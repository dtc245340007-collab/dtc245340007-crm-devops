#!/usr/bin/env python3
# ==============================================================================
# SCRIPT THIẾT LẬP CREDENTIALS VÀ ĐỒNG BỘ DỊCH VỤ CHO CRM DEVOPS (PYTHON)
# Tự động nhận diện thư mục dự án, bảo vệ secrets, không xóa volume dữ liệu
# ==============================================================================

import subprocess
import os
import sys

# Xác định thư mục dự án dựa trên vị trí script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
ENV_FILE = os.path.join(PROJECT_DIR, ".env")
COMPOSE_FILE = os.path.join(PROJECT_DIR, "docker-compose.yml")

force = "-y" in sys.argv or "--force" in sys.argv or "--yes" in sys.argv

print("==================================================================")
print("          THIẾT LẬP CREDENTIALS CHO HỆ THỐNG CRM DEVOPS          ")
print(f" Thư mục dự án: {PROJECT_DIR}")
print("==================================================================")

if os.path.exists(ENV_FILE) and not force:
    print(f"[!] CẢNH BÁO: File .env đã tồn tại tại: {ENV_FILE}")
    confirm = input("Bạn có chắc chắn muốn cập nhật/ghi đè credentials? (y/N): ").strip()
    if confirm.lower() not in ("y", "yes"):
        print("[-] Đã hủy thao tác theo yêu cầu người dùng.")
        sys.exit(0)

# Lấy mật khẩu từ biến môi trường nếu có, hoặc dùng mật khẩu mặc định mạnh
ADMIN_PASS = os.environ.get("ADMIN_PASSWORD", "Admin@CRM2026!")
STAFF1_PASS = os.environ.get("STAFF1_PASSWORD", "Staff@CRM2026!")
STAFF2_PASS = os.environ.get("STAFF2_PASSWORD", "Staff@CRM2026!")
PGADMIN_PASS = os.environ.get("PGADMIN_DEFAULT_PASSWORD", "Admin@CRM2026!")
GRAFANA_PASS = os.environ.get("GRAFANA_ADMIN_PASSWORD", "Admin@CRM2026!")
DB_SUPER_PASS = os.environ.get("POSTGRES_PASSWORD", "Admin@CRM2026!")
DB_APP_PASS = os.environ.get("APP_DB_PASSWORD", "App@CRM2026!")
DB_EXPORTER_PASS = os.environ.get("POSTGRES_EXPORTER_PASSWORD", "Exporter@CRM2026!")
PGADMIN_EMAIL = os.environ.get("PGADMIN_DEFAULT_EMAIL", "dtc245340007@gmail.com")

# 1. Sinh password hash bằng werkzeug
print("[1/4] Sinh password hash qua werkzeug / container web...")
admin_hash = ""
staff1_hash = ""
staff2_hash = ""

try:
    from werkzeug.security import generate_password_hash
    admin_hash = generate_password_hash(ADMIN_PASS)
    staff1_hash = generate_password_hash(STAFF1_PASS)
    staff2_hash = generate_password_hash(STAFF2_PASS)
except ImportError:
    cmd_hash = ["docker", "compose", "-f", COMPOSE_FILE, "exec", "-T", "web", "python", "-c",
                f"from werkzeug.security import generate_password_hash; print(generate_password_hash('{ADMIN_PASS}'))"]
    res = subprocess.run(cmd_hash, capture_output=True, text=True)
    if res.returncode == 0:
        admin_hash = res.stdout.strip()

print(" -> Đã tạo hash an toàn cho tài khoản người dùng.")

# 2. Cập nhật .env (chmod 600)
print("[2/4] Cập nhật file .env...")
env_content = f"""# ==============================================================================
# HỆ THỐNG CRM CHĂM SÓC KHÁCH HÀNG - CẤU HÌNH MÔI TRƯỜNG
# MSSV: dtc245340007 - NGUYEN THI QUYNH THO
# ==============================================================================

# 1. PostgreSQL Configuration
POSTGRES_DB=crm
POSTGRES_USER=crm_admin
POSTGRES_PASSWORD={DB_SUPER_PASS}

# 2. Dedicated Application DB Role (Non-superuser)
APP_DB_USER=crm_app
APP_DB_PASSWORD={DB_APP_PASS}

# 3. Dedicated Monitoring DB Role (pg_monitor, Non-superuser)
POSTGRES_EXPORTER_PASSWORD={DB_EXPORTER_PASS}

# 4. Flask App Configuration
SECRET_KEY=CRM2026SecretKeySecurityDevOpsNguyenThiQuynhThoDTC245340007
FLASK_ENV=production
SESSION_COOKIE_SECURE=true

# 5. pgAdmin Configuration
PGADMIN_DEFAULT_EMAIL={PGADMIN_EMAIL}
PGADMIN_DEFAULT_PASSWORD={PGADMIN_PASS}

# 6. CRM Users Default Passwords
ADMIN_PASSWORD={ADMIN_PASS}
STAFF1_PASSWORD={STAFF1_PASS}
STAFF2_PASSWORD={STAFF2_PASS}

# 7. Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD={GRAFANA_PASS}
"""

with open(ENV_FILE, "w", encoding="utf-8") as f:
    f.write(env_content)
os.chmod(ENV_FILE, 0o600)
print(" -> Đã ghi file .env bảo mật (quyền 600).")

# 3. Cập nhật Database roles và users
print("[3/4] Cập nhật Database roles và bảng users...")
if admin_hash and staff1_hash and staff2_hash:
    sql_commands = f"""
ALTER USER crm_admin WITH PASSWORD '{DB_SUPER_PASS}';
ALTER USER crm_app WITH PASSWORD '{DB_APP_PASS}';
ALTER USER exporter WITH PASSWORD '{DB_EXPORTER_PASS}';

UPDATE users SET password_hash = '{admin_hash}' WHERE username = 'admin';
UPDATE users SET password_hash = '{staff1_hash}' WHERE username = 'nhanvien01';
UPDATE users SET password_hash = '{staff2_hash}' WHERE username = 'nhanvien02';
"""
    cmd_db = ["docker", "compose", "-f", COMPOSE_FILE, "exec", "-T", "db", "psql", "-U", "crm_admin", "-d", "crm"]
    subprocess.run(cmd_db, input=sql_commands, text=True, capture_output=True)
    print(" -> Đã cập nhật mật khẩu database roles và bảng users.")

# 4. Reset Grafana admin password & Khởi động lại service cần thiết (Không xóa volume dữ liệu)
print("[4/4] Áp dụng cấu hình và cập nhật dịch vụ...")
cmd_gf = ["docker", "compose", "-f", COMPOSE_FILE, "exec", "-T", "grafana", "grafana-cli", "admin", "reset-admin-password", GRAFANA_PASS]
subprocess.run(cmd_gf, capture_output=True, text=True)

subprocess.run(["docker", "compose", "-f", COMPOSE_FILE, "up", "-d", "pgadmin", "web", "postgres-exporter"], capture_output=True)

print("==================================================================")
print(" [THÀNH CÔNG] ĐÃ CẤU HÌNH VÀ ĐỒNG BỘ CREDENTIALS!")
print(f" Vị trí file lưu cấu hình bí mật: {ENV_FILE}")
print(" Mật khẩu đã được mã hóa và lưu trữ an toàn trong .env (chmod 600).")
print(" (Mở file .env để xem thông tin chi tiết khi cần đăng nhập).")
print("==================================================================")
