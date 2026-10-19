#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/evidence"
EVID="$PROJECT_DIR/evidence/buoc5-sucodo.txt"
LOKI_ID=$(docker compose ps -q loki 2>/dev/null || echo "crm-loki-1")
LOKI_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$LOKI_ID")
GF_PASS=$(grep GRAFANA_ADMIN_PASSWORD "$PROJECT_DIR/.env" | cut -d= -f2)

echo "================================================================================" > "$EVID"
echo " EVIDENCE BƯỚC 5: KỊCH BẢN SỰ CỐ AN TOÀN THÔNG TIN & TRUY VẾT LOG" >> "$EVID"
echo " Kịch bản: Brute-Force / Phá hoại xác thực vào hệ thống CRM" >> "$EVID"
echo " Thời gian: $(date)" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "=== 1. CHẠY KỊCH BẢN TẤN CÔNG GIẢ LẬP (scripts/simulate_bruteforce.sh) ===" >> "$EVID"
bash scripts/simulate_bruteforce.sh >> "$EVID"
echo "" >> "$EVID"

echo "Chờ 12 giây để Promtail đẩy log, Loki định chỉ mục và Grafana Alerting đánh giá..."
sleep 12

echo "=== 2. TRẠNG THÁI ALERT TRÊN GRAFANA ALERTING (API) ===" >> "$EVID"
echo "Endpoint: /grafana/api/prometheus/grafana/api/v1/alerts" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" https://192.168.207.128/grafana/api/prometheus/grafana/api/v1/alerts | jq . >> "$EVID"
echo "" >> "$EVID"

echo "Endpoint: /grafana/api/prometheus/grafana/api/v1/rules" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" https://192.168.207.128/grafana/api/prometheus/grafana/api/v1/rules | jq '.data.groups[0].rules[] | {name: .name, state: .state, health: .health, lastEvaluation: .lastEvaluation, alerts: .alerts}' >> "$EVID"
echo "" >> "$EVID"

echo "=== 3. LOG TỪ SERVICE ALERT-SINK (NHẬN WEBHOOK CẢNH BÁO) ===" >> "$EVID"
docker logs crm-alert-sink-1 --tail 35 >> "$EVID"
echo "" >> "$EVID"

echo "Payload JSON chi tiết lưu tại alert-sink (/alerts):" >> "$EVID"
docker exec crm-alert-sink-1 python3 -c '
import urllib.request, json
res = urllib.request.urlopen("http://localhost:5000/alerts")
data = json.loads(res.read().decode())
print(json.dumps(data[-1] if data else {}, indent=2))
' >> "$EVID"
echo "" >> "$EVID"

echo "=== 4. TRUY VẾT SỰ CỐ QUA 3 GÓC NHÌN TỪ LOG LOKI ===" >> "$EVID"
echo "" >> "$EVID"
echo "--- GÓC NHÌN 1: LOG TỪ NGINX REVERSE PROXY ---" >> "$EVID"
echo "Truy vấn: {job=\"nginx\"} |= \"POST /login\"" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="nginx"} |= "POST /login"' \
  --data-urlencode 'limit=20' | jq -r '.data.result[].values[][1]' | head -n 20 >> "$EVID"
echo "" >> "$EVID"

echo "--- GÓC NHÌN 2: LOG TỪ WEB APP FLASK (LOGIN_FAILED) ---" >> "$EVID"
echo "Truy vấn: {job=\"webapp\"} |= \"LOGIN_FAILED\"" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="webapp"} |= "LOGIN_FAILED"' \
  --data-urlencode 'limit=20' | jq -r '.data.result[].values[][1]' | head -n 20 >> "$EVID"
echo "" >> "$EVID"

echo "--- GÓC NHÌN 3: LOG TỪ ALERT-SINK TRONG LOKI ---" >> "$EVID"
echo "Truy vấn: {job=\"alert-sink\"}" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="alert-sink"}' \
  --data-urlencode 'limit=15' | jq -r '.data.result[].values[][1]' >> "$EVID"
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " HOÀN TẤT GHI EVIDENCE SỰ CỐ BƯỚC 5" >> "$EVID"
echo "================================================================================" >> "$EVID"
