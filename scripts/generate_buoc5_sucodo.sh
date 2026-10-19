#!/bin/bash
set -e
cd ~/crm
EVID="evidence/buoc5-sucodo.txt"
LOKI_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' crm-loki-1)
GF_PASS=$(grep GRAFANA_ADMIN_PASSWORD ~/crm/.env | cut -d= -f2)

echo "================================================================================" > "$EVID"
echo " EVIDENCE B??C 5: K?CH B?N S? C? AN TO?N TH?NG TIN & TRUY V?T LOG" >> "$EVID"
echo " K?ch b?n: Brute-Force / Ph? ho?i x?c th?c v?o h? th?ng CRM" >> "$EVID"
echo " Th?i gian: $(date)" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "=== 1. CH?Y K?CH B?N T?N C?NG GI? L?P (scripts/simulate_bruteforce.sh) ===" >> "$EVID"
bash scripts/simulate_bruteforce.sh >> "$EVID"
echo "" >> "$EVID"

echo "Ch? 12 gi?y ?? Promtail ??y log, Loki ??nh ch? m?c v? Grafana Alerting ??nh gi?..."
sleep 12

echo "=== 2. TR?NG TH?I ALERT TR?N GRAFANA ALERTING (API) ===" >> "$EVID"
echo "Endpoint: /grafana/api/prometheus/grafana/api/v1/alerts" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" https://192.168.207.128/grafana/api/prometheus/grafana/api/v1/alerts | jq . >> "$EVID"
echo "" >> "$EVID"

echo "Endpoint: /grafana/api/prometheus/grafana/api/v1/rules" >> "$EVID"
curl -k -s -u "admin:$GF_PASS" https://192.168.207.128/grafana/api/prometheus/grafana/api/v1/rules | jq '.data.groups[0].rules[] | {name: .name, state: .state, health: .health, lastEvaluation: .lastEvaluation, alerts: .alerts}' >> "$EVID"
echo "" >> "$EVID"

echo "=== 3. LOG T? SERVICE ALERT-SINK (NH?N WEBHOOK C?NH B?O) ===" >> "$EVID"
docker logs crm-alert-sink-1 --tail 35 >> "$EVID"
echo "" >> "$EVID"

echo "Payload JSON chi ti?t l?u t?i alert-sink (/alerts):" >> "$EVID"
docker exec crm-alert-sink-1 python3 -c '
import urllib.request, json
res = urllib.request.urlopen("http://localhost:5000/alerts")
data = json.loads(res.read().decode())
print(json.dumps(data[-1] if data else {}, indent=2))
' >> "$EVID"
echo "" >> "$EVID"

echo "=== 4. TRUY V?T S? C? QUA 3 G?C NH?N T? LOG LOKI ===" >> "$EVID"
echo "" >> "$EVID"
echo "--- G?C NH?N 1: LOG T? NGINX REVERSE PROXY ---" >> "$EVID"
echo "Truy v?n: {job=\"nginx\"} |= \"POST /login\"" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="nginx"} |= "POST /login"' \
  --data-urlencode 'limit=20' | jq -r '.data.result[].values[][1]' | head -n 20 >> "$EVID"
echo "" >> "$EVID"

echo "--- G?C NH?N 2: LOG T? WEB APP FLASK (LOGIN_FAILED) ---" >> "$EVID"
echo "Truy v?n: {job=\"webapp\"} |= \"LOGIN_FAILED\"" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="webapp"} |= "LOGIN_FAILED"' \
  --data-urlencode 'limit=20' | jq -r '.data.result[].values[][1]' | head -n 20 >> "$EVID"
echo "" >> "$EVID"

echo "--- G?C NH?N 3: LOG T? ALERT-SINK TRONG LOKI ---" >> "$EVID"
echo "Truy v?n: {job=\"alert-sink\"}" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="alert-sink"}' \
  --data-urlencode 'limit=15' | jq -r '.data.result[].values[][1]' >> "$EVID"
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " HO?N T?T GHI EVIDENCE S? C? B??C 5" >> "$EVID"
echo "================================================================================" >> "$EVID"
