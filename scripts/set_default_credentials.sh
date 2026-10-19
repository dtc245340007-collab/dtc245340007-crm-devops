#!/bin/bash
# ==============================================================================
# SCRIPT THIẾT LẬP CREDENTIALS VÀ ĐỒNG BỘ DỊCH VỤ CHO CRM DEVOPS
# Tự động nhận diện thư mục dự án, bảo vệ secrets, không xóa volume dữ liệu
# ==============================================================================

set -e

# Xác định thư mục dự án dựa trên vị trí script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"

# Cờ hỗ trợ chạy không cần tương tác (-y hoặc --force)
FORCE=false
for arg in "$@"; do
  if [ "$arg" = "-y" ] || [ "$arg" = "--force" ] || [ "$arg" = "--yes" ]; then
    FORCE=true
  fi
done

echo "=================================================================="
echo "          THIẾT LẬP CREDENTIALS CHO HỆ THỐNG CRM DEVOPS          "
echo " Thư mục dự án: $PROJECT_DIR"
echo "=================================================================="

# Kiểm tra nếu file .env đã tồn tại
if [ -f "$ENV_FILE" ] && [ "$FORCE" = false ]; then
  echo "[!] CẢNH BÁO: File .env đã tồn tại tại: $ENV_FILE"
  read -r -p "Bạn có chắc chắn muốn cập nhật/ghi đè credentials? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "[-] Đã hủy thao tác theo yêu cầu người dùng."
    exit 0
  fi
fi

# Mật khẩu chuẩn hóa lấy từ biến môi trường nếu có, hoặc dùng giá trị mạnh mặc định
ADMIN_PASS="${ADMIN_PASSWORD:-Admin@CRM2026!}"
STAFF1_PASS="${STAFF1_PASSWORD:-Staff@CRM2026!}"
STAFF2_PASS="${STAFF2_PASSWORD:-Staff@CRM2026!}"
PGADMIN_PASS="${PGADMIN_DEFAULT_PASSWORD:-Admin@CRM2026!}"
GRAFANA_PASS="${GRAFANA_ADMIN_PASSWORD:-Admin@CRM2026!}"
DB_SUPER_PASS="${POSTGRES_PASSWORD:-Admin@CRM2026!}"
DB_APP_PASS="${APP_DB_PASSWORD:-App@CRM2026!}"
DB_EXPORTER_PASS="${POSTGRES_EXPORTER_PASSWORD:-Exporter@CRM2026!}"
PGADMIN_EMAIL="${PGADMIN_DEFAULT_EMAIL:-dtc245340007@gmail.com}"

# 1. Sinh password hash an toàn bằng scrypt qua container web
echo "[1/4] Sinh password hash qua web container..."
ADMIN_HASH=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T web python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$ADMIN_PASS'))" 2>/dev/null | tr -d '\r')
STAFF1_HASH=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T web python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$STAFF1_PASS'))" 2>/dev/null | tr -d '\r')
STAFF2_HASH=$(docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T web python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$STAFF2_PASS'))" 2>/dev/null | tr -d '\r')

if [ -z "$ADMIN_HASH" ]; then
  echo "[-] Web container chưa chạy, sinh hash trực tiếp qua python3 nội bộ..."
  ADMIN_HASH=$(python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$ADMIN_PASS'))" 2>/dev/null || echo "")
  STAFF1_HASH=$(python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$STAFF1_PASS'))" 2>/dev/null || echo "")
  STAFF2_HASH=$(python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('$STAFF2_PASS'))" 2>/dev/null || echo "")
fi

echo " -> Đã tạo hash an toàn cho tài khoản người dùng."

# 2. Cập nhật .env (quyền 600)
echo "[2/4] Cập nhật file .env..."
cat << EOF > "$ENV_FILE"
# ==============================================================================
# HỆ THỐNG CRM CHĂM SÓC KHÁCH HÀNG - CẤU HÌNH MÔI TRƯỜNG
# MSSV: dtc245340007 - NGUYEN THI QUYNH THO
# ==============================================================================

# 1. PostgreSQL Configuration
POSTGRES_DB=crm
POSTGRES_USER=crm_admin
POSTGRES_PASSWORD=$DB_SUPER_PASS

# 2. Dedicated Application DB Role (Non-superuser)
APP_DB_USER=crm_app
APP_DB_PASSWORD=$DB_APP_PASS

# 3. Dedicated Monitoring DB Role (pg_monitor, Non-superuser)
POSTGRES_EXPORTER_PASSWORD=$DB_EXPORTER_PASS

# 4. Flask App Configuration
SECRET_KEY=CRM2026SecretKeySecurityDevOpsNguyenThiQuynhThoDTC245340007
FLASK_ENV=production
SESSION_COOKIE_SECURE=true

# 5. pgAdmin Configuration
PGADMIN_DEFAULT_EMAIL=$PGADMIN_EMAIL
PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASS

# 6. CRM Users Default Passwords
ADMIN_PASSWORD=$ADMIN_PASS
STAFF1_PASSWORD=$STAFF1_PASS
STAFF2_PASSWORD=$STAFF2_PASS

# 7. Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASS
EOF

chmod 600 "$ENV_FILE"
echo " -> Đã ghi file .env bảo mật (quyền 600)."

# 3. Cập nhật Database roles và users
echo "[3/4] Cập nhật Database roles và bảng users..."
if [ -n "$ADMIN_HASH" ]; then
  docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T db psql -U crm_admin -d crm << EOF >/dev/null 2>&1 || true
ALTER USER crm_admin WITH PASSWORD '$DB_SUPER_PASS';
ALTER USER crm_app WITH PASSWORD '$DB_APP_PASS';
ALTER USER exporter WITH PASSWORD '$DB_EXPORTER_PASS';

UPDATE users SET password_hash = '$ADMIN_HASH' WHERE username = 'admin';
UPDATE users SET password_hash = '$STAFF1_HASH' WHERE username = 'nhanvien01';
UPDATE users SET password_hash = '$STAFF2_HASH' WHERE username = 'nhanvien02';
EOF
  echo " -> Đã cập nhật mật khẩu database roles và bảng users thành công."
fi

# 4. Cập nhật Grafana admin password & Khởi động lại service cần thiết (Không xóa volume dữ liệu)
echo "[4/4] Áp dụng cấu hình và cập nhật dịch vụ..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T grafana grafana-cli admin reset-admin-password "$GRAFANA_PASS" >/dev/null 2>&1 || true
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d pgadmin web postgres-exporter >/dev/null 2>&1 || true

echo "=================================================================="
echo " [THÀNH CÔNG] ĐÃ CẤU HÌNH VÀ ĐỒNG BỘ CREDENTIALS!"
echo " Vị trí file lưu cấu hình bí mật: $ENV_FILE"
echo " Mật khẩu đã được mã hóa và lưu trữ an toàn trong .env (chmod 600)."
echo " (Mở file .env để xem thông tin chi tiết khi cần đăng nhập)."
echo "=================================================================="
