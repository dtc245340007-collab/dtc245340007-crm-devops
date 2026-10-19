# BÁO CÁO ĐỒ ÁN MÔN HỌC: TRIỂN KHAI VÀ QUẢN TRỊ HỆ THỐNG PHẦN MỀM

---

* **Đề tài 4:** Hệ thống CRM Chăm sóc Khách hàng  
* **Học viên thực hiện:** NGUYỄN THỊ QUỲNH THƠ  
* **Mã số sinh viên (MSSV):** `dtc245340007`  
* **Repository GitHub:** `git@github.com:dtc245340007-collab/dtc245340007-crm-devops.git`  
* **Môi trường thực nghiệm:** Ubuntu Linux Server (IP: `192.168.207.128`)  
* **Công nghệ cốt lõi:** Docker Engine, Docker Compose v2, Nginx, Python/Flask, PostgreSQL 16, pgAdmin 4, Prometheus, Grafana, Loki, Promtail, cAdvisor, Exporters, UFW.

---

## CHƯƠNG 1: GIỚI THIỆU ĐỀ TÀI VÀ MỤC TIÊU ĐỒ ÁN

### 1.1. Bối cảnh và Bài toán Nghiệp vụ CRM
Trong hoạt động kinh doanh hiện đại, quản lý quan hệ khách hàng (Customer Relationship Management - CRM) là thành phần then chốt quyết định năng lực cạnh tranh và hiệu quả hoạt động của doanh nghiệp. Đề tài **"Hệ thống CRM Chăm sóc Khách hàng"** xây dựng một nền tảng phần mềm nội bộ chuyên sâu phục vụ các nghiệp vụ:
1. **Quản lý Hồ sơ Khách hàng & Người liên hệ:** Quản lý thông tin doanh nghiệp đối tác, mã khách hàng, đầu mối liên hệ (contacts) với phân định liên hệ chính (primary contact), trạng thái khách hàng (`lead`, `active`, `inactive`).
2. **Nhật ký Tương tác (Interaction Timeline):** Ghi nhận chi tiết từng lần trao đổi giữa nhân viên công ty với khách hàng (cuộc gọi, thư điện tử, cuộc họp trực tiếp, ghi chú nghiệp vụ) kèm lịch hẹn chăm sóc kế tiếp (next follow-up).
3. **Phân quyền người dùng dựa trên vai trò (Role-Based Access Control - RBAC):**
   - **Quản lý (Manager):** Quản trị danh mục khách hàng công ty, phân công nhân viên phụ trách, quản lý tài khoản nhân sự (tạo mới, cấp lại mật khẩu, kích hoạt/khóa tài khoản) và truy cập báo cáo tổng hợp.
   - **Nhân viên CSKH (Staff):** Đăng nhập an toàn, theo dõi danh mục khách hàng được phân công, ghi nhận tương tác và cập nhật hồ sơ khách hàng của mình.

### 1.2. Mục tiêu Kỹ thuật DevOps
Đồ án không dừng lại ở mức độ phát triển ứng dụng đơn thuần mà tập trung vào việc **xây dựng hạ tầng triển khai chuẩn công nghiệp, tự động hóa toàn diện và củng cố an toàn thông tin (DevSecOps)**:
- **Đóng gói chuẩn hóa (Containerization):** Đóng gói toàn bộ các dịch vụ theo kiến trúc vi dịch vụ sử dụng Docker và Docker Compose v2.
- **Bảo mật và Phân vùng mạng (Network & Container Hardening):** Phân chia 3 mạng nội bộ, chạy container bằng non-root, áp dụng read-only rootfs, thu hồi Linux capabilities, cấu hình Nginx reverse proxy với HTTPS tự ký và Security Headers.
- **Giám sát số liệu định lượng (Metrics Monitoring):** Xây dựng hệ thống Prometheus thu thập chuỗi thời gian từ cAdvisor, Nginx Exporter, PostgreSQL Exporter; trực quan hóa trên Grafana với 4 Dashboard tự động nạp (provisioning).
- **Quản trị nhật ký tập trung (Centralized Logging):** Triển khai Promtail và Grafana Loki, thiết lập các câu truy vấn LogQL phục vụ điều tra và phân tích vận hành.
- **Phát hiện và Xử lý Sự cố An toàn Thông tin:** Mô phỏng tấn công dò quét mật khẩu (Brute-Force Attack), tự động kích hoạt luật cảnh báo (Alert Rule) chuyển trạng thái Firing gửi Webhook tới Alert-Sink, đồng thời kích hoạt Nginx Rate Limiting chặn đứng bằng mã lỗi HTTP 429.

---

## CHƯƠNG 2: THIẾT KẾ KIẾN TRÚC HỆ THỐNG VÀ HẠ TẦNG

### 2.1. Mô hình Phân lớp Hệ thống
Hệ thống được thiết kế theo mô hình 5 phân lớp kiến trúc (Multi-tier Architecture):
1. **Lớp Biên & Điều phối (Edge & Proxy Tier):** Nginx Reverse Proxy (1.27 unprivileged) đóng vai trò cổng tiếp nhận duy nhất cho toàn bộ lưu lượng bên ngoài, thực hiện chuyển hướng HTTP sang HTTPS, kết thúc mã hóa TLS, áp dụng các header bảo mật HTTP và giới hạn tần suất yêu cầu (Rate Limiting).
2. **Lớp Ứng dụng & Nghiệp vụ (Application Tier):** Web App Flask chạy trên máy chủ WSGI Gunicorn (2 worker processes), phục vụ giao diện người dùng và xử lý logic nghiệp vụ CRM.
3. **Lớp Cơ sở Dữ liệu & Quản trị (Data Tier):** CSDL PostgreSQL 16.4 lưu trữ dữ liệu bền vững trên volume độc lập; ứng dụng web kết nối qua tài khoản tối thiểu quyền `crm_app`. Giao diện pgAdmin 4 hỗ trợ quản trị viên thao tác dữ liệu qua web.
4. **Lớp Giám sát Hiệu năng (Monitoring Tier):** Prometheus định kỳ 15s scrape số liệu từ 4 targets (cAdvisor, Nginx Exporter, Postgres Exporter, Prometheus self-metrics); Grafana trực quan hóa số liệu trên các bảng điều khiển thời gian thực.
5. **Lớp Nhật ký & Cảnh báo Sự cố (Logging & Incident Alerting Tier):** Promtail đọc Docker container log JSON, đẩy về Loki; Grafana Alerting kiểm tra LogQL và gửi Webhook cảnh báo tới dịch vụ `alert-sink`.

### 2.2. Bảng Danh mục 12 Dịch vụ Container

| STT | Tên Service | Image Sử dụng | Cổng Nội bộ | Cổng Host | Mạng Docker | Vai trò Kỹ thuật |
| :---: | :--- | :--- | :---: | :---: | :--- | :--- |
| 1 | `nginx` | `nginxinc/nginx-unprivileged:1.27-alpine` | `8080`, `8443` | `80`, `443` | `frontend` | Reverse Proxy, SSL Termination, Rate Limiting |
| 2 | `web` | `crm-web:latest` (Python 3.12-slim) | `8000` | *Không* | `frontend`, `backend` | Ứng dụng CRM Flask + Gunicorn, User 10001 |
| 3 | `db` | `postgres:16.4` | `5432` | *Không* | `backend` | PostgreSQL Database, User 999 |
| 4 | `pgadmin` | `dpage/pgadmin4:8.11` | `8080` | *Không* | `frontend`, `backend` | Giao diện quản trị CSDL, User 5050 |
| 5 | `prometheus` | `prom/prometheus:v2.54.1` | `9090` | *Không* | `monitoring` | Time-series TSDB, Scrape chu kỳ 15s, User 65534 |
| 6 | `grafana` | `grafana/grafana:11.2.0` | `3000` | *Không* | `frontend`, `monitoring` | Dashboards, LogQL Explore, Alerting, User 472 |
| 7 | `cadvisor` | `gcr.io/cadvisor/cadvisor:v0.49.1` | `8080` | *Không* | `monitoring` | Metrics tài nguyên phần cứng container |
| 8 | `nginx-exporter`| `nginx/nginx-prometheus-exporter:1.3.0` | `9113` | *Không* | `frontend`, `monitoring` | Metrics Nginx active connections & requests |
| 9 | `postgres-exporter`| `prometheuscommunity/postgres-exporter:v0.15.0`| `9187` | *Không* | `backend`, `monitoring` | Metrics PostgreSQL transactions & cache hit |
| 10 | `loki` | `grafana/loki:2.9.2` | `3100` | *Không* | `monitoring` | Lưu trữ nhật ký tập trung, User 10001 |
| 11 | `promtail` | `grafana/promtail:3.0.0` | *Không* | *Không* | `monitoring` | Thu gom Docker logs, User root (đọc host log 710) |
| 12 | `alert-sink` | `crm-alert-sink:latest` (Python 3.12-slim) | `5000` | *Không* | `monitoring` | Webhook receiver cảnh báo sự cố, User 10001 |

### 2.3. Thiết kế Phân vùng Mạng Docker
Hệ thống phân tách thành 3 mạng bridge độc lập trong `docker-compose.yml`:
1. `crm_frontend` (Bridge): Kết nối giữa Nginx Reverse Proxy với các giao diện web (`web`, `pgadmin`, `grafana`). Chỉ duy nhất Nginx mở cổng ra host (80 và 443).
2. `crm_backend` (Bridge, `internal: true`): Mạng nội bộ tuyệt đối, kết nối `web`, `pgadmin`, `postgres-exporter` với cơ sở dữ liệu `db`. Cơ sở dữ liệu hoàn toàn không có kết nối ra Internet hay mạng ngoài.
3. `crm_monitoring` (Bridge, `internal: true`): Mạng nội bộ dành riêng cho hạ tầng quan sát, kết nối các exporter, cAdvisor, Promtail, Prometheus, Loki, Grafana và Alert-Sink.

---

## CHƯƠNG 3: TRIỂN KHAI DỊCH VỤ VÀ AN TOÀN KẾT NỐI

### 3.1. Đóng gói Ứng dụng Web Flask (`web/Dockerfile`)
- Base Image: `python:3.12-slim` nhằm tối thiểu hóa dung lượng và diện tích tấn công (attack surface).
- Người dùng không đặc quyền: Tạo group `appgroup` (GID 10001) và user `appuser` (UID 10001). Toàn bộ mã nguồn thuộc quyền sở hữu của `appuser`.
- Web Server: Sử dụng Gunicorn WSGI HTTP Server với cấu hình 2 worker processes đồng bộ, lắng nghe tại cổng nội bộ `0.0.0.0:8000`.
- Cơ chế kiểm soát phiên (Session Security):
  * `SESSION_COOKIE_HTTPONLY = True`: Ngăn chặn mã độc JavaScript phía client trích xuất cookie qua các cuộc tấn công XSS.
  * `SESSION_COOKIE_SAMESITE = "Lax"`: Phòng chống tấn công giả mạo yêu cầu chéo trang (CSRF).
  * `SESSION_COOKIE_SECURE = True`: Đảm bảo trình duyệt chỉ truyền cookie qua kênh mã hóa HTTPS.
  * `ProxyFix`: Cấu hình WSGI middleware để tin cậy các headers được Nginx ủy quyền (`X-Forwarded-For`, `X-Forwarded-Proto`, `X-Forwarded-Host`).

### 3.2. Cấu hình Nginx Reverse Proxy, HTTPS & HTTP Security Headers
File cấu hình `nginx/nginx.conf` thiết lập các tiêu chuẩn an toàn:
1. **Chuyển hướng toàn diện (HTTP 301):** Khối server cổng 8080 (map cổng 80 host) tự động trả về mã chuyển hướng vĩnh viễn `return 301 https://$host$request_uri;`.
2. **Cấu hình SSL/TLS Tiêu chuẩn:**
   - Chứng chỉ tự ký RSA 2048-bit tạo bởi script `nginx/gen-cert.sh` với SAN mở rộng `IP:192.168.207.128, DNS:localhost`.
   - Giới hạn giao thức an toàn: `ssl_protocols TLSv1.2 TLSv1.3;`.
   - Cấu hình cipher suite mã hóa mạnh, bật `ssl_session_cache shared:SSL:10m;` và `ssl_session_timeout 1d;`.
3. **Bộ HTTP Security Headers Bắt buộc:**
   - `Strict-Transport-Security: max-age=31536000; includeSubDomains` (HSTS).
   - `X-Frame-Options: SAMEORIGIN` (Chống Clickjacking).
   - `X-Content-Type-Options: nosniff` (Chống MIME-type sniffing).
   - `X-XSS-Protection: 1; mode=block` (Chống reflected XSS trên trình duyệt cũ).
   - `Referrer-Policy: strict-origin-when-cross-origin`.
   - `Content-Security-Policy`: Định nghĩa nguồn tải tài nguyên hợp lệ cho ứng dụng.
4. **Định tuyến Subpath:**
   - `/`: Proxy pass tới `http://web:8000`.
   - `/pgadmin/`: Proxy pass tới `http://pgadmin:8080/` kèm `proxy_set_header X-Script-Name /pgadmin`.
   - `/grafana/`: Proxy pass tới `http://grafana:3000/` kèm hỗ trợ WebSocket upgrade (`$http_upgrade`, `$connection_upgrade`).
   - `/nginx_status`: Endpoint nội bộ cho `nginx-exporter`, chỉ cho phép `127.0.0.1` và dải IP Docker `172.16.0.0/12`.

---

## CHƯƠNG 4: CỦNG CỐ BẢO MẬT HỆ THỐNG (HARDENING)

### 4.1. Thực thi Nguyên tắc Đặc quyền Tối thiểu (Principle of Least Privilege)
1. **Phân quyền người dùng Container (Non-root Execution):**
   - 11/12 dịch vụ hoạt động hoàn toàn bằng tài khoản non-root: `web` (10001), `nginx` (101), `db` (999), `pgadmin` (5050), `grafana` (472), `prometheus` (65534), `cadvisor` (read-only), `nginx-exporter` (65534), `postgres-exporter` (65534), `loki` (10001), `alert-sink` (10001).
2. **Giải trình Kỹ thuật Chuyên sâu về Promtail (`user: root`):**
   - *Nguyên nhân:* Thư mục log của Docker Engine trên host Linux (`/var/lib/docker/containers`) có phân quyền mặc định `0710 (drwx--x--- root:root)` và các file `*-json.log` có quyền `0640 (-rw-r----- root:root)`. Quyền cho nhóm khác (`others`) là `000 (---)`. Mọi người dùng non-root (dù thuộc group docker hay root group) khi gọi lệnh đọc đều bị nhân Linux từ chối với lỗi `EACCES: Permission denied`.
   - *Biện pháp cô lập:* Mount bind ở chế độ `:ro`, thu hồi toàn bộ capabilities (`cap_drop: [ALL]`), kích hoạt `no-new-privileges:true`, cô lập hoàn toàn trong mạng `monitoring` không mở cổng.
3. **Phân tích Rủi ro An ninh đối với Docker Socket (`/var/run/docker.sock`):**
   - *Lưu ý kỹ thuật:* Trên hệ điều hành Linux, việc gắn cờ `:ro` khi bind mount một Unix Domain Socket **không** làm cho Docker daemon API trở thành chỉ đọc. Socket là kênh giao tiếp song công (full-duplex IPC stream); bất kỳ tiến trình nào mở được socket đều có khả năng gửi HTTP request (bao gồm cả POST/DELETE) tới daemon.
   - *Biện pháp giảm thiểu:* Tước bỏ capabilities, bật `no-new-privileges`, không công khai port mạng của Promtail. Khuyến nghị production: sử dụng `docker-socket-proxy` có bộ lọc chặn request POST/DELETE.
4. **PostgreSQL Database Role Separation:**
   - Role `crm_admin`: Superuser quản trị hệ thống cơ sở dữ liệu.
   - Role `crm_app`: Role nghiệp vụ dành riêng cho ứng dụng Web. Chỉ được cấp quyền DML (`SELECT, INSERT, UPDATE, DELETE`) trên các bảng nghiệp vụ. Quyền DDL bị thu hồi hoàn toàn trên schema `public` (lệnh `CREATE TABLE`, `DROP TABLE` bị PostgreSQL từ chối dứt điểm).
   - Role `exporter`: Role dành riêng cho Postgres Exporter, chỉ được gán role `pg_monitor` để đọc metrics hiệu năng, không thể truy cập dữ liệu khách hàng.
5. **Hệ thống tệp gốc Chỉ đọc (Read-only Rootfs) & tmpfs:**
   - Áp dụng `read_only: true` cho các dịch vụ phi trạng thái: `web`, `nginx`, `nginx-exporter`, `postgres-exporter`, `alert-sink`.
   - Cung cấp vùng nhớ tạm thời an toàn thông qua `tmpfs`: `/tmp:rw,noexec,nosuid,size=64m` (ngăn chặn thực thi mã độc từ thư mục tạm).
6. **Kiểm soát Khóa Bí mật `SECRET_KEY`:**
   - Ứng dụng Flask kiểm tra nghiêm ngặt `SECRET_KEY` khi chạy ở môi trường production (`FLASK_ENV=production`): Yêu cầu độ dài tối thiểu 32 ký tự, cấm sử dụng giá trị rỗng hoặc placeholder (`your_secure_secret_key_here`, `change-me`, `secret`). Nếu không đạt chuẩn, ứng dụng chủ động ném ngoại lệ `RuntimeError` và dừng khởi động.
   - Không tự động sinh khóa ngẫu nhiên khi khởi động lại để tránh làm vô hiệu hóa phiên đăng nhập của người dùng giữa các workers hoặc khi container khởi động lại.

---

## CHƯƠNG 5: HỆ THỐNG GIÁM SÁT HIỆU NĂNG (PROMETHEUS & GRAFANA)

### 5.1. Kiến trúc Thu thập Chuỗi Thời gian (Prometheus)
- Chu kỳ thu thập (Scrape Interval): 15 giây.
- Thời gian lưu trữ (Data Retention): 7 ngày trên Docker named volume `prometheus_data`.
- **Xác minh 4/4 Scrape Targets hoạt động (Trạng thái UP):**
  1. `prometheus`: Tự giám sát tiến trình Prometheus (cổng nội bộ 9090).
  2. `cadvisor`: Thu thập số liệu tài nguyên phần cứng (CPU sử dụng theo core, RAM bytes, Network I/O, Disk I/O) của toàn bộ 12 containers qua Docker cgroups.
  3. `nginx`: Thu thập qua `nginx-exporter:9113` kết nối với `nginx:8080/nginx_status` (active connections, requests per second, accepted/handled connections).
  4. `postgres`: Thu thập qua `postgres-exporter:9187` kết nối `db:5432` bằng role `exporter` (số transactions commit/rollback, cache hit ratio, số lượng kết nối đang mở, kích thước database).

### 5.2. Các Dashboard Chuyên dụng trên Grafana
Hệ thống tự động nạp (provisioning) 4 bảng điều khiển trong thư mục **CRM**:
1. **CRM - Containers (UID: `crm-containers`):** Biểu đồ tổng quan số lượng containers, tỷ lệ % CPU tiêu thụ theo từng container, dung lượng RAM sử dụng thực tế, tốc độ truyền nhận mạng (Network Inbound/Outbound Throughput).
2. **CRM - Nginx (UID: `crm-nginx`):** Biểu đồ số kết nối đồng thời (Active Connections), tốc độ xử lý request/giây, phân bổ mã trạng thái HTTP phản hồi (2xx, 3xx, 4xx, 5xx).
3. **CRM - PostgreSQL (UID: `crm-postgresql`):** Biểu đồ tốc độ giao dịch (Transactions/s), tỷ lệ sử dụng bộ nhớ đệm (Buffer Cache Hit Ratio > 99%), số lượng kết nối active/idle, tổng dung lượng database.
4. **CRM - Logs (UID: `crm-logs`):** Tích hợp nhật ký trực tiếp từ Loki, biểu đồ tần suất `LOGIN_FAILED/phút`, biểu đồ phân tích mã phản hồi Nginx và nhật ký lỗi database.

---

## CHƯƠNG 6: QUẢN TRỊ NHẬT KÝ TẬP TRUNG & KỊCH BẢN SỰ CỐ AN TOÀN

### 6.1. Thu thập & Chỉ mục Nhật ký với Promtail & Loki
- Loki hoạt động ở chế độ Single-binary tối ưu tài nguyên, lưu trữ chỉ mục (index) và khối dữ liệu (chunks) trên volume `loki_data`.
- Promtail giám sát các file JSON log của container, sử dụng `docker_sd_configs` lọc theo nhãn `com.docker.compose.project=crm`, tự động gán các nhãn cấu trúc:
  * `job="webapp"`: Nhật ký từ ứng dụng CRM Flask.
  * `job="nginx"`: Nhật ký truy cập và lỗi từ Nginx.
  * `job="postgres"`: Nhật ký hoạt động và lỗi từ PostgreSQL.

### 6.2. 5 Truy vấn LogQL Tiêu chuẩn
1. **Q1 - Lỗi HTTP 5xx phía Nginx:**
   ```logql
   {job="nginx"} |~ "\" 5[0-9]{2} "
   ```
2. **Q2 - Lỗi và ngoại lệ phía Ứng dụng Web:**
   ```logql
   {job="webapp"} |~ "(?i)(error|exception|fail)"
   ```
3. **Q3 - Sự kiện đăng nhập thất bại:**
   ```logql
   {job="webapp"} |= "LOGIN_FAILED"
   ```
4. **Q4 - Thống kê số lần đăng nhập sai theo phút:**
   ```logql
   sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
   ```
5. **Q5 - Nhật ký lỗi Cơ sở dữ liệu PostgreSQL:**
   ```logql
   {job="postgres"} |~ "(?i)(error|fatal|panic)"
   ```

### 6.3. Kịch bản Mô phỏng Sự cố Tấn công Brute-force & Cảnh báo Tự động
1. **Mô phỏng tấn công:** Thực thi script `scripts/simulate_bruteforce.sh` gửi dồn dập 20 yêu cầu sai mật khẩu vào tài khoản `admin` trong vòng 11 giây.
2. **Cơ chế Phát hiện & Cảnh báo:**
   - Luật cảnh báo `CRM_BruteForce_Detected` trên Grafana Alerting liên tục đánh giá biểu thức:
     `sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m])) > 5`
   - Khi vượt ngưỡng 5 lần trong 1 phút, luật lập tức chuyển trạng thái sang **Firing** và gửi webhook payload tới dịch vụ `alert-sink` tại endpoint `/alert`.
3. **Cơ chế Phòng thủ & Chặn đứng (Rate Limiting Mitigation):**
   - Nginx cấu hình vùng giới hạn: `limit_req_zone $binary_remote_addr zone=crm_login:10m rate=5r/m; limit_req_status 429;` tại `location = /login` với `burst=10 nodelay`.
   - **Kết quả thực nghiệm:** 10 request đầu tiên được ứng dụng xử lý và trả về phản hồi sai mật khẩu; từ request thứ 11 trở đi, Nginx chủ động chặn đứng và phản hồi **HTTP 429 Too Many Requests**, ngăn chặn hoàn toàn việc cạn kiệt tài nguyên máy chủ.

---

## CHƯƠNG 7: KẾT QUẢ KIỂM THỬ THỰC TẾ

Toàn bộ các bài kiểm tra chức năng và an toàn đều được thực thi trực tiếp trên máy chủ thật và ghi nhận kết quả xác thực:

```
=================================================================
          SMOKE TEST HE THONG CRM (KIEM THU TU DONG)             
=================================================================

[1] Kiem tra dang nhap Web CRM...
 -> [PASSED] Dang nhap Web CRM thanh cong voi user: admin

[2] Kiem tra Tao khach hang moi (/customers/new)...
 -> [PASSED] Tao khach hang thanh cong: KH-VERIFY-479 (Customer ID: 1)

[3] Ghi nhan lich su tuong tac (/customers/1/interactions/new)...
 -> [PASSED] Ghi nhan tuong tac thanh cong!

[4] Kiem tra giao dien quan tri pgAdmin (/pgadmin/)...
 -> [PASSED] pgAdmin phan hoi HTTP Status 200 (OK) [lan thu 1]

[5] Kiem tra Grafana API qua Nginx Proxy (/grafana/api/datasources)...
 -> [PASSED] Grafana xac thuc thanh cong. Datasources hoat dong: Loki, Prometheus [lan thu 1]
 -> [PASSED] Dashboards san sang: CRM - Containers, CRM - Logs, CRM - Nginx, CRM - PostgreSQL

=================================================================
   KET QUA: TOAN BO CHUC NANG HE THONG HOAT DONG HOAN HAO!     
=================================================================
```

### Bảng Tổng hợp Kết quả Kiểm tra 11 Tiêu chí

| STT | Hạng mục Kiểm thử | Lệnh Thực thi | Kết quả Thực tế | Đánh giá |
| :---: | :--- | :--- | :--- | :---: |
| 1 | CRM truy cập HTTPS | `curl -kI https://localhost/login` | HTTP/2 200, HSTS, CSP, X-Frame-Options | **PASS** |
| 2 | Session & Cookies | Kiểm tra Set-Cookie | `Secure; HttpOnly; SameSite=Lax` | **PASS** |
| 3 | PostgreSQL lưu & truy vấn | `psql -c "SELECT count(*) FROM customers;"` | Trả về 16 khách hàng và 3 users | **PASS** |
| 4 | pgAdmin kết nối DB | `curl -kI https://localhost/pgadmin/` | HTTP/2 302 -> `/pgadmin/browser/` | **PASS** |
| 5 | Prometheus Scrape Targets | `wget -qO- .../api/v1/targets` | Đủ 4 targets: `cadvisor, nginx, postgres, prometheus` UP | **PASS** |
| 6 | Grafana Dashboards | API `/grafana/api/search` | Đủ 4 dashboards trong thư mục `CRM` | **PASS** |
| 7 | Loki Log Ingestion | API `/loki/api/v1/query_range` | Nhận đủ streams: `webapp, nginx, postgres` | **PASS** |
| 8 | Promtail Log Collection | Kiểm tra log lines trong Loki | Thu thập đầy đủ log JSON các container | **PASS** |
| 9 | Cảnh báo Brute-force | `simulate_bruteforce.sh` | Grafana Alert firing, Webhook tới `alert-sink` | **PASS** |
| 10 | Rate Limiting HTTP 429 | `simulate_bruteforce.sh` | Requests 11-20 bị Nginx chặn với mã 429 | **PASS** |
| 11 | Healthcheck & Exporters | `curl -k https://localhost/health` | Trả về HTTP 200 `OK`, các exporter hoạt động | **PASS** |

---

## CHƯƠNG 8: KẾT LUẬN, HẠN CHẾ VÀ HƯỚNG PHÁT TRIỂN

### 8.1. Kết luận Đạt được
1. Đồ án đã hoàn thành 100% các yêu cầu của **Đề tài 4: Hệ thống CRM Chăm sóc Khách hàng**, từ nghiệp vụ ứng dụng, cơ sở dữ liệu mẫu đến toàn bộ chu trình triển khai DevOps.
2. Thiết lập kiến trúc container hóa chuẩn mực với 12 dịch vụ, 3 mạng phân tách, quy chuẩn non-root, read-only rootfs và thu hồi quyền hạn cấp nhân Linux.
3. Vận hành thành công hệ thống giám sát toàn diện (Prometheus, Grafana với 4 dashboards chuyên sâu) và hệ thống nhật ký tập trung (Loki, Promtail với 5 truy vấn LogQL chuẩn xác).
4. Xây dựng kịch bản an toàn thông tin hoàn chỉnh: Mô phỏng tấn công Brute-force, tự động phát hiện bằng LogQL Alert Rule, kích hoạt webhook thông báo và ngăn chặn tức thời bằng Rate Limiting HTTP 429.

### 8.2. Hạn chế Hiện tại & Rủi ro Lịch sử Git
1. **Lịch sử Git quá khứ chứa thông tin mẫu:** Trong các commit ban đầu (`d4e9c81`, `21087b3`, `c134447`), các bảng README và comment SQL có chứa mật khẩu mẫu. Tuân thủ nguyên tắc an toàn không viết lại lịch sử Git (không rewrite history), toàn bộ mật khẩu trên môi trường thật đã được thay thế độc lập qua file `.env`.
2. **Mount Docker Socket:** Promtail cần Docker socket để tự động khám phá container. Mặc dù đã gắn `:ro` và drop all capabilities, bản chất Unix domain socket vẫn tiềm ẩn rủi ro nếu container bị chiếm quyền điều khiển cấp cao.

### 8.3. Hướng Phát triển Nâng cao
- **Quản lý Bí mật Động (Secret Management):** Tích hợp HashiCorp Vault hoặc Docker Secrets để cấp phát và tự động xoay vòng mật khẩu CSDL, khóa phiên thay cho biến môi trường `.env`.
- **Cơ chế Xác thực Nâng cao:** Bổ sung xác thực 2 yếu tố (2FA / TOTP) cho tài khoản quản lý và tích hợp reCAPTCHA / Cloudflare Turnstile tại trang đăng nhập.
- **Mở rộng Kiến trúc Cụm (Orchestration):** Chuyển đổi kiến trúc từ Docker Compose sang cụm Kubernetes (K8s) với Helm Chart, Horizontal Pod Autoscaler (HPA) và Ingress Controller chuẩn doanh nghiệp.
