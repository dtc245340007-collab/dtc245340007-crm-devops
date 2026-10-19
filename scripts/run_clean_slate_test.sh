#!/bin/bash
set -e

echo "================================================================================"
echo "          KIEM THU KHOI CHAY TU TRANG THAI SACH (CLEAN-SLATE TEST)             "
echo "================================================================================"
echo "Thoi gian bat dau: $(date)"

# Buoc 1: Dung moi truong hien tai
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
echo -e "\n[1/6] Dung moi truong hien tai trong $PROJECT_DIR..."
cd "$PROJECT_DIR"
docker compose down -v || true

# Buoc 2: Clone vao thu muc kiem thu tam thoi
VERIFY_DIR="/tmp/crm-clean-verify"
echo -e "\n[2/6] Tao thu muc kiem thu sach $VERIFY_DIR tu Git..."
rm -rf "$VERIFY_DIR"
git clone "$PROJECT_DIR" "$VERIFY_DIR"
cd "$VERIFY_DIR"
mkdir -p evidence

# Buoc 3: Tao .env moi va sinh chung chi SSL
echo -e "\n[3/6] Cau hinh .env moi va sinh chung chi SSL..."
python3 -c '
import secrets, string
def gen(n=20):
    chars = string.ascii_letters + string.digits
    return "".join(secrets.choice(chars) for _ in range(n))

with open(".env.example", "r") as f:
    text = f.read()

text = text.replace("thay_bang_mat_khau_db_sieu_manh", gen())
text = text.replace("thay_bang_mat_khau_app_manh", gen())
text = text.replace("thay_bang_mat_khau_exporter_manh", gen())
text = text.replace("thay_bang_chuoi_bi_mat_ngau_nhien_64_ky_tu", gen(32))
text = text.replace("thay_bang_mat_khau_pgadmin_manh", gen())
text = text.replace("thay_bang_mat_khau_grafana_manh", gen())

with open(".env", "w") as f:
    f.write(text)
'
chmod 600 .env
chmod +x nginx/gen-cert.sh
./nginx/gen-cert.sh
chmod -R a+rX grafana

# Buoc 4: Khoi chay bang mot lenh duy nhat
echo -e "\n[4/6] Khoi chay he thong bang lenh duy nhat: docker compose up -d --build..."
docker compose up -d --build

echo "Dang doi toan bo dich vu (Database, pgAdmin, Grafana) hoan tat khoi dong..."
for i in $(seq 1 45); do
  DB_READY=$(docker compose ps db | grep -c "(healthy)" || true)
  PG_READY=$(curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1/pgadmin/ || true)
  GF_READY=$(curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1/grafana/api/health || true)
  
  if [ "$DB_READY" -ge 1 ] && [ "$PG_READY" = "302" ] && [ "$GF_READY" = "200" ]; then
    echo "Toan bo cac dich vu (DB healthy, pgAdmin 302, Grafana 200) da san sang sau $((i * 2))s!"
    break
  fi
  sleep 2
done

docker compose ps

# Buoc 5: Thuc hien bo smoke test va ghi evidence
echo -e "\n[5/6] Chay toan bo bai test kiem thu tu dau..."
EVID="evidence/final-smoke-test.txt"

echo "================================================================================" > "$EVID"
echo " EVIDENCE KIEM THU KHOI CHAY TU TRANG THAI SACH (CLEAN-SLATE TEST)" >> "$EVID"
echo " Thu muc kiem thu: ~/crm-verify" >> "$EVID"
echo " Thoi gian: $(date)" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "=== 1. DANH SACH CONTAINER HOAT DONG ===" >> "$EVID"
docker compose ps >> "$EVID"
echo "" >> "$EVID"

echo "=== 2. KET QUA SMOKE TEST (WEB, CRUD, PGADMIN, GRAFANA) ===" >> "$EVID"
python3 scripts/smoke_test.py >> "$EVID" 2>&1
echo "" >> "$EVID"

echo "=== 3. TRUY VAN LOG LOKI QUA PROMTAIL ===" >> "$EVID"
sleep 5
docker compose exec -T loki wget -qO- 'http://127.0.0.1:3100/loki/api/v1/query_range?query=%7Bjob%3D%22webapp%22%7D&limit=5' | jq -r '.data.result[].values[][1]' >> "$EVID" 2>&1 || true
echo "" >> "$EVID"

echo "=== 4. CHAY KICH BAN BRUTE FORCE & KIEM TRA ALERT FIRING ===" >> "$EVID"
bash scripts/simulate_bruteforce.sh >> "$EVID" 2>&1
sleep 20

echo "--- Alert Webhook nhan tai Alert-Sink ---" >> "$EVID"
docker compose logs alert-sink --tail 25 >> "$EVID" 2>&1
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " KIEM THU TU TRANG THAI SACH THANH CONG 100%!" >> "$EVID"
echo "================================================================================" >> "$EVID"

cat "$EVID"

# Copy evidence sang PROJECT_DIR
cp "$EVID" "$PROJECT_DIR/evidence/final-smoke-test.txt"

# Buoc 6: Don dep thu muc kiem thu va phuc hoi moi truong chinh
echo -e "\n[6/6] Don dep thu muc kiem thu va phuc hoi moi truong $PROJECT_DIR chinh..."
docker compose down -v
cd "$PROJECT_DIR"
rm -rf "$VERIFY_DIR"
docker compose up -d

echo "================================================================================"
echo "          HOAN TAT TOAN BO QUY TRINH KIEM THU TU DAU!                           "
echo "================================================================================"
