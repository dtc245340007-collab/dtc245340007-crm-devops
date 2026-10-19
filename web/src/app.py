import os
import secrets
from datetime import datetime, date
from flask import (
    Flask, render_template, request, redirect,
    url_for, session, flash, abort
)
from werkzeug.middleware.proxy_fix import ProxyFix
from werkzeug.security import check_password_hash, generate_password_hash

from .db import get_db
from .auth import (
    login_required, manager_required,
    get_client_ip, log_login_failure, log_login_success
)

def create_app():
    app = Flask(__name__)
    app.secret_key = os.environ.get("SECRET_KEY", secrets.token_hex(32))
    
    # Session cookie hardening
    app.config.update(
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=False  # Step 3 will enable HTTPS
    )

    # ProxyFix to trust reverse proxy headers (X-Forwarded-For, X-Forwarded-Proto)
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

    # CSRF Protection
    @app.before_request
    def csrf_protect():
        if "csrf_token" not in session:
            session["csrf_token"] = secrets.token_hex(32)
        if request.method == "POST":
            # Exclude health check from CSRF
            if request.path == "/health":
                return
            token = request.form.get("csrf_token")
            if not token or token != session.get("csrf_token"):
                abort(400, description="CSRF token không hợp lệ hoặc đã hết hạn.")

    @app.context_processor
    def inject_globals():
        return {
            "csrf_token": lambda: session.get("csrf_token", ""),
            "current_user": {
                "id": session.get("user_id"),
                "username": session.get("username"),
                "full_name": session.get("full_name"),
                "role": session.get("role")
            } if "user_id" in session else None,
            "today": date.today()
        }

    # -------------------------------------------------------------
    # Error Handlers
    # -------------------------------------------------------------
    @app.errorhandler(400)
    def bad_request_error(e):
        return render_template("errors/400.html", message=getattr(e, "description", "Yêu cầu không hợp lệ.")), 400

    @app.errorhandler(403)
    def forbidden_error(e):
        return render_template("errors/403.html"), 403

    @app.errorhandler(404)
    def not_found_error(e):
        return render_template("errors/404.html"), 404

    @app.errorhandler(500)
    def internal_error(e):
        return render_template("errors/500.html"), 500

    # -------------------------------------------------------------
    # Health Check
    # -------------------------------------------------------------
    @app.route("/health")
    def health():
        try:
            with get_db() as cur:
                cur.execute("SELECT 1")
            return "OK", 200
        except Exception as ex:
            return f"DATABASE ERROR: {str(ex)}", 500

    # -------------------------------------------------------------
    # Authentication Routes
    # -------------------------------------------------------------
    @app.route("/login", methods=["GET", "POST"])
    def login():
        if "user_id" in session:
            return redirect(url_for("dashboard"))

        if request.method == "POST":
            username = request.form.get("username", "").strip()
            password = request.form.get("password", "")
            ip = get_client_ip()

            with get_db() as cur:
                cur.execute(
                    "SELECT id, username, password_hash, full_name, role, is_active FROM users WHERE username = %s",
                    (username,)
                )
                user = cur.fetchone()

            if not user:
                log_login_failure(ip, username, "unknown_user")
                flash("Tên đăng nhập hoặc mật khẩu không đúng.", "danger")
                return render_template("login.html")

            if not user["is_active"]:
                log_login_failure(ip, username, "inactive")
                flash("Tài khoản đã bị khóa. Vui lòng liên hệ Quản lý.", "danger")
                return render_template("login.html")

            if not check_password_hash(user["password_hash"], password):
                log_login_failure(ip, username, "wrong_password")
                flash("Tên đăng nhập hoặc mật khẩu không đúng.", "danger")
                return render_template("login.html")

            # Login Successful
            log_login_success(ip, username)
            session.clear()
            session["user_id"] = user["id"]
            session["username"] = user["username"]
            session["full_name"] = user["full_name"]
            session["role"] = user["role"]
            session["csrf_token"] = secrets.token_hex(32)

            next_page = request.args.get("next")
            if next_page and next_page.startswith("/"):
                return redirect(next_page)
            return redirect(url_for("dashboard"))

        return render_template("login.html")

    @app.route("/logout", methods=["GET", "POST"])
    def logout():
        session.clear()
        return redirect(url_for("login"))

    # -------------------------------------------------------------
    # Dashboard / Home
    # -------------------------------------------------------------
    @app.route("/")
    @login_required
    def dashboard():
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            # 1. Customer Counts by Status
            if role == "manager":
                cur.execute("""
                    SELECT status, COUNT(*) as count 
                    FROM customers 
                    GROUP BY status
                """)
            else:
                cur.execute("""
                    SELECT status, COUNT(*) as count 
                    FROM customers 
                    WHERE assigned_to = %s 
                    GROUP BY status
                """, (user_id,))
            
            status_counts = {"lead": 0, "active": 0, "inactive": 0}
            for row in cur.fetchall():
                status_counts[row["status"]] = row["count"]

            # 2. Today and overdue reminders (next_follow_up <= CURRENT_DATE)
            if role == "manager":
                cur.execute("""
                    SELECT i.*, c.name as customer_name, c.customer_code, c.phone as customer_phone,
                           ct.full_name as contact_name, u.full_name as staff_name
                    FROM interactions i
                    JOIN customers c ON i.customer_id = c.id
                    LEFT JOIN contacts ct ON i.contact_id = ct.id
                    JOIN users u ON i.user_id = u.id
                    WHERE i.next_follow_up IS NOT NULL AND i.next_follow_up <= CURRENT_DATE
                    ORDER BY i.next_follow_up ASC, i.interaction_time DESC
                    LIMIT 20
                """)
            else:
                cur.execute("""
                    SELECT i.*, c.name as customer_name, c.customer_code, c.phone as customer_phone,
                           ct.full_name as contact_name, u.full_name as staff_name
                    FROM interactions i
                    JOIN customers c ON i.customer_id = c.id
                    LEFT JOIN contacts ct ON i.contact_id = ct.id
                    JOIN users u ON i.user_id = u.id
                    WHERE i.next_follow_up IS NOT NULL 
                      AND i.next_follow_up <= CURRENT_DATE
                      AND c.assigned_to = %s
                    ORDER BY i.next_follow_up ASC, i.interaction_time DESC
                    LIMIT 20
                """, (user_id,))
            
            reminders = cur.fetchall()

            # Total customers count
            if role == "manager":
                cur.execute("SELECT COUNT(*) as total FROM customers")
            else:
                cur.execute("SELECT COUNT(*) as total FROM customers WHERE assigned_to = %s", (user_id,))
            total_customers = cur.fetchone()["total"]

        return render_template(
            "dashboard.html",
            counts=status_counts,
            reminders=reminders,
            total_customers=total_customers
        )

    # -------------------------------------------------------------
    # Customer Management
    # -------------------------------------------------------------
    @app.route("/customers")
    @login_required
    def customers_list():
        user_id = session["user_id"]
        role = session["role"]

        query = request.args.get("q", "").strip()
        status_filter = request.args.get("status", "").strip()
        page = max(1, int(request.args.get("page", 1)))
        per_page = 10
        offset = (page - 1) * per_page

        conditions = ["1=1"]
        params = []

        if role == "staff":
            conditions.append("c.assigned_to = %s")
            params.append(user_id)

        if status_filter in ("lead", "active", "inactive"):
            conditions.append("c.status = %s")
            params.append(status_filter)

        if query:
            conditions.append("""(
                c.name ILIKE %s OR c.customer_code ILIKE %s OR 
                c.email ILIKE %s OR c.phone ILIKE %s OR c.company ILIKE %s
            )""")
            search_pattern = f"%{query}%"
            params.extend([search_pattern] * 5)

        where_clause = " AND ".join(conditions)

        with get_db() as cur:
            # Total count
            cur.execute(f"SELECT COUNT(*) as total FROM customers c WHERE {where_clause}", tuple(params))
            total_items = cur.fetchone()["total"]

            # Query items
            data_params = list(params) + [per_page, offset]
            cur.execute(f"""
                SELECT c.*, u.full_name as assigned_name 
                FROM customers c 
                LEFT JOIN users u ON c.assigned_to = u.id 
                WHERE {where_clause} 
                ORDER BY c.id DESC 
                LIMIT %s OFFSET %s
            """, tuple(data_params))
            customers = cur.fetchall()

        total_pages = max(1, (total_items + per_page - 1) // per_page)

        return render_template(
            "customers/list.html",
            customers=customers,
            query=query,
            status_filter=status_filter,
            page=page,
            total_pages=total_pages,
            total_items=total_items
        )

    @app.route("/customers/new", methods=["GET", "POST"])
    @login_required
    def customer_new():
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT id, full_name, role FROM users WHERE is_active = TRUE ORDER BY full_name")
            staff_list = cur.fetchall()

        if request.method == "POST":
            code = request.form.get("customer_code", "").strip()
            name = request.form.get("name", "").strip()
            email = request.form.get("email", "").strip() or None
            phone = request.form.get("phone", "").strip() or None
            company = request.form.get("company", "").strip() or None
            address = request.form.get("address", "").strip() or None
            status = request.form.get("status", "lead")
            
            if role == "manager":
                assigned_to = request.form.get("assigned_to") or None
                if assigned_to:
                    assigned_to = int(assigned_to)
            else:
                assigned_to = user_id

            if not code or not name:
                flash("Mã khách hàng và Tên khách hàng không được để trống.", "danger")
                return render_template("customers/form.html", customer=None, staff_list=staff_list)

            with get_db() as cur:
                # Check duplicate code
                cur.execute("SELECT id FROM customers WHERE customer_code = %s", (code,))
                if cur.fetchone():
                    flash(f"Mã khách hàng '{code}' đã tồn tại trong hệ thống.", "danger")
                    return render_template("customers/form.html", customer=request.form, staff_list=staff_list)

                # Check duplicate email
                if email:
                    cur.execute("SELECT id FROM customers WHERE email = %s", (email,))
                    if cur.fetchone():
                        flash(f"Email '{email}' đã được sử dụng bởi khách hàng khác.", "danger")
                        return render_template("customers/form.html", customer=request.form, staff_list=staff_list)

                cur.execute("""
                    INSERT INTO customers (customer_code, name, email, phone, company, address, status, assigned_to)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (code, name, email, phone, company, address, status, assigned_to))
                new_id = cur.fetchone()["id"]

            flash("Thêm khách hàng mới thành công!", "success")
            return redirect(url_for("customer_detail", id=new_id))

        return render_template("customers/form.html", customer=None, staff_list=staff_list)

    @app.route("/customers/<int:id>")
    @login_required
    def customer_detail(id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("""
                SELECT c.*, u.full_name as assigned_name 
                FROM customers c 
                LEFT JOIN users u ON c.assigned_to = u.id 
                WHERE c.id = %s
            """, (id,))
            customer = cur.fetchone()

            if not customer:
                abort(404)

            # BR: Staff can only view their own assigned customers
            if role == "staff" and customer["assigned_to"] != user_id:
                abort(403)

            # Contacts list
            cur.execute("""
                SELECT * FROM contacts 
                WHERE customer_id = %s 
                ORDER BY is_primary DESC, id ASC
            """, (id,))
            contacts = cur.fetchall()

            # Interactions Timeline
            cur.execute("""
                SELECT i.*, ct.full_name as contact_name, u.full_name as user_name 
                FROM interactions i 
                LEFT JOIN contacts ct ON i.contact_id = ct.id 
                JOIN users u ON i.user_id = u.id 
                WHERE i.customer_id = %s 
                ORDER BY i.interaction_time DESC
            """, (id,))
            interactions = cur.fetchall()

        return render_template(
            "customers/detail.html",
            customer=customer,
            contacts=contacts,
            interactions=interactions
        )

    @app.route("/customers/<int:id>/edit", methods=["GET", "POST"])
    @login_required
    def customer_edit(id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT * FROM customers WHERE id = %s", (id,))
            customer = cur.fetchone()
            if not customer:
                abort(404)

            # Check permission: Staff can only edit if assigned to them
            if role == "staff" and customer["assigned_to"] != user_id:
                abort(403)

            cur.execute("SELECT id, full_name, role FROM users WHERE is_active = TRUE ORDER BY full_name")
            staff_list = cur.fetchall()

        if request.method == "POST":
            code = request.form.get("customer_code", "").strip()
            name = request.form.get("name", "").strip()
            email = request.form.get("email", "").strip() or None
            phone = request.form.get("phone", "").strip() or None
            company = request.form.get("company", "").strip() or None
            address = request.form.get("address", "").strip() or None
            status = request.form.get("status", customer["status"])

            if role == "manager":
                assigned_to = request.form.get("assigned_to") or None
                if assigned_to:
                    assigned_to = int(assigned_to)
            else:
                assigned_to = customer["assigned_to"]  # Staff cannot re-assign

            if not code or not name:
                flash("Mã khách hàng và Tên khách hàng không được để trống.", "danger")
                return render_template("customers/form.html", customer=customer, staff_list=staff_list)

            with get_db() as cur:
                # Check duplicate code
                cur.execute("SELECT id FROM customers WHERE customer_code = %s AND id != %s", (code, id))
                if cur.fetchone():
                    flash(f"Mã khách hàng '{code}' đã trùng với khách hàng khác.", "danger")
                    return render_template("customers/form.html", customer=customer, staff_list=staff_list)

                # Check duplicate email
                if email:
                    cur.execute("SELECT id FROM customers WHERE email = %s AND id != %s", (email, id))
                    if cur.fetchone():
                        flash(f"Email '{email}' đã được sử dụng bởi khách hàng khác.", "danger")
                        return render_template("customers/form.html", customer=customer, staff_list=staff_list)

                cur.execute("""
                    UPDATE customers 
                    SET customer_code = %s, name = %s, email = %s, phone = %s, company = %s,
                        address = %s, status = %s, assigned_to = %s, updated_at = NOW()
                    WHERE id = %s
                """, (code, name, email, phone, company, address, status, assigned_to, id))

            flash("Cập nhật thông tin khách hàng thành công!", "success")
            return redirect(url_for("customer_detail", id=id))

        return render_template("customers/form.html", customer=customer, staff_list=staff_list)

    @app.route("/customers/<int:id>/delete", methods=["POST"])
    @manager_required
    def customer_delete(id):
        # BR: Customer with interactions MUST NOT be hard-deleted, only status='inactive'
        with get_db() as cur:
            cur.execute("SELECT COUNT(*) as count FROM interactions WHERE customer_id = %s", (id,))
            interaction_count = cur.fetchone()["count"]

            if interaction_count > 0:
                cur.execute("UPDATE customers SET status = 'inactive', updated_at = NOW() WHERE id = %s", (id,))
                flash(f"Khách hàng đã có {interaction_count} tương tác trong lịch sử. Hệ thống KHÔNG xóa cứng mà đã chuyển trạng thái sang Inactive.", "warning")
            else:
                cur.execute("DELETE FROM customers WHERE id = %s", (id,))
                flash("Đã xóa vĩnh viễn khách hàng (chưa có tương tác nào).", "success")

        return redirect(url_for("customers_list"))

    # -------------------------------------------------------------
    # Contact Management
    # -------------------------------------------------------------
    @app.route("/customers/<int:id>/contacts/new", methods=["POST"])
    @login_required
    def contact_new(id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT assigned_to FROM customers WHERE id = %s", (id,))
            cust = cur.fetchone()
            if not cust:
                abort(404)
            if role == "staff" and cust["assigned_to"] != user_id:
                abort(403)

            full_name = request.form.get("full_name", "").strip()
            position = request.form.get("position", "").strip() or None
            email = request.form.get("email", "").strip() or None
            phone = request.form.get("phone", "").strip() or None
            is_primary = bool(request.form.get("is_primary"))

            if not full_name:
                flash("Họ và tên người liên hệ không được để trống.", "danger")
                return redirect(url_for("customer_detail", id=id))

            # BR: At most 1 primary contact per customer
            if is_primary:
                cur.execute("UPDATE contacts SET is_primary = FALSE WHERE customer_id = %s", (id,))

            cur.execute("""
                INSERT INTO contacts (customer_id, full_name, position, email, phone, is_primary)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (id, full_name, position, email, phone, is_primary))

        flash("Thêm người liên hệ thành công!", "success")
        return redirect(url_for("customer_detail", id=id))

    @app.route("/customers/<int:c_id>/contacts/<int:contact_id>/delete", methods=["POST"])
    @login_required
    def contact_delete(c_id, contact_id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT assigned_to FROM customers WHERE id = %s", (c_id,))
            cust = cur.fetchone()
            if not cust:
                abort(404)
            if role == "staff" and cust["assigned_to"] != user_id:
                abort(403)

            cur.execute("DELETE FROM contacts WHERE id = %s AND customer_id = %s", (contact_id, c_id))

        flash("Đã xóa người liên hệ.", "success")
        return redirect(url_for("customer_detail", id=c_id))

    @app.route("/customers/<int:c_id>/contacts/<int:contact_id>/primary", methods=["POST"])
    @login_required
    def contact_set_primary(c_id, contact_id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT assigned_to FROM customers WHERE id = %s", (c_id,))
            cust = cur.fetchone()
            if not cust:
                abort(404)
            if role == "staff" and cust["assigned_to"] != user_id:
                abort(403)

            cur.execute("UPDATE contacts SET is_primary = FALSE WHERE customer_id = %s", (c_id,))
            cur.execute("UPDATE contacts SET is_primary = TRUE WHERE id = %s AND customer_id = %s", (contact_id, c_id))

        flash("Đã đặt làm người liên hệ chính.", "success")
        return redirect(url_for("customer_detail", id=c_id))

    # -------------------------------------------------------------
    # Interaction Management
    # -------------------------------------------------------------
    @app.route("/customers/<int:id>/interactions/new", methods=["POST"])
    @login_required
    def interaction_new(id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT assigned_to FROM customers WHERE id = %s", (id,))
            cust = cur.fetchone()
            if not cust:
                abort(404)
            if role == "staff" and cust["assigned_to"] != user_id:
                abort(403)

            itype = request.form.get("type", "note")
            contact_id = request.form.get("contact_id") or None
            if contact_id:
                contact_id = int(contact_id)
            subject = request.form.get("subject", "").strip()
            content = request.form.get("content", "").strip()
            interaction_time = request.form.get("interaction_time") or None
            next_follow_up = request.form.get("next_follow_up") or None

            if not subject or not content:
                flash("Tiêu đề và nội dung tương tác không được để trống.", "danger")
                return redirect(url_for("customer_detail", id=id))

            cur.execute("""
                INSERT INTO interactions (
                    customer_id, contact_id, user_id, type, subject, content,
                    interaction_time, next_follow_up
                ) VALUES (%s, %s, %s, %s, %s, %s, COALESCE(%s, NOW()), %s)
            """, (id, contact_id, user_id, itype, subject, content, interaction_time, next_follow_up))

        flash("Đã ghi nhận tương tác mới vào timeline!", "success")
        return redirect(url_for("customer_detail", id=id))

    @app.route("/interactions/<int:id>/edit", methods=["GET", "POST"])
    @login_required
    def interaction_edit(id):
        user_id = session["user_id"]
        role = session["role"]

        with get_db() as cur:
            cur.execute("SELECT * FROM interactions WHERE id = %s", (id,))
            interaction = cur.fetchone()
            if not interaction:
                abort(404)

            # BR: Staff can only edit interactions they created
            if role == "staff" and interaction["user_id"] != user_id:
                abort(403)

            cur.execute("SELECT * FROM contacts WHERE customer_id = %s", (interaction["customer_id"],))
            contacts = cur.fetchall()

        if request.method == "POST":
            itype = request.form.get("type", interaction["type"])
            contact_id = request.form.get("contact_id") or None
            if contact_id:
                contact_id = int(contact_id)
            subject = request.form.get("subject", "").strip()
            content = request.form.get("content", "").strip()
            next_follow_up = request.form.get("next_follow_up") or None

            if not subject or not content:
                flash("Tiêu đề và nội dung không được để trống.", "danger")
                return render_template("interactions/edit.html", interaction=interaction, contacts=contacts)

            with get_db() as cur:
                cur.execute("""
                    UPDATE interactions 
                    SET type = %s, contact_id = %s, subject = %s, content = %s, next_follow_up = %s
                    WHERE id = %s
                """, (itype, contact_id, subject, content, next_follow_up, id))

            flash("Cập nhật tương tác thành công!", "success")
            return redirect(url_for("customer_detail", id=interaction["customer_id"]))

        return render_template("interactions/edit.html", interaction=interaction, contacts=contacts)

    @app.route("/interactions/<int:id>/delete", methods=["POST"])
    @manager_required
    def interaction_delete(id):
        # BR: Only Manager can delete interaction
        with get_db() as cur:
            cur.execute("SELECT customer_id FROM interactions WHERE id = %s", (id,))
            row = cur.fetchone()
            if not row:
                abort(404)
            cust_id = row["customer_id"]

            cur.execute("DELETE FROM interactions WHERE id = %s", (id,))

        flash("Đã xóa tương tác khỏi hệ thống.", "success")
        return redirect(url_for("customer_detail", id=cust_id))

    # -------------------------------------------------------------
    # User / Staff Management (Manager Only)
    # -------------------------------------------------------------
    @app.route("/users")
    @manager_required
    def users_list():
        with get_db() as cur:
            cur.execute("""
                SELECT u.*, COUNT(c.id) as assigned_count 
                FROM users u 
                LEFT JOIN customers c ON u.id = c.assigned_to 
                GROUP BY u.id 
                ORDER BY u.id ASC
            """)
            users = cur.fetchall()

        return render_template("users/list.html", users=users)

    @app.route("/users/new", methods=["GET", "POST"])
    @manager_required
    def user_new():
        if request.method == "POST":
            username = request.form.get("username", "").strip()
            full_name = request.form.get("full_name", "").strip()
            password = request.form.get("password", "")
            role = request.form.get("role", "staff")

            if not username or not full_name or not password:
                flash("Vui lòng điền đầy đủ thông tin bắt buộc.", "danger")
                return render_template("users/form.html", user=None)

            pw_hash = generate_password_hash(password)

            with get_db() as cur:
                cur.execute("SELECT id FROM users WHERE username = %s", (username,))
                if cur.fetchone():
                    flash(f"Tên đăng nhập '{username}' đã tồn tại.", "danger")
                    return render_template("users/form.html", user=request.form)

                cur.execute("""
                    INSERT INTO users (username, password_hash, full_name, role, is_active)
                    VALUES (%s, %s, %s, %s, true)
                """, (username, pw_hash, full_name, role))

            flash("Tạo tài khoản nhân viên thành công!", "success")
            return redirect(url_for("users_list"))

        return render_template("users/form.html", user=None)

    @app.route("/users/<int:id>/edit", methods=["GET", "POST"])
    @manager_required
    def user_edit(id):
        with get_db() as cur:
            cur.execute("SELECT * FROM users WHERE id = %s", (id,))
            user = cur.fetchone()
            if not user:
                abort(404)

        if request.method == "POST":
            full_name = request.form.get("full_name", "").strip()
            role = request.form.get("role", user["role"])

            if not full_name:
                flash("Họ và tên không được để trống.", "danger")
                return render_template("users/form.html", user=user)

            with get_db() as cur:
                cur.execute("""
                    UPDATE users SET full_name = %s, role = %s WHERE id = %s
                """, (full_name, role, id))

            flash("Cập nhật thông tin nhân viên thành công!", "success")
            return redirect(url_for("users_list"))

        return render_template("users/form.html", user=user)

    @app.route("/users/<int:id>/reset-password", methods=["POST"])
    @manager_required
    def user_reset_password(id):
        new_pwd = request.form.get("new_password", "")
        if not new_pwd or len(new_pwd) < 6:
            flash("Mật khẩu mới phải có tối thiểu 6 ký tự.", "danger")
            return redirect(url_for("users_list"))

        pw_hash = generate_password_hash(new_pwd)
        with get_db() as cur:
            cur.execute("UPDATE users SET password_hash = %s WHERE id = %s", (pw_hash, id))

        flash(f"Đã đặt lại mật khẩu cho nhân viên #{id}.", "success")
        return redirect(url_for("users_list"))

    @app.route("/users/<int:id>/toggle-status", methods=["POST"])
    @manager_required
    def user_toggle_status(id):
        if id == session["user_id"]:
            flash("Không thể tự khóa tài khoản của chính mình!", "danger")
            return redirect(url_for("users_list"))

        with get_db() as cur:
            cur.execute("UPDATE users SET is_active = NOT is_active WHERE id = %s RETURNING is_active", (id,))
            new_status = cur.fetchone()["is_active"]

        status_text = "kích hoạt" if new_status else "khóa"
        flash(f"Đã {status_text} tài khoản thành công.", "success")
        return redirect(url_for("users_list"))

    # -------------------------------------------------------------
    # Reports (Manager Only)
    # -------------------------------------------------------------
    @app.route("/reports")
    @manager_required
    def reports():
        with get_db() as cur:
            # 1. Customers by status
            cur.execute("""
                SELECT status, COUNT(*) as count 
                FROM customers 
                GROUP BY status
            """)
            status_dist = {r["status"]: r["count"] for r in cur.fetchall()}

            # 2. Interactions by day (past 7 days)
            cur.execute("""
                SELECT DATE(interaction_time) as period, COUNT(*) as count 
                FROM interactions 
                WHERE interaction_time >= CURRENT_DATE - INTERVAL '7 days' 
                GROUP BY period 
                ORDER BY period DESC
            """)
            by_day = cur.fetchall()

            # 3. Interactions by week (past 4 weeks)
            cur.execute("""
                SELECT DATE_TRUNC('week', interaction_time)::DATE as period, COUNT(*) as count 
                FROM interactions 
                WHERE interaction_time >= CURRENT_DATE - INTERVAL '4 weeks' 
                GROUP BY period 
                ORDER BY period DESC
            """)
            by_week = cur.fetchall()

            # 4. Interactions by month (past 6 months)
            cur.execute("""
                SELECT TO_CHAR(interaction_time, 'YYYY-MM') as period, COUNT(*) as count 
                FROM interactions 
                WHERE interaction_time >= CURRENT_DATE - INTERVAL '6 months' 
                GROUP BY period 
                ORDER BY period DESC
            """)
            by_month = cur.fetchall()

            # 5. Top staff by interactions
            cur.execute("""
                SELECT u.id, u.full_name, u.role, COUNT(i.id) as count 
                FROM users u 
                JOIN interactions i ON u.id = i.user_id 
                GROUP BY u.id, u.full_name, u.role 
                ORDER BY count DESC 
                LIMIT 5
            """)
            top_staff = cur.fetchall()

            # 6. Neglected customers (> 30 days without contact)
            cur.execute("""
                SELECT c.id, c.customer_code, c.name, c.company, c.status, 
                       u.full_name as assigned_name, 
                       MAX(i.interaction_time) as last_interaction
                FROM customers c 
                LEFT JOIN users u ON c.assigned_to = u.id 
                LEFT JOIN interactions i ON c.id = i.customer_id 
                GROUP BY c.id, c.customer_code, c.name, c.company, c.status, u.full_name 
                HAVING MAX(i.interaction_time) IS NULL 
                    OR MAX(i.interaction_time) < NOW() - INTERVAL '30 days' 
                ORDER BY last_interaction ASC NULLS FIRST
            """)
            neglected_customers = cur.fetchall()

        return render_template(
            "reports.html",
            status_dist=status_dist,
            by_day=by_day,
            by_week=by_week,
            by_month=by_month,
            top_staff=top_staff,
            neglected_customers=neglected_customers
        )

    return app

if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=8000)
