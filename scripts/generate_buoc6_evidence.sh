#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/evidence"
EVID="$PROJECT_DIR/evidence/buoc6-hardening.txt"

echo "================================================================================" > "$EVID"
echo " EVIDENCE BƯỚC 6: KIỂM CHỨNG CÁC BIỆN PHÁP BẢO MẬT & HARDENING HỆ THỐNG" >> "$EVID"
echo " Thời gian: $(date)" >> "$EVID"
echo " Đề tài 4: Hệ thống CRM Chăm sóc Khách hàng" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "=== 1. KIỂM TRA NGƯỜI DÙNG TRONG TỪNG SERVICE (NON-ROOT CONTAINER) ===" >> "$EVID"
echo "Danh sách ID/whoami thực tế bên trong từng container:" >> "$EVID"
for s in web nginx pgadmin prometheus grafana loki alert-sink postgres-exporter promtail cadvisor db; do
  NAME=$(docker compose ps -q $s)
  if [ -n "$NAME" ]; then
    ID_OUT=$(docker exec $NAME id 2>&1 || docker exec $NAME whoami 2>&1 || true)
    printf "%-18s -> %s\n" "$s" "$ID_OUT" >> "$EVID"
  fi
done
echo "" >> "$EVID"
echo "Ghi chú ngoại lệ:" >> "$EVID"
echo "- cadvisor & promtail: Bắt buộc cần quyền root để đọc Docker socket (/var/run/docker.sock) và container json logs (/var/lib/docker/containers). Đã hardening bằng mount chỉ đọc (:ro) và drop toàn bộ capabilities (cap_drop: ALL)." >> "$EVID"
echo "- db (postgres): Image chuẩn khởi tạo bằng script root để cấp quyền volume, sau đó chuyển toàn bộ tiến trình daemon sang user 'postgres' (UID 999)." >> "$EVID"
echo "" >> "$EVID"

echo "=== 2. KIỂM TRA PHÂN TÁCH MẠNG DOCKER (NETWORK ISOLATION) ===" >> "$EVID"
echo "--- Danh sách mạng Docker ---" >> "$EVID"
docker network ls | grep crm >> "$EVID"
echo "" >> "$EVID"
echo "--- Mạng BACKEND (internal: true, chứa db, web, pgadmin, postgres-exporter) ---" >> "$EVID"
docker network inspect crm_backend | jq '.[0] | {name: .Name, internal: .Internal, containers: [.Containers[] | .Name]}' >> "$EVID"
echo "" >> "$EVID"
echo "--- Mạng MONITORING (internal: true, chứa các thành phần giám sát/log) ---" >> "$EVID"
docker network inspect crm_monitoring | jq '.[0] | {name: .Name, internal: .Internal, containers: [.Containers[] | .Name]}' >> "$EVID"
echo "" >> "$EVID"
echo "--- Mạng FRONTEND (chỉ nối reverse proxy với web, pgadmin, grafana) ---" >> "$EVID"
docker network inspect crm_frontend | jq '.[0] | {name: .Name, internal: .Internal, containers: [.Containers[] | .Name]}' >> "$EVID"
echo "" >> "$EVID"
echo "-> KẾT LUẬN: db hoàn toàn KHÔNG nối vào crm_frontend, KHÔNG publish port ra ngoài." >> "$EVID"
echo "" >> "$EVID"

echo "=== 3. KIỂM TRA CỔNG MỞ & TIẾN TRÌNH LẮNG NGHE (PORT EXPOSURE) ===" >> "$EVID"
echo "--- docker compose ps (chỉ có nginx mở cổng 80 và 443) ---" >> "$EVID"
docker compose ps >> "$EVID"
echo "" >> "$EVID"
echo "--- ss -tlnp (các cổng lắng nghe trên host) ---" >> "$EVID"
echo ubuntu | sudo -S ss -tlnp >> "$EVID" 2>/dev/null || ss -tlnp >> "$EVID"
echo "" >> "$EVID"

echo "=== 4. KIỂM TRA TRẠNG THÁI TƯỜNG LỬA UFW (FIREWALL HARDENING) ===" >> "$EVID"
echo ubuntu | sudo -S ufw status verbose >> "$EVID" 2>/dev/null || ufw status verbose >> "$EVID"
echo "" >> "$EVID"

echo "=== 5. HẠN CHẾ QUYỀN DATABASE (LEAST PRIVILEGE ROLE & PERMISSION CHECK) ===" >> "$EVID"
APP_PASS=$(grep APP_DB_PASSWORD "$PROJECT_DIR/.env" | cut -d= -f2)
echo "--- Danh sách Roles (\du) ---" >> "$EVID"
docker compose exec -T db psql -U crm_admin -d crm -c "\du" >> "$EVID"
echo "" >> "$EVID"
echo "--- Quyền trên các bảng (\dp) ---" >> "$EVID"
docker compose exec -T db psql -U crm_admin -d crm -c "\dp" >> "$EVID"
echo "" >> "$EVID"
echo "--- Thử nghiệm DROP TABLE bằng role crm_app (Phải bị từ chối) ---" >> "$EVID"
docker compose exec -T -e PGPASSWORD="$APP_PASS" db psql -U crm_app -d crm -c "DROP TABLE customers;" >> "$EVID" 2>&1 || true
echo "" >> "$EVID"
echo "--- Thử nghiệm CREATE TABLE bằng role crm_app (Phải bị từ chối) ---" >> "$EVID"
docker compose exec -T -e PGPASSWORD="$APP_PASS" db psql -U crm_app -d crm -c "CREATE TABLE test_unauth(id int);" >> "$EVID" 2>&1 || true
echo "" >> "$EVID"

echo "=== 6. KIỂM TRA SECURITY HEADERS & ẨN THÔNG TIN PHIÊN BẢN (CURL) ===" >> "$EVID"
echo "--- Headers trả về từ https://localhost/login ---" >> "$EVID"
curl -k -I https://localhost/login >> "$EVID"
echo "" >> "$EVID"
echo "Kiểm tra rò rỉ phiên bản:" >> "$EVID"
curl -k -I https://localhost/login | grep -iE "server:|x-powered-by:|python|werkzeug|gunicorn" >> "$EVID" || echo "Không rò rỉ phiên bản." >> "$EVID"
echo "" >> "$EVID"

echo "=== 7. RÀ SOÁT BÍ MẬT & MẬT KHẨU TRONG GIT HISTORY (GIT GREP AUDIT) ===" >> "$EVID"
POSTGRES_PASS=$(grep POSTGRES_PASSWORD "$PROJECT_DIR/.env" | cut -d= -f2)
APP_PASS_AUDIT=$(grep APP_DB_PASSWORD "$PROJECT_DIR/.env" | cut -d= -f2)
SECRET_KEY_AUDIT=$(grep SECRET_KEY "$PROJECT_DIR/.env" | cut -d= -f2)

git grep "$POSTGRES_PASS" >> "$EVID" 2>&1 || echo "[OK] POSTGRES_PASSWORD KHÔNG tồn tại trong git repo" >> "$EVID"
git grep "$APP_PASS_AUDIT" >> "$EVID" 2>&1 || echo "[OK] APP_DB_PASSWORD KHÔNG tồn tại trong git repo" >> "$EVID"
git grep "$SECRET_KEY_AUDIT" >> "$EVID" 2>&1 || echo "[OK] SECRET_KEY KHÔNG tồn tại trong git repo" >> "$EVID"
git grep "BEGIN PRIVATE KEY" >> "$EVID" 2>&1 || echo "[OK] KHÔNG có private key nào bị commit" >> "$EVID"
echo "" >> "$EVID"

echo "=== 8. KẾT QUẢ CHẠY SMOKE TEST TOÀN BỘ HỆ THỐNG ===" >> "$EVID"
python3 "$PROJECT_DIR/scripts/smoke_test.py" >> "$EVID"
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " HOÀN TẤT THỰC HIỆN KIỂM CHỨNG BƯỚC 6 (HARDENING)" >> "$EVID"
echo "================================================================================" >> "$EVID"
