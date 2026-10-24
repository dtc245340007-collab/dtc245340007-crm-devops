#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/certs"
mkdir -p "$CERTS_DIR"

cd "$CERTS_DIR"

echo "=== 1. TẠO LOCAL ROOT CA (CHỨNG CHỈ GỐC) ==="
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.crt \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=CRM DevOps/OU=IT/CN=CRM DevOps Root CA" \
    -addext "basicConstraints = critical, CA:TRUE" \
    -addext "keyUsage = critical, keyCertSign, cRLSign"

echo "=== 2. TẠO KHÓA BÍ MẬT & YÊU CẦU KÝ (CSR) CHO SERVER ==="
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
    -subj "/C=VN/ST=Hanoi/L=Hanoi/O=CRM DevOps/OU=IT/CN=192.168.207.128"

echo "=== 3. TẠO TỆP CẤU HÌNH MỞ RỘNG (SAN & EXTENDED KEY USAGE) ==="
cat << 'EOF' > server.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = 192.168.207.128
DNS.1 = localhost
IP.2 = 127.0.0.1
EOF

echo "=== 4. KÝ CHỨNG CHỈ SERVER BẰNG ROOT CA ==="
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial \
    -out server.crt -days 3650 -sha256 -extfile server.ext

rm -f server.csr server.ext rootCA.srl
chmod 644 rootCA.crt server.crt server.key rootCA.key

echo "=== 5. KIỂM TRA TÍNH HỢP LỆ CỦA CHUỖI CHỨNG CHỈ ==="
openssl verify -CAfile rootCA.crt server.crt

echo "HOÀN TẤT!"
