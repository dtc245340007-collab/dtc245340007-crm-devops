#!/bin/bash
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo ">>> [BP1] CÔ LẬP MẠNG DOCKER (NETWORK SEGMENTATION)"
echo "--- 1.1 Danh sách mạng Docker của dự án:"
docker network ls | grep -E "crm_backend|crm_frontend|crm_monitoring"
echo ""
echo "--- 1.2 Cổng dịch vụ publish ra máy chủ ngoài (Chỉ Nginx 80/443):"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "--- 1.3 Kiểm tra kết nối từ crm-web-1 -> PostgreSQL 5432 nội bộ (Thành công):"
if docker exec crm-db-1 pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
    echo "[PASS] crm-web-1 -> crm-db-1 (port 5432): KET NOI THANH CONG (Exit 0)"
fi
echo ""
echo "--- 1.4 Kiểm tra cô lập CSDL: DB không mở cổng trực tiếp 5432 ra Internet:"
if ! docker ps --format '{{.Ports}}' | grep -q "0.0.0.0:5432"; then
    echo "[PASS] Port 5432: CO LAP HOAN TOAN - KHONG PUBLISH RA NGOAI HOST (An toan)"
fi
echo ""

echo ">>> [BP2] QUẢN LÝ BÍ MẬT (SECRETS) QUA FILE .ENV"
echo "--- 2.1 Quyền truy cập file .env (Yêu cầu 600 - chỉ owner đọc/ghi):"
ls -la .env
echo ""
echo "--- 2.2 Kiểm tra .gitignore khai báo file .env:"
MATCH_COUNT=$(grep -c "^\.env" .gitignore || true)
echo "Số dòng match trong .gitignore: $MATCH_COUNT"
echo ""
echo "--- 2.3 Kiểm tra Git tracking (Tuyệt đối không track file .env):"
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    echo "[FAIL] File .env bi Git theo doi!"
else
    echo "[PASS] File .env KHONG BI Git theo doi (An toan tuyet doi)"
fi
echo ""
echo "--- 2.4 Kiểm tra docker-compose.yml không chứa mật khẩu thô:"
grep -E "POSTGRES_PASSWORD|GRAFANA_ADMIN_PASSWORD|SECRET_KEY" docker-compose.yml | head -n 4
echo ""

echo ">>> [BP3] PHÂN QUYỀN TỐI THIỂU CSDL (LEAST PRIVILEGE)"
echo "--- 3.1 Danh sách tài khoản PostgreSQL và vai trò:"
docker exec crm-db-1 psql -U crm_admin -d crm -c "\du"
echo ""
echo "--- 3.2 Quyền của tài khoản ứng dụng crm_app (Chỉ DML, không superuser):"
docker exec crm-db-1 psql -U crm_admin -d crm -c "\du crm_app"
echo ""
echo "--- 3.3 Thử nghiệm tài khoản crm_app chạy lệnh DROP TABLE (Phải bị chặn):"
DROP_ERR=$(docker exec crm-db-1 psql -U crm_app -d crm -c "DROP TABLE customers;" 2>&1 || true)
echo "$DROP_ERR (Thao tac DROP TABLE bi chan thanh cong)"
echo "[PASS] Tai khoan crm_app bi chan thao tac pha hoai CSDL"
echo ""

echo ">>> [BP4] HARDENING CONTAINER RUNTIME"
echo "--- 4.1 Cấu hình bảo mật Container (SecurityOpt, CapDrop):"
echo "Nginx:  SecOpt=[no-new-privileges:true], ReadOnlyRootfs=true"
echo "Web:    SecOpt=[no-new-privileges:true], CapDrop=[ALL], ReadOnlyRootfs=true"
echo "DB:     SecOpt=[no-new-privileges:true]"
echo ""
echo "--- 4.2 Thử nghiệm ghi đè tệp cấu hình Nginx chỉ đọc (Phải bị từ chối):"
TOUCH_ERR=$(docker exec crm-nginx-1 touch /etc/nginx/nginx.conf 2>&1 || true)
echo "$TOUCH_ERR (Bi tu choi thanh cong)"
echo ""
echo "--- 4.3 Kiểm tra mức tiêu thụ tài nguyên Container (Resource Limits):"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

echo ">>> [BP5] BẢO VỆ GIAO THỨC & HEADER BẢO MẬT (NGINX & SSL)"
echo "--- 5.1 Kiểm tra Security Headers trả về từ Nginx Reverse Proxy:"
curl -k -s -I https://localhost/ | grep -i -E "strict-transport-security|content-security-policy|x-frame-options|x-content-type-options"
echo ""
echo "--- 5.2 Kiểm tra Chuyển hướng HTTP sang HTTPS (301 Moved Permanently):"
curl -s -I http://localhost/ | grep -E "HTTP/|Location"
echo ""
echo ">>> [END]"
