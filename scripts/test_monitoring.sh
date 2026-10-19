#!/bin/bash
set -e
cd ~/crm
EVID="evidence/buoc4-giamsat.txt"

PROM_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' crm-prometheus-1)
GF_PASS=$(grep GRAFANA_ADMIN_PASSWORD .env | cut -d= -f2)

echo "=== EVIDENCE B??C 4: GI?M S?T PROMETHEUS + GRAFANA ===" > "$EVID"
echo "Th?i gian: $(date)" >> "$EVID"
echo "H? th?ng: CRM Ch?m s?c Kh?ch h?ng (?? t?i 4)" >> "$EVID"
echo "MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "Prometheus Internal IP: $PROM_IP" >> "$EVID"
echo "" >> "$EVID"

echo "--- 1. DANH S?CH CONTAINER V? TR?NG TH?I ---" >> "$EVID"
docker compose ps >> "$EVID"
echo "" >> "$EVID"

echo "--- 2. PROMETHEUS TARGETS TR?NG TH?I ---" >> "$EVID"
curl -s "http://$PROM_IP:9090/api/v1/targets" | jq -r '.data.activeTargets[] | "\(.labels.job) -> \(.labels.instance) [health: \(.health)]"' >> "$EVID"
echo "" >> "$EVID"

echo "--- 3. METRIC TR??C KHI SINH T?I ---" >> "$EVID"
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

echo "--- 4. SINH T?I (200 requests HTTPS v?o CRM Web & DB) ---" >> "$EVID"
for i in $(seq 1 200); do
  curl -k -s -o /dev/null https://192.168.207.128/health
done
echo "?? th?c hi?n 200 requests th?nh c?ng." >> "$EVID"
sleep 16

echo "--- 5. METRIC SAU KHI SINH T?I (KI?M TRA THAY ??I) ---" >> "$EVID"
echo "[Nginx Requests Total]:" >> "$EVID"
curl -s "http://$PROM_IP:9090/api/v1/query?query=nginx_http_requests_total" | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Postgres Transactions Commit Count sau t?i]:" >> "$EVID"
curl -s -G "http://$PROM_IP:9090/api/v1/query" --data-urlencode 'query=pg_stat_database_xact_commit{datname="crm"}' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "--- 6. KI?M TRA GRAFANA HTTP ENDPOINT V? PROVISIONING API ---" >> "$EVID"
echo "[CURL Header https://192.168.207.128/grafana/]:" >> "$EVID"
curl -k -I https://192.168.207.128/grafana/ >> "$EVID"
echo "" >> "$EVID"

echo "[Grafana Datasources API]:" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" https://192.168.207.128/grafana/api/datasources | jq . >> "$EVID"
echo "" >> "$EVID"

echo "[Grafana Provisioned Dashboards API]:" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" "https://192.168.207.128/grafana/api/search?query=CRM" | jq . >> "$EVID"
echo "" >> "$EVID"

echo "=== HO?N TH?NH GHI EVIDENCE B??C 4 ==="
chmod +x ~/crm/scripts/test_monitoring.sh
