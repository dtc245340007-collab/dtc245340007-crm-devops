#!/usr/bin/env bash
set -e

# Thư mục chứa chứng chỉ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/certs"
mkdir -p "$CERTS_DIR"

CERT_FILE="$CERTS_DIR/server.crt"
KEY_FILE="$CERTS_DIR/server.key"

echo "=== TỰ SINH CHỨNG CHỈ SSL/TLS CHO NGINX REVERSE PROXY ==="
echo "Địa chỉ CN: 192.168.207.128"
echo "Subject Alternative Names (SAN): IP:192.168.207.128, DNS:localhost, IP:127.0.0.1"

# Tạo chứng chỉ tự ký RSA 2048-bit, hạn 365 ngày với SAN
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=CRM DevOps/OU=IT/CN=192.168.207.128" \
    -addext "subjectAltName = IP:192.168.207.128,DNS:localhost,IP:127.0.0.1"

chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

echo "Đã tạo thành công:"
echo " - Khóa bí mật (Private Key): $KEY_FILE"
echo " - Chứng chỉ (Certificate):   $CERT_FILE"
echo "=========================================================="
