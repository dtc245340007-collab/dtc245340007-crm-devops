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
