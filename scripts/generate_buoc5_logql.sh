#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/evidence"
EVID="$PROJECT_DIR/evidence/buoc5-logql.txt"
LOKI_ID=$(docker compose ps -q loki 2>/dev/null || echo "crm-loki-1")
LOKI_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$LOKI_ID")

echo "================================================================================" > "$EVID"
echo " EVIDENCE BƯỚC 5: TRUY VẤN LOGQL QUA LOKI API (/loki/api/v1/query_range)" >> "$EVID"
echo " Thời gian: $(date)" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo " Loki Endpoint: http://$LOKI_IP:3100" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "### Q1: Lỗi HTTP 5xx của Nginx" >> "$EVID"
echo "Query: {job=\"nginx\"} |~ \"\\\" 5[0-9]{2} \"" >> "$EVID"
echo "Mô tả: Lọc toàn bộ access log của Nginx có chứa mã phản hồi HTTP 5xx (500, 502, 503, 504)." >> "$EVID"
echo "--- JSON Output ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="nginx"} |~ "\" 5[0-9]{2} "' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q2: Lỗi/ngoại lệ ứng dụng Flask CRM Webapp" >> "$EVID"
echo "Query: {job=\"webapp\"} |~ \"(?i)(error|exception|fail)\"" >> "$EVID"
echo "Mô tả: Lọc các dòng log chứa từ khóa error, exception, fail (không phân biệt hoa thường)." >> "$EVID"
echo "--- JSON Output (Top 5 mẫu) ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="webapp"} |~ "(?i)(error|exception|fail)"' \
  --data-urlencode 'limit=5' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q3: Đăng nhập thất bại (LOGIN_FAILED)" >> "$EVID"
echo "Query: {job=\"webapp\"} |= \"LOGIN_FAILED\"" >> "$EVID"
echo "Mô tả: Lọc chính xác các sự kiện đăng nhập thất bại do ứng dụng CRM web ghi nhận." >> "$EVID"
echo "--- JSON Output (Top 5 mẫu) ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="webapp"} |= "LOGIN_FAILED"' \
  --data-urlencode 'limit=5' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q4: Thống kê số lần login fail theo phút" >> "$EVID"
echo "Query: sum(count_over_time({job=\"webapp\"} |= \"LOGIN_FAILED\" [1m]))" >> "$EVID"
echo "Mô tả: Metric query đếm tổng số dòng LOGIN_FAILED trong từng cửa sổ 1 phút." >> "$EVID"
echo "--- JSON Output (Ma trận mẫu theo thời gian) ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query=sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "### Q5: PostgreSQL log lỗi (error/fatal/panic)" >> "$EVID"
echo "Query: {job=\"postgres\"} |~ \"(?i)(error|fatal|panic)\"" >> "$EVID"
echo "Mô tả: Lọc các dòng log ghi nhận lỗi từ hệ quản trị cơ sở dữ liệu PostgreSQL." >> "$EVID"
echo "--- JSON Output ---" >> "$EVID"
curl -s -G "http://$LOKI_IP:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="postgres"} |~ "(?i)(error|fatal|panic)"' | jq . >> "$EVID"
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " HOÀN TẤT THỰC HIỆN 5 CÂU TRUY VẤN LOGQL" >> "$EVID"
echo "================================================================================" >> "$EVID"
