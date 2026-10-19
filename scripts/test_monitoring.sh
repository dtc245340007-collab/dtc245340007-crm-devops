#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/evidence"
EVID="$PROJECT_DIR/evidence/buoc4-giamsat.txt"

PROM_ID=$(docker compose ps -q prometheus 2>/dev/null || echo "crm-prometheus-1")
PROM_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PROM_ID")
GF_PASS=$(grep GRAFANA_ADMIN_PASSWORD "$PROJECT_DIR/.env" | cut -d= -f2)

echo "=== EVIDENCE BƯỚC 4: GIÁM SÁT PROMETHEUS + GRAFANA ===" > "$EVID"
echo "Thời gian: $(date)" >> "$EVID"
echo "Hệ thống: CRM Chăm sóc Khách hàng (Đề tài 4)" >> "$EVID"
echo "MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "Prometheus Internal IP: $PROM_IP" >> "$EVID"
echo "" >> "$EVID"

echo "--- 1. DANH SÁCH CONTAINER VÀ TRẠNG THÁI ---" >> "$EVID"
docker compose ps >> "$EVID"
echo "" >> "$EVID"

echo "--- 2. PROMETHEUS TARGETS TRẠNG THÁI ---" >> "$EVID"
curl -s "http://$PROM_IP:9090/api/v1/targets" | jq -r '.data.activeTargets[] | "\(.labels.job) -> \(.labels.instance) [health: \(.health)]"' >> "$EVID"
echo "" >> "$EVID"

echo "--- 3. METRIC TRƯỚC KHI SINH TẢI ---" >> "$EVID"
echo "[Nginx active connections]:" >> "$EVID"
curl -s "http://$PROM_IP:9090/api/v1/query?query=nginx_connections_active" | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Postgres Up Status]:" >> "$EVID"
curl -s "http://$PROM_IP:9090/api/v1/query?query=pg_up" | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Postgres Transactions Commit Count (datname=crm)]:" >> "$EVID"
curl -s -G "http://$PROM_IP:9090/api/v1/query" --data-urlencode 'query=pg_stat_database_xact_commit{datname="crm"}' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Container Memory Usage (sample)]:" >> "$EVID"
curl -s -G "http://$PROM_IP:9090/api/v1/query" --data-urlencode 'query=container_memory_usage_bytes{name=~".*crm.*"}' | jq -r '.data.result[] | "\(.metric.name): \(.value[1]) bytes"' | head -n 10 >> "$EVID"
echo "" >> "$EVID"

echo "--- 4. SINH TẢI (200 requests HTTPS vào CRM Web & DB) ---" >> "$EVID"
for i in $(seq 1 200); do
  curl -k -s -o /dev/null https://localhost/health
done
echo "Đã thực hiện 200 requests thành công." >> "$EVID"
sleep 16

echo "--- 5. METRIC SAU KHI SINH TẢI (KIỂM TRA THAY ĐỔI) ---" >> "$EVID"
echo "[Nginx Requests Total]:" >> "$EVID"
curl -s "http://$PROM_IP:9090/api/v1/query?query=nginx_http_requests_total" | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Postgres Transactions Commit Count sau tải]:" >> "$EVID"
curl -s -G "http://$PROM_IP:9090/api/v1/query" --data-urlencode 'query=pg_stat_database_xact_commit{datname="crm"}' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "--- 6. KIỂM TRA GRAFANA HTTP ENDPOINT VÀ PROVISIONING API ---" >> "$EVID"
echo "[CURL Header https://localhost/grafana/]:" >> "$EVID"
curl -k -I https://localhost/grafana/ >> "$EVID"
echo "" >> "$EVID"

echo "[Grafana Datasources API]:" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" https://localhost/grafana/api/datasources | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Grafana Provisioned Dashboards API]:" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" "https://localhost/grafana/api/search?query=CRM" | jq . >> "$EVID"
echo "" >> "$EVID"

echo "=== HOÀN THÀNH GHI EVIDENCE BƯỚC 4 ==="
chmod +x "$SCRIPT_DIR/test_monitoring.sh"
