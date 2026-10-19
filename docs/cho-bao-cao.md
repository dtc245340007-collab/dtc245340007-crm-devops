# TỔNG HỢP NỘI DUNG VÀ TÀI LIỆU PHỤC VỤ VIẾT BÁO CÁO BÀI TẬP LỚN

**Học phần:** Triển khai và Quản trị Hệ thống Phần mềm  
**Học viên:** NGUYEN THI QUYNH THO  
**MSSV:** dtc245340007  
**Đề tài 4:** Hệ thống CRM Chăm sóc Khách hàng  
**Môi trường thực thi:** Ubuntu Linux (192.168.207.128) - Docker Engine & Compose v2  
**Repository GitHub:** `git@github.com:dtc245340007-collab/dtc245340007-crm-devops.git`

---

## MỤC 1. GIỚI THIỆU VÀ KIẾN TRÚC TỔNG THỂ

### 1.1. Giới thiệu Đề tài & Bài toán nghiệp vụ
- **Mô tả triển khai (Văn phong báo cáo):**  
  Hệ thống CRM Chăm sóc Khách hàng là ứng dụng web doanh nghiệp nội bộ phục vụ công tác quản lý quan hệ khách hàng, quản lý danh bạ liên hệ (contacts), ghi nhận và theo dõi lịch sử tương tác (cuộc gọi, email, họp trực tiếp, ghi chú) và nhắc lịch chăm sóc khách hàng định kỳ. Hệ thống phân quyền chặt chẽ theo hai vai trò:
  - *Quản lý (Manager):* Toàn quyền quản lý danh mục khách hàng, phân công người phụ trách, quản trị tài khoản nhân viên và theo dõi báo cáo phân tích toàn công ty.
  - *Nhân viên CSKH (Staff):* Chỉ được xem, chỉnh sửa và tạo tương tác trên các khách hàng được phân công phụ trách.
- **File cấu hình liên quan:** `web/src/models.py`, `web/src/auth.py`, `db/init.sql`
- **File evidence:** `evidence/buoc12-web-db.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 1.1:* Giao diện Đăng nhập hệ thống CRM (`https://192.168.207.128/login`).
  - *Hình 1.2:* Giao diện Dashboard Quản lý Khách hàng của vai trò Quản lý (`admin`).
  - *Hình 1.3:* Giao diện Chi tiết Khách hàng, thêm người liên hệ và ghi nhận lịch sử tương tác.

### 1.2. Sơ đồ Kiến trúc Hệ thống & Hạ tầng Triển khai
- **Mô tả triển khai (Văn phong báo cáo):**  
  Toàn bộ hệ thống được container hóa bằng Docker Compose v2 theo mô hình vi dịch vụ phân lớp (Multi-tier Architecture):
  1. *Lớp Proxy / Gateway:* Nginx Reverse Proxy (1.27-alpine unprivileged) đóng vai trò cổng vào duy nhất, chấm dứt TLS (HTTPS), áp dụng HTTP Security Headers và Rate Limiting.
  2. *Lớp Ứng dụng (Application Tier):* Python 3.12 (Flask + Gunicorn WSGI 2 workers) chạy dưới tài khoản không đặc quyền `appuser` (UID 10001).
  3. *Lớp Dữ liệu (Data Tier):* PostgreSQL 16.4 lưu trữ dữ liệu bền vững trên volume `db_data`, áp dụng phân quyền vai trò tối thiểu (`crm_app`) và mã hóa SCRAM-SHA-256; pgAdmin 4 quản trị cơ sở dữ liệu qua giao diện web.
  4. *Lớp Giám sát (Monitoring Tier):* Prometheus v2.54.1, cAdvisor v0.49.1, Nginx Exporter, Postgres Exporter và Grafana 11.2.0.
  5. *Lớp Quản trị Nhật ký (Logging Tier):* Grafana Loki 2.9.2, Promtail 3.0.0 và dịch vụ webhook Alert-Sink.
- **File cấu hình liên quan:** `docker-compose.yml`, `nginx/nginx.conf`
- **File evidence:** `evidence/buoc0-moitruong.txt`, `evidence/buoc6-hardening.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 1.4:* Sơ đồ khối kiến trúc hệ thống CRM (có thể dùng sơ đồ Mermaid trong README.md).
  - *Hình 1.5:* Kết quả lệnh `docker compose ps` hiển thị đầy đủ 12 containers đang hoạt động.

---

## MỤC 2. TRIỂN KHAI DỊCH VỤ WEB, DATABASE & REVERSE PROXY

### 2.1. Triển khai Web App, Database PostgreSQL & pgAdmin (Bước 1 & 2)
- **Mô tả triển khai (Văn phong báo cáo):**  
  Ứng dụng web CRM được đóng gói bằng `Dockerfile` tối ưu dựa trên image `python:3.12-slim`. Cơ sở dữ liệu PostgreSQL 16.4 khởi tạo thông qua script `db/01-init.sh` và `db/init.sql` tạo sẵn 4 bảng nghiệp vụ (`users`, `customers`, `contacts`, `interactions`) cùng các chỉ mục tối ưu hóa truy vấn (`email`, `phone`, `assigned_to`, `customer_id`, `interaction_time`). Hệ thống nạp sẵn dữ liệu demo phong phú gồm 3 người dùng, 15 khách hàng doanh nghiệp, 20 người liên hệ và 40 bản ghi tương tác. Ứng dụng kết nối DB bằng role riêng biệt `crm_app` (không dùng superuser). pgAdmin 4 được cấu hình tự động nhận diện cơ sở dữ liệu thông qua file `pgadmin/servers.json`.
- **File cấu hình liên quan:** `web/Dockerfile`, `db/01-init.sh`, `db/init.sql`, `pgadmin/servers.json`, `.env.example`
- **File evidence:** `evidence/buoc12-web-db.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 2.1:* Giao diện pgAdmin kết nối thành công tới Database `CRM DB` hiển thị danh sách 4 bảng.
  - *Hình 2.2:* Minh chứng thực thi script `db/01-init.sh` cấp quyền cho role `crm_app`.

### 2.2. Cấu hình Nginx Reverse Proxy, HTTPS & Security Headers (Bước 3 - COMMIT 1)
- **Mô tả triển khai (Văn phong báo cáo):**  
  Nginx đảm nhận việc điều phối lưu lượng và bảo vệ ứng dụng:
  - Cổng 80 tự động chuyển hướng 301 vĩnh viễn sang cổng 443 (HTTPS).
  - Chứng chỉ số SSL/TLS tự ký RSA 2048-bit có SAN mở rộng (`IP:192.168.207.128`, `DNS:localhost`) được sinh tự động bằng script `nginx/gen-cert.sh`.
  - Giới hạn giao thức an toàn TLSv1.2 và TLSv1.3, bộ mã hóa (cipher suite) bảo mật cao, bật `ssl_session_cache`.
  - Định tuyến subpath: Chuyển tiếp `/` tới `web:8000`, `/pgadmin/` tới `pgadmin:80` (kèm header `X-Script-Name /pgadmin`), và `/grafana/` tới `grafana:3000` (hỗ trợ WebSocket upgrade).
  - Áp dụng các HTTP Security Headers bắt buộc: `Strict-Transport-Security`, `X-Frame-Options SAMEORIGIN`, `X-Content-Type-Options nosniff`, `X-XSS-Protection "1; mode=block"`, `Referrer-Policy strict-origin-when-cross-origin`, `Content-Security-Policy` và `Permissions-Policy`.
- **File cấu hình liên quan:** `nginx/nginx.conf`, `nginx/gen-cert.sh`
- **File evidence:** `evidence/buoc3-nginx.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 2.3:* Chi tiết chứng chỉ SSL/TLS khi xem trên trình duyệt web (hiển thị SAN `192.168.207.128`).
  - *Hình 2.4:* Kết quả kiểm tra Header bằng lệnh `curl -kI https://192.168.207.128/` hiển thị đầy đủ Security Headers.

---

## MỤC 3. GIÁM SÁT, QUẢN TRỊ NHẬT KÝ & XỬ LÝ SỰ CỐ AN TOÀN

### 3.1. Hệ thống Giám sát Số liệu Prometheus & Grafana (Bước 4 - COMMIT 2)
- **Mô tả triển khai (Văn phong báo cáo):**  
  Hạ tầng giám sát định lượng chu kỳ 15s thu thập metrics từ toàn bộ các tầng thành phần:
  - Prometheus v2.54.1 lưu trữ chuỗi thời gian retention 7 ngày trên volume `prometheus_data`.
  - Scrape đồng thời 4 targets: `prometheus` (localhost:9090), `cadvisor` (cadvisor:8080 - CPU, RAM, Network I/O containers), `nginx` (nginx-exporter:9113 - active connections, requests), và `postgres` (postgres-exporter:9187 - transactions, connections, cache hit ratio qua role `exporter` có quyền `pg_monitor`).
  - Grafana 11.2.0 hoạt động qua đường dẫn con `/grafana/`, tự động provisioning Datasource Prometheus và 3 Dashboard chuyên sâu trong thư mục **CRM**:
    1. *CRM - Containers:* Giám sát tài nguyên CPU, bộ nhớ của toàn bộ container Docker.
    2. *CRM - Nginx:* Giám sát lưu lượng truy cập mạng, active connections, request rate.
    3. *CRM - PostgreSQL:* Giám sát sức khỏe CSDL, transactions commit/rollback, cache hit.
  - Đã thực hiện kiểm chứng sinh tải 200 requests HTTPS và ghi nhận biến thiên số liệu tương ứng.
- **File cấu hình liên quan:** `prometheus/prometheus.yml`, `grafana/provisioning/datasources/prometheus.yml`, `grafana/provisioning/dashboards/`
- **File evidence:** `evidence/buoc4-giamsat.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 3.1:* Màn hình Prometheus Targets (`http://.../targets`) xác nhận cả 4 targets đều `UP`.
  - *Hình 3.2:* Màn hình Dashboard Grafana "CRM - Containers" hiển thị biểu đồ CPU/RAM.
  - *Hình 3.3:* Màn hình Dashboard Grafana "CRM - PostgreSQL" hiển thị transaction rate và kết nối DB.

### 3.2. Hệ thống Nhật ký Tập trung Loki, Promtail & Truy vấn LogQL (Bước 5A, 5B)
- **Mô tả triển khai (Văn phong báo cáo):**  
  Giải pháp quản trị nhật ký tập trung Cloud-Native với Loki và Promtail:
  - Loki 2.9.2 lưu trữ logs filesystem đơn giản, chu kỳ lưu trữ 7 ngày trên volume `loki_data`.
  - Promtail 3.0.0 tự động phát hiện containers qua Docker socket, áp dụng bộ lọc `com.docker.compose.project=crm`, gắn nhãn tiêu chuẩn `job="nginx"`, `job="webapp"`, `job="postgres"`. Pipeline parse Nginx access log trích xuất trường `status` làm nhãn kiểm soát độ biến thiên thấp.
  - Dashboard Grafana "CRM - Logs" hiển thị đồng thời: Biểu đồ số lần `LOGIN_FAILED/phút`, biểu đồ top mã HTTP Nginx, log ứng dụng web Flask và log lỗi PostgreSQL.
  - Đã thực thi và ghi nhận kết quả 5 câu truy vấn LogQL tiêu chuẩn (Q1 đến Q5).
- **File cấu hình liên quan:** `loki/loki-config.yaml`, `promtail/promtail-config.yaml`, `grafana/provisioning/dashboards/logs.json`
- **File evidence:** `evidence/buoc5-logql.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 3.4:* Dashboard Grafana "CRM - Logs" hiển thị các panels nhật ký thời gian thực.
  - *Hình 3.5:* Giao diện Grafana Explore thực thi câu truy vấn LogQL `{job="webapp"} |= "LOGIN_FAILED"`.

### 3.3. Kịch bản Sự cố An toàn Thông tin: Brute-force Xác thực & Cảnh báo (Bước 5C - COMMIT 3)
- **Mô tả triển khai (Văn phong báo cáo):**  
  - *Kịch bản:* Mô phỏng tấn công dò quét mật khẩu (Brute-Force) vào tài khoản quản trị viên `admin` qua cổng `/login` bằng script `scripts/simulate_bruteforce.sh`, gửi dồn dập 20 yêu cầu sai mật khẩu.
  - *Cơ chế Cảnh báo:* Luật cảnh báo `CRM_BruteForce_Detected` trên Grafana Alerting phát hiện khi `sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m])) > 5`. Trạng thái chuyển tức thời sang `firing` và phát webhook notification tới container `alert-sink`.
  - *Truy vết sự cố (Incident Tracing):* Truy vết đầy đủ qua 3 góc nhìn từ Loki:
    1. Góc nhìn Nginx: Ghi nhận chuỗi yêu cầu `POST /login` từ IP nguồn `192.168.207.128`.
    2. Góc nhìn Web App: Ghi nhận các bản ghi `LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password`.
    3. Góc nhìn Alert: Ghi nhận webhook notification nhận được tại dịch vụ `alert-sink`.
  - *Biện pháp Giảm thiểu (Mitigation):* Cấu hình Rate Limiting trên Nginx (`limit_req_zone $binary_remote_addr zone=crm_login:10m rate=5r/m; limit_req_status 429;`) tại `location = /login`. Khi kẻ tấn công gửi yêu cầu vượt ngưỡng, Nginx lập tức từ chối và phản hồi **HTTP 429 Too Many Requests**, bảo vệ hoàn toàn ứng dụng backend.
- **File cấu hình & Script liên quan:** `scripts/simulate_bruteforce.sh`, `grafana/provisioning/alerting/`, `docs/su-co-bruteforce.md`, `alert-sink/app.py`
- **File evidence:** `evidence/buoc5-sucodo.txt`, `docs/su-co-bruteforce.md`
- **Danh sách ảnh cần chụp:**
  - *Hình 3.6:* Terminal thực thi script `scripts/simulate_bruteforce.sh` hiển thị phản hồi từ chối HTTP 429.
  - *Hình 3.7:* Giao diện Grafana Alerting hiển thị luật `CRM_BruteForce_Detected` ở trạng thái **Firing**.
  - *Hình 3.8:* Log của container `alert-sink` nhận payload webhook cảnh báo sự cố.

---

## MỤC 4. CỦNG CỐ BẢO MẬT HỆ THỐNG (HARDENING)

### 4.1. Bộ giải pháp Hardening Toàn diện (Bước 6)
- **Mô tả triển khai (Văn phong báo cáo):**  
  Áp dụng bộ giải pháp bảo mật theo chiều sâu (Defense-in-Depth):
  1. *Non-root Containers:* 10/12 container chạy hoàn toàn bằng user không đặc quyền (`appuser` UID 10001, `nginx` UID 101, `pgadmin` UID 5050, `nobody` UID 65534, `grafana` UID 472, `postgres` UID 999). Hai container `cadvisor` và `promtail` bắt buộc quyền đọc docker.sock được cô lập bằng mount `:ro` và drop all capabilities.
  2. *Network Isolation:* Phân tách 3 mạng Docker bridge độc lập; mạng `backend` và `monitoring` được đặt cờ `internal: true`. Database hoàn toàn không nối mạng `frontend` và không publish cổng ra ngoài.
  3. *Database Least Privilege:* Role `crm_app` chỉ có quyền thao tác dữ liệu bảng (`SELECT, INSERT, UPDATE, DELETE`) và sequence, bị thu hồi toàn bộ quyền DDL trên schema `public`. Thử nghiệm lệnh `DROP TABLE` và `CREATE TABLE` bị từ chối dứt điểm.
  4. *Container Security Opts & Read-only rootfs:* Bật `no-new-privileges:true`, `cap_drop: [ALL]`, `read_only: true` (kèm `tmpfs` cho `/tmp`), và giới hạn tài nguyên CPU/RAM trên tất cả containers.
  5. *Tường lửa máy chủ UFW:* Kích hoạt tường lửa, chính sách mặc định `deny incoming`, chỉ mở cổng 22 (SSH), 80 (HTTP) và 443 (HTTPS).
  6. *Ẩn thông tin phiên bản & Quản lý bí mật:* `server_tokens off;`, ẩn header `Server` và `X-Powered-By`, phân quyền `.env` ở chế độ `chmod 600`, kiểm toán lịch sử git không lộ mật khẩu.
- **File cấu hình liên quan:** `docker-compose.yml`, `nginx/nginx.conf`, `web/Dockerfile`, `alert-sink/Dockerfile`, `db/01-init.sh`
- **File evidence:** `evidence/buoc6-hardening.txt`
- **Danh sách ảnh cần chụp:**
  - *Hình 4.1:* Kiểm tra `id` trong các container chứng minh người dùng non-root.
  - *Hình 4.2:* Kiểm tra `docker network inspect crm_backend` chứng minh có `internal: true`.
  - *Hình 4.3:* Thử nghiệm lệnh `DROP TABLE` bị PostgreSQL từ chối với lỗi quyền.
  - *Hình 4.4:* Trạng thái tường lửa `sudo ufw status verbose`.

---

## MỤC 5. KẾT LUẬN & ĐÁNH GIÁ

### 5.1. Kết quả đạt được
- Triển khai thành công 100% hệ thống CRM Chăm sóc Khách hàng trên nền tảng Docker Compose với 12 dịch vụ hoạt động đồng bộ, ổn định và tự động hóa cao.
- Đáp ứng trọn vẹn toàn bộ các tiêu chí đề tài: Khởi tạo dữ liệu mẫu phong phú, phân quyền theo vai trò người dùng, thiết lập HTTPS tự ký bảo mật, giám sát metrics toàn diện với Prometheus/Grafana, thu thập nhật ký tập trung với Loki/Promtail, xây dựng kịch bản sự cố Brute-force có cảnh báo thời gian thực và áp dụng bộ giải pháp Hardening đa lớp.
- Kiểm thử "chạy bằng một lệnh" (`docker compose up -d --build`) từ trạng thái sạch hoàn toàn thành công, vượt qua 100% các bài smoke test.

### 5.2. Khuyến nghị & Hướng phát triển
- Tích hợp giải pháp quản lý khóa bí mật chuyên dụng (HashiCorp Vault hoặc Docker Secrets) thay cho biến môi trường `.env`.
- Mở rộng xác thực đa yếu tố (2FA / TOTP) cho tài khoản quản trị viên và tích hợp cơ chế CAPTCHA bảo vệ cổng đăng nhập.
- Nâng cấp triển khai trên cụm máy chủ phân tán Kubernetes (K8s) khi quy mô khách hàng doanh nghiệp mở rộng.
