#!/bin/bash
set -e
cd ~/crm
EVID="evidence/buoc5-logql.txt"
LOKI_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' crm-loki-1)

echo "================================================================================" > "$EVID"
echo " EVIDENCE B??C 5: TRUY V?N LOGQL QUA LOKI API (/loki/api/v1/query_range)" >> "$EVID"
echo " Th?i gian: $(date)" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo " Loki Endpoint: http://$LOKI_IP:3100" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "### Q1: L?i HTTP 5xx c?a Nginx" >> "$EVID"
echo "Query: {job=\"nginx\"} |~ \"\\\" 5[0-9]{2} \"" >> "$EVID"
echo "M? t?: L?c to?n b? access log c?a Nginx c? ch?a m? ph?n h?i HTTP 5xx (500, 502, 503, 504)." >> "$EVID"
echo "--- JSON Output ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="nginx"} |~ "\" 5[0-9]{2} "' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q2: L?i/ngo?i l? ?ng d?ng Flask CRM Webapp" >> "$EVID"
echo "Query: {job=\"webapp\"} |~ \"(?i)(error|exception|fail)\"" >> "$EVID"
echo "M? t?: L?c c?c d?ng log ch?a t? kh?a error, exception, fail (kh?ng ph?n bi?t hoa th??ng)." >> "$EVID"
echo "--- JSON Output (Top 5 m?u) ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="webapp"} |~ "(?i)(error|exception|fail)"' \
  --data-urlencode 'limit=5' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q3: ??ng nh?p th?t b?i (LOGIN_FAILED)" >> "$EVID"
echo "Query: {job=\"webapp\"} |= \"LOGIN_FAILED\"" >> "$EVID"
echo "M? t?: L?c ch?nh x?c c?c s? ki?n ??ng nh?p th?t b?i do ?ng d?ng CRM web ghi nh?n." >> "$EVID"
echo "--- JSON Output (Top 5 m?u) ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="webapp"} |= "LOGIN_FAILED"' \
  --data-urlencode 'limit=5' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q4: Th?ng k? s? l?n login fail theo ph?t" >> "$EVID"
echo "Query: sum(count_over_time({job=\"webapp\"} |= \"LOGIN_FAILED\" [1m]))" >> "$EVID"
echo "M? t?: Metric query ??m t?ng s? d?ng LOGIN_FAILED trong t?ng c?a s? 1 ph?t." >> "$EVID"
echo "--- JSON Output (Ma tr?n m?u theo th?i gian) ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query=sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q5: PostgreSQL log l?i (error/fatal/panic)" >> "$EVID"
echo "Query: {job=\"postgres\"} |~ \"(?i)(error|fatal|panic)\"" >> "$EVID"
echo "M? t?: L?c c?c d?ng log ghi nh?n l?i t? h? qu?n tr? c? s? d? li?u PostgreSQL." >> "$EVID"
echo "--- JSON Output ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="postgres"} |~ "(?i)(error|fatal|panic)"' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " HO?N T?T TH?C HI?N 5 C?U TRUY V?N LOGQL" >> "$EVID"
echo "================================================================================" >> "$EVID"
