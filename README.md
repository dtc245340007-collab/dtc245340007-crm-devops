# dtc245340007-crm-devops

Bài tập lớn môn: **Triển khai và Quản trị Hệ thống Phần mềm**  
Họ và tên: **NGUYEN THI QUYNH THO**  
MSSV: **dtc245340007**  
Đề tài 4: **Hệ thống CRM Chăm sóc Khách hàng**  

---

## 1. Giới thiệu đề tài
Hệ thống CRM Chăm sóc Khách hàng nội bộ hỗ trợ quản lý khách hàng, quản lý người liên hệ (contacts), ghi nhận và theo dõi lịch sử tương tác (cuộc gọi, email, họp, ghi chú), nhắc lịch chăm sóc và phân quyền theo 2 vai trò:
- **Quản lý (Manager)**: Quản lý khách hàng toàn diện, phân công nhân viên, quản lý nhân viên, xem báo cáo tổng thể.
- **Nhân viên CSKH (Staff)**: Quản lý khách hàng được phân công, ghi nhận và cập nhật tương tác của mình.

---

## 2. Kiến trúc Công nghệ
- **Backend / Web**: Python 3.12 (Flask + Gunicorn)
- **Database**: PostgreSQL 16.4 (Non-superuser role `crm_app` riêng biệt cho ứng dụng)
- **Database Admin UI**: pgAdmin 4 (8.11)
- **Reverse Proxy**: Nginx (1.27-alpine) (HTTPS tự ký + Security Headers + Gzip + Rate Limit + Subpath Routing)
- **Monitoring**: Prometheus + Grafana (Bước 4)
- **Logging**: Loki + Promtail (Bước 5)
- **Orchestration**: Docker Compose (chạy với 1 lệnh: `docker compose up -d`)

---

## 3. Cấu trúc Thư mục Dự án
```
.
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── web/                     # Ứng dụng Flask CRM
│   ├── Dockerfile
│   ├── requirements.txt
│   └── src/
├── db/                      # Scripts khởi tạo cơ sở dữ liệu
│   ├── 01-init.sh           # Tạo role crm_app
│   └── init.sql             # Tạo bảng, index và seed dữ liệu
├── nginx/                   # Nginx reverse proxy & SSL
│   ├── gen-cert.sh          # Script tự sinh chứng chỉ SSL/TLS
│   ├── nginx.conf           # Cấu hình Nginx HTTPS & Security Headers
│   └── certs/               # Thư mục chứa cert (server.key được gitignore)
├── pgadmin/                 # Cấu hình kết nối pgAdmin
│   └── servers.json
├── prometheus/              # Cấu hình Prometheus scraper
├── grafana/                 # Dashboards & Datasources provisioned
│   └── provisioning/
├── loki/                    # Cấu hình Loki
├── promtail/                # Cấu hình Promtail log shipping
├── scripts/                 # Kịch bản kiểm thử & tự động hóa
├── evidence/                # Minh chứng kiểm tra các bước (gitignored)
└── docs/                    # Tài liệu kỹ thuật
```

---

## 4. Hướng dẫn Khởi tạo & Triển khai

### Bước 1: Chuẩn bị chứng chỉ SSL/TLS
Tự sinh chứng chỉ SSL/TLS tự ký có SAN (`IP:192.168.207.128`, `DNS:localhost`) bằng script:
```bash
chmod +x nginx/gen-cert.sh
./nginx/gen-cert.sh
```
Script sẽ sinh ra 2 file trong `nginx/certs/`:
- `server.crt`: Chứng chỉ công khai.
- `server.key`: Khóa bí mật (đã được cấu hình trong `.gitignore`, không đưa lên repo).

### Bước 2: Cấu hình biến môi trường
Sao chép file mẫu `.env.example` thành `.env` và đặt mật khẩu bảo mật:
```bash
cp .env.example .env
# Chỉnh sửa mật khẩu an toàn trong .env
chmod 600 .env
```

### Bước 3: Khởi chạy toàn bộ hệ thống
Khởi chạy hệ thống bằng Docker Compose:
```bash
docker compose up -d --build
```

### Bước 4: Truy cập hệ thống
- **Ứng dụng CRM Web:** `https://192.168.207.128` (hoặc `https://localhost`)
  - Chuyển hướng tự động từ HTTP (port 80) sang HTTPS (port 443).
  - Trình duyệt sẽ hiển thị cảnh báo chứng chỉ tự ký -> chọn *Nâng cao (Advanced)* > *Tiếp tục truy cập (Proceed)*.
- **Trang quản trị pgAdmin:** `https://192.168.207.128/pgadmin/`
  - Đăng nhập bằng email và mật khẩu cấu hình trong `.env`.

---

## 5. Gi?m s?t H? th?ng (Prometheus & Grafana)

H? th?ng t?ch h?p gi?m s?t to?n di?n v?i Prometheus v? Grafana theo m? h?nh m?ng n?i b? c? l?p (kh?ng expose port tr?c ti?p ra ngo?i, truy c?p Grafana qua Nginx reverse proxy):

### 5.1. C?c d?ch v? gi?m s?t
1. **Prometheus (`prom/prometheus:v2.54.1`)**: Thu th?p s? li?u chu k? 15s, l?u tr? tr?n volume `prometheus_data` retention 7 ng?y. Scrape 4 targets:
   - `prometheus` (localhost:9090): Gi?m s?t tr?ng th?i Prometheus server.
   - `cadvisor` (cadvisor:8080): Thu th?p CPU, RAM, Network I/O c?a to?n b? Docker container.
   - `nginx` (nginx-exporter:9113): Thu th?p active connections, requests count t? `/nginx_status`.
   - `postgres` (postgres-exporter:9187): K?t n?i PostgreSQL b?ng user `exporter` c? quy?n `pg_monitor`.
2. **Grafana (`grafana/grafana:11.2.0`)**: 
   - Truy c?p t?i: `https://192.168.207.128/grafana/` (ho?c `https://localhost/grafana/`).
   - T?i kho?n ??ng nh?p qu?n tr? l?y t? `.env` (`GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`).
   - T? ??ng n?p s?n (Provisioning) Datasource Prometheus v? 3 Dashboards chuy?n d?ng trong th? m?c **CRM**:
     - **CRM - Containers**: Gi?m s?t CPU/RAM/Network t?t c? containers (cAdvisor).
     - **CRM - Nginx**: Gi?m s?t l?u l??ng k?t n?i, tr?ng th?i HTTP, requests/s.
     - **CRM - PostgreSQL**: Gi?m s?t k?t n?i DB, transactions commit/rollback, cache hit ratio, k?ch th??c database.

### 5.2. Kh?i t?o role cho Postgres Exporter (n?u d?ng database c? s?n)
N?u volume c? s? d? li?u ?? t?n t?i t? tr??c, t?o role `exporter` v?i quy?n t?i thi?u:
```bash
docker compose exec db psql -U crm_admin -d crm -c "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'exporter') THEN
    CREATE ROLE exporter WITH LOGIN PASSWORD 'M?t_kh?u_t?_env';
    GRANT pg_monitor TO exporter;
  END IF;
END \$\$;
"
```

### 5.3. Ki?m th? gi?m s?t
Ch?y script ki?m tra tr?ng th?i targets v? sinh t?i:
```bash
chmod +x scripts/test_monitoring.sh
./scripts/test_monitoring.sh
```
K?t qu? ghi nh?n t?i `evidence/buoc4-giamsat.txt`.

---

## 6. H? th?ng Qu?n tr? Nh?t k? T?p trung & C?nh b?o S? c? (Loki + Promtail)

H? th?ng t?ch h?p gi?i ph?p qu?n tr? log t?p trung to?n di?n theo chu?n Cloud-Native v?i Loki, Promtail v? Grafana Alerting.

### 6.1. Ki?n tr?c H? t?ng Logging
1. **Loki (`grafana/loki:2.9.2`)**: L?u tr? v? ??nh ch? m?c metadata log theo ??nh d?ng filesystem ??n gi?n, chu k? l?u tr? (retention) 7 ng?y tr?n volume `loki_data`.
2. **Promtail (`grafana/promtail:3.0.0`)**: Agent ??c log container qua `/var/run/docker.sock` v? `/var/lib/docker/containers/`.
   - C? ch? ph?t hi?n t? ??ng `docker_sd_configs` v?i b? l?c ch? ??nh `com.docker.compose.project=crm`.
   - G?n nh?n chu?n x?c: `container`, `compose_service`, v? ph?n lo?i `job`:
     - `job="nginx"` cho Nginx Reverse Proxy.
     - `job="webapp"` cho ?ng d?ng CRM Flask/Gunicorn.
     - `job="postgres"` cho PostgreSQL Database.
   - Pipeline ph?n t?ch log Nginx: Tr?ch xu?t m? ph?n h?i HTTP `status` l?m nh?n ki?m so?t (low cardinality) m? kh?ng ??nh nh?n ??a ch? IP ?? tr?nh b?ng n? cardinality.
3. **Alert-Sink (`alert-sink`)**: D?ch v? webhook n?i b? si?u nh? ti?p nh?n v? ghi nh?n c?nh b?o s? c? b?o m?t t? Grafana Alerting.

### 6.2. Dashboard "CRM - Logs"
Truy c?p t?i: `https://192.168.207.128/grafana/d/crm-logs/crm-logs`
Bao g?m 4 panels nghi?p v?:
- **??ng Nh?p Th?t B?i (LOGIN_FAILED / ph?t)**: Bi?u ?? th?i gian s? l?n nh?p sai m?t kh?u theo ph?t.
- **Top M? Tr?ng Th?i HTTP (Nginx)**: Bi?u ?? c?t ph?n b? c?c m? tr?ng th?i HTTP (200, 301, 302, 429, 500,...).
- **CRM Webapp Logs**: Tr?c quan h?a chi ti?t log ?ng d?ng Flask v? audit trail ??ng nh?p.
- **PostgreSQL Errors & FATAL**: Gi?m s?t c?c l?i c? ph?p, k?t n?i ho?c panic c?a c? s? d? li?u.

### 6.3. T?p l?nh Truy v?n LogQL Ti?u chu?n (Q1 - Q5)
- **Q1 (L?i HTTP 5xx Nginx):**
  ```logql
  {job="nginx"} |~ "\" 5[0-9]{2} "
  ```
- **Q2 (L?i/Ngo?i l? ?ng d?ng):**
  ```logql
  {job="webapp"} |~ "(?i)(error|exception|fail)"
  ```
- **Q3 (??ng nh?p th?t b?i):**
  ```logql
  {job="webapp"} |= "LOGIN_FAILED"
  ```
- **Q4 (Th?ng k? s? l?n login fail theo ph?t):**
  ```logql
  sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
  ```
- **Q5 (L?i c? s? d? li?u PostgreSQL):**
  ```logql
  {job="postgres"} |~ "(?i)(error|fatal|panic)"
  ```
K?t qu? th?c thi m?u ???c l?u t?i `evidence/buoc5-logql.txt`.

### 6.4. K?ch b?n S? c? An to?n Th?ng tin: Brute-Force X?c th?c
1. **M? ph?ng t?n c?ng:**
   ```bash
   chmod +x scripts/simulate_bruteforce.sh
   ./scripts/simulate_bruteforce.sh
   ```
2. **C? ch? C?nh b?o (Alert):**
   - Lu?t c?nh b?o `CRM_BruteForce_Detected` t? ??ng ph?t hi?n khi `LOGIN_FAILED` v??t ng??ng 5 l?n/ph?t.
   - Tr?ng th?i chuy?n sang `firing` v? t? ??ng b?n webhook t?i `http://alert-sink:5000/alert`.
3. **Bi?n ph?p Ph?ng th? & Gi?m thi?u (Mitigation):**
   - Nginx Rate Limiting ?p d?ng t?i endpoint `/login`: Gi?i h?n 5 requests/ph?t (burst=5 nodelay).
   - T? request v??t ng??ng tr? ?i, Nginx ch? ??ng t? ch?i v?i m? **HTTP 429 Too Many Requests**, b?o v? tuy?t ??i backend web v? DB.
4. **T?i li?u chi ti?t s? c?:** Xem t?i `docs/su-co-bruteforce.md`. Minh ch?ng ghi nh?n t?i `evidence/buoc5-sucodo.txt`.

---

## 7. C?c Bi?n ph?p C?ng c? An ninh To?n di?n (System Hardening)

H? th?ng ???c ?p d?ng b? gi?i ph?p b?o m?t nhi?u l?p (Defense-in-Depth) theo c?c ti?u chu?n th?c h?nh t?t nh?t c?a CIS Docker Benchmark:

### 7.1. Ch?y Container v?i Ng??i d?ng Kh?ng ??c quy?n (Non-Root Containers)
- **Web App (`crm-web`)**: Kh?i t?o ng??i d?ng ri?ng `appuser` (UID `10001`, GID `10001`), gunicorn l?ng nghe c?ng kh?ng ??c quy?n 8000.
- **Nginx Reverse Proxy (`crm-nginx`)**: S? d?ng base image `nginxinc/nginx-unprivileged:1.27-alpine` ch?y d??i user `nginx` (UID `101`, GID `101`), l?ng nghe n?i b? c?ng `8080` (HTTP) v? `8443` (HTTPS) map ra `80`/`443` tr?n host.
- **pgAdmin (`crm-pgadmin`)**: Ch?y d??i user `pgadmin` (UID `5050`).
- **Prometheus & Exporters**: Ch?y d??i user `nobody` (UID `65534`).
- **Grafana**: Ch?y d??i user `grafana` (UID `472`).
- **Loki & Alert-Sink**: Ch?y d??i user UID `10001`.
- **Ngo?i l? k? thu?t:**
  - `cadvisor` & `promtail`: B?t bu?c c?n quy?n ??c socket `/var/run/docker.sock` v? `/var/lib/docker/containers/` ?? thu th?p metrics v? nh?t k? container; ???c b?o v? b?ng c? mount ch? ??c (`:ro`) v? lo?i b? to?n b? capabilities.
  - `db (postgres)`: Script kh?i t?o c?n quy?n volume ban ??u, sau ?? to?n b? ti?n tr?nh daemon ch?y ??c quy?n d??i user `postgres` (UID `999`).

### 7.2. Ph?n t?ch M?ng N?i b? (Network Isolation)
H? th?ng ph?n t?ch th?nh 3 m?ng Docker bridge ??c l?p:
1. `crm_frontend`: M?ng c?ng khai n?i Nginx v?i Web, pgAdmin, Grafana v? Nginx Exporter.
2. `crm_backend` (`internal: true`): M?ng n?i b? c? l?p tuy?t ??i, ch? cho ph?p k?t n?i gi?a Web, pgAdmin, Postgres Exporter v? Database `db`. Database **tuy?t ??i kh?ng tham gia m?ng frontend** v? **kh?ng publish b?t k? c?ng n?o** ra m?y ch? host.
3. `crm_monitoring` (`internal: true`): M?ng n?i b? c? l?p cho h? t?ng Prometheus, Grafana, Exporters, Loki, Promtail v? Alert-Sink.

### 7.3. Nguy?n t?c ??c quy?n T?i thi?u C? s? D? li?u (Database Least Privilege)
- Role `crm_app` d?nh cho ?ng d?ng web:
  - Ch? ???c c?p quy?n `SELECT, INSERT, UPDATE, DELETE` tr?n c?c b?ng schema `public`.
  - Quy?n `USAGE, SELECT` tr?n c?c sequence.
  - Thu h?i to?n b? quy?n DDL (`REVOKE CREATE ON SCHEMA public FROM PUBLIC; REVOKE ALL ON SCHEMA public FROM crm_app;`).
  - Th? nghi?m c?c c?u l?nh `DROP TABLE` ho?c `CREATE TABLE` ??u b? PostgreSQL t? ch?i v?i l?i `permission denied` / `must be owner of table`.
- Role `exporter` ch? ???c c?p quy?n `pg_monitor` ?? ??c metrics, kh?ng truy c?p d? li?u b?ng nghi?p v?.
- Superuser `crm_admin` tuy?t ??i kh?ng c?u h?nh cho ?ng d?ng web.
- M? h?a m?t kh?u ??t chu?n `scram-sha-256`.

### 7.4. H?n ch? Quy?n H?n & T?i nguy?n Container
- ?p d?ng `security_opt: [no-new-privileges:true]` tr?n to?n b? 12 containers ?? ng?n ch?n k? thu?t leo thang ??c quy?n (privilege escalation).
- Lo?i b? to?n b? Linux capabilities (`cap_drop: [ALL]`) ??i v?i c?c containers ?ng d?ng, proxy, gi?m s?t.
- ?p d?ng h? th?ng t?p tin ch? ??c (`read_only: true`) k?t h?p `tmpfs` t?m th?i (ch? cho ph?p ghi t?i `/tmp` v?i c?c c? an to?n `noexec,nosuid`).
- Gi?i h?n t?i nguy?n ph?n c?ng (`mem_limit`, `cpus`) ?? ph?ng ch?ng t?n c?ng t? ch?i d?ch v? (DoS / resource exhaustion do noisy neighbor).

### 7.5. Nginx Security Headers, Rate Limiting & ?n Th?ng tin
- K?ch ho?t ??y ?? c?c HTTP Security Headers (`always`): `Strict-Transport-Security`, `X-Frame-Options SAMEORIGIN`, `X-Content-Type-Options nosniff`, `X-XSS-Protection "1; mode=block"`, `Content-Security-Policy`, `Referrer-Policy`, `Permissions-Policy`.
- ?n th?ng tin phi?n b?n m?y ch?: `server_tokens off;`, `proxy_hide_header Server;`, `proxy_hide_header X-Powered-By;`.
- Gi?i h?n t?n su?t ??ng nh?p (Rate Limiting) tr?n `/login`: 5 requests/ph?t (burst=5 nodelay), tr? v? m? `HTTP 429 Too Many Requests` khi b? t?n c?ng Brute-force.

### 7.6. T??ng l?a M?y ch? (UFW Firewall)
- Thi?t l?p t??ng l?a theo th? t? ti?u chu?n:
  ```bash
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw --force enable
  ```
- **L?u ? k? thu?t v? Docker v? UFW:** M?c ??nh Docker can thi?p tr?c ti?p v?o chu?i iptables `DOCKER` c? th? ?i v?ng qua c?c quy t?c c?a UFW ??i v?i c?c c?ng ???c publish. Trong ki?n tr?c n?y, nguy c? ???c tri?t ti?u ho?n to?n nh? vi?c **ch? publish duy nh?t c?ng 80 v? 443 c?a Nginx**, to?n b? 11 d?ch v? c?n l?i (k? c? Database v? Prometheus/Grafana) n?m ho?n to?n trong c?c m?ng Docker n?i b? (`internal: true`) kh?ng c? b?t k? c?ng host n?o m? ra ngo?i.

### 7.7. Qu?n l? B? m?t & M?t kh?u An to?n
- M?i m?t kh?u v? kh?a b? m?t ???c l?u t?p trung trong `.env`, ph?n quy?n t?p `chmod 600 .env`.
- T?p m?u `.env.example` ch? ch?a gi? tr? gi? l?p placeholder.
- To?n b? l?ch s? git commit ???c r? so?t v? ki?m ch?ng s?ch s? (`git grep`), kh?ng r? r? b?t k? m?t kh?u ho?c kh?a b? m?t n?o.

### 7.8. Ki?m ch?ng Th?c t?
Ch?y t?p l?nh ki?m tra to?n di?n:
```bash
chmod +x scripts/generate_buoc6_evidence.sh
./scripts/generate_buoc6_evidence.sh
```
K?t qu? ghi nh?n ??y ?? t?i `evidence/buoc6-hardening.txt`.
