# Báo Cáo Xử Lý Sự Cố An Toàn Thông Tin: Tấn Công Brute-Force Xác Thực CRM

**Môn học:** Triển khai và Quản trị Hệ thống Phần mềm  
**Học viên:** NGUYEN THI QUYNH THO  
**MSSV:** dtc245340007  
**Đề tài 4:** Hệ thống CRM Chăm sóc Khách hàng  
**Mã sự cố:** `INC-SEC-2026-001`  
**Mức độ nghiêm trọng:** `CRITICAL` (P1)  
**Trạng thái:** `RESOLVED / MITIGATED`  

---

## 1. Mô tả Kịch bản và Mục tiêu Tấn công

### 1.1. Bối cảnh sự cố
Hệ thống CRM Chăm sóc Khách hàng cung cấp cổng đăng nhập tập trung tại `https://192.168.207.128/login` cho Quản lý và Nhân viên CSKH. Cổng đăng nhập này là điểm truy cập trọng yếu bảo vệ dữ liệu khách hàng, lịch sử giao dịch và thông tin kinh doanh nhạy cảm.

### 1.2. Kịch bản & Kỹ thuật tấn công
- **Kỹ thuật:** Tấn công dò quét mật khẩu tự động (Brute-Force Attack / Password Guessing / Credential Stuffing).
- **Mục tiêu:** Tài khoản quản trị cấp cao `admin`.
- **Hành vi của kẻ tấn công:**
  1. Sử dụng script tự động hóa (`scripts/simulate_bruteforce.sh`) gửi yêu cầu GET tới `https://192.168.207.128/login` để trích xuất `csrf_token` và session cookie hợp lệ nhằm vượt qua lớp bảo vệ CSRF.
  2. Gửi dồn dập 20 yêu cầu HTTP POST liên tiếp thử các mật khẩu phổ biến (`123456`, `password`, `admin123`, `qwerty`,...) với tần suất cao (khoảng 0.5s/request).
- **Mục đích:** Chiếm quyền điều khiển tài khoản quản trị viên tối cao của hệ thống CRM nhằm đánh cắp hoặc phá hoại dữ liệu khách hàng.

---

## 2. Cơ chế Phát hiện Sự cố (Detection)

### 2.1. Dấu hiệu nhận biết
- **Tần suất yêu cầu bất thường:** Xuất hiện nhiều yêu cầu POST tới endpoint `/login` từ một địa chỉ IP duy nhất trong khoảng thời gian rất ngắn (< 15 giây).
- **Thông điệp nhật ký ứng dụng:** Web application liên tục ghi nhận sự kiện thất bại vào luồng `STDERR` với mẫu định dạng:
  ```
  LOGIN_FAILED ip=<IP> user=admin reason=wrong_password
  ```

### 2.2. Biểu thức giám sát & Cảnh báo (Grafana / LogQL Alert Rule)
Hệ thống thiết lập luật cảnh báo tự động trên Grafana Alerting:
- **Tên cảnh báo:** `CRM_BruteForce_Detected`
- **Mức độ:** `critical`
- **Biểu thức LogQL phát hiện:**
  ```logql
  sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
  ```
- **Điều kiện kích hoạt:** Giá trị tổng số lần đăng nhập thất bại vượt quá **5 lần trong vòng 1 phút** (`threshold: gt 5`).
- **Chu kỳ đánh giá (Evaluation Interval):** 10 giây.
- **Thời gian duy trì trước khi bắn cảnh báo (For):** 0 giây (bắn tức thời khi vượt ngưỡng).
- **Điểm tiếp nhận cảnh báo (Contact Point):** Webhook nội bộ gửi về `alert-sink:5000/alert`.

### 2.3. Bằng chứng kích hoạt cảnh báo
Khi script tấn công gửi đến request thứ 6, tổng số lần `LOGIN_FAILED` vượt ngưỡng 5. Grafana Alerting lập tức chuyển trạng thái sang `firing` và phát webhook notification:
```json
{
  "receiver": "alert-sink",
  "status": "firing",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "CRM_BruteForce_Detected",
        "grafana_folder": "CRM",
        "severity": "critical"
      },
      "annotations": {
        "summary": "CRM Brute-Force Authentication Attack Detected",
        "description": "More than 5 LOGIN_FAILED events detected in 1 minute from CRM Webapp."
      },
      "startsAt": "2026-10-19T10:18:30Z"
    }
  ]
}
```

---

## 3. Truy vết Nguyên nhân Gốc rễ qua Log tập trung Loki (Incident Tracing)

Nhờ hạ tầng thu thập nhật ký Promtail và lưu trữ tập trung Loki, kỹ sư DevOps có thể truy vết toàn diện sự cố theo 3 góc nhìn tương quan:

### 3.1. Góc nhìn Nginx Reverse Proxy (`{job="nginx"}`)
Truy vấn:
```logql
{job="nginx"} |= "POST /login"
```
**Kết quả ghi nhận:**
```
192.168.207.128 - - [19/Oct/2026:10:20:51 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.100 ...
192.168.207.128 - - [19/Oct/2026:10:20:51 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.095 ...
192.168.207.128 - - [19/Oct/2026:10:20:52 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.086 ...
192.168.207.128 - - [19/Oct/2026:10:20:53 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.090 ...
...
```
*Nhận xét:* Xác định chính xác địa chỉ IP nguồn tấn công là `192.168.207.128`, User-Agent sử dụng công cụ tự động `curl/8.18.0`.

### 3.2. Góc nhìn Web Application (`{job="webapp"}`)
Truy vấn:
```logql
{job="webapp"} |= "LOGIN_FAILED"
```
**Kết quả ghi nhận:**
```
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
...
```
*Nhận xét:* Xác nhận ứng dụng ghi nhận liên tiếp 20 lần thử mật khẩu sai đối với duy nhất tài khoản `admin`. Tất cả request đều từ IP `192.168.207.128`.

### 3.3. Góc nhìn Alert Notification (`{job="alert-sink"}`)
Truy vấn:
```logql
{job="alert-sink"}
```
**Kết quả ghi nhận:**
```
[ALERT-SINK] WEBHOOK ALERT RECEIVED AT 2026-10-19T10:18:50Z
Endpoint: /alert
Alert Details:
  - Alert Name: CRM_BruteForce_Detected
    Status:     firing
    Severity:   critical
    Summary:    CRM Brute-Force Authentication Attack Detected
```
*Nhận xét:* Kênh tiếp nhận cảnh báo hoạt động hoàn hảo, thông báo được ghi nhận trong vòng dưới 10 giây kể từ khi hành vi tấn công diễn ra.

---

## 4. Biện pháp Khắc phục Đã Triển khai (Remediation)

### 4.1. Giới hạn tần suất yêu cầu trên Nginx (Rate Limiting)
Đã cấu hình trực tiếp trong `nginx/nginx.conf`:
- Khởi tạo bộ nhớ chia sẻ `crm_login` dung lượng 10MB (lưu trữ tới 160.000 địa chỉ IP) với tần suất tối đa cho phép là **5 yêu cầu / phút** (`rate=5r/m`).
- Áp dụng vào riêng khối `location = /login`:
  - `burst=5`: Cho phép đệm tối đa 5 yêu cầu gửi nhanh.
  - `nodelay`: Xử lý tức thời các yêu cầu trong burst mà không trì hoãn.
  - Từ yêu cầu vượt ngưỡng trở đi, Nginx chủ động từ chối và trả về mã lỗi **HTTP 429 Too Many Requests**.

#### Trích đoạn cấu hình Nginx sau khắc phục:
```nginx
http {
    ...
    # Rate Limiting: Phòng thủ tấn công Brute-Force vào trang xác thực
    limit_req_zone $binary_remote_addr zone=crm_login:10m rate=5r/m;
    limit_req_status 429;

    server {
        listen 443 ssl;
        ...

        # ---------------------------------------------------------------------
        # CRM Login với Rate Limiting (Phòng thủ Brute-Force)
        # ---------------------------------------------------------------------
        location = /login {
            limit_req zone=crm_login burst=5 nodelay;

            proxy_pass http://web:8000;
            proxy_http_version 1.1;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;

            # Security Headers
            add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; frame-ancestors 'self';" always;
            add_header X-Frame-Options SAMEORIGIN always;
            add_header X-Content-Type-Options nosniff always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header Referrer-Policy strict-origin-when-cross-origin always;
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
        }
        ...
    }
}
```

### 4.2. Kết quả kiểm thử sau khi áp dụng Rate Limiting
Gửi liên tiếp 10 yêu cầu tới `/login`:
- Request #1 đến #6: Trả về **HTTP 200** (cho phép người dùng hợp lệ thao tác).
- Request #7 đến #10: Ngay lập tức bị Nginx chặn đứng và trả về **HTTP 429** (Too Many Requests).
- Lưu lượng tấn công bị triệt tiêu ngay tại tầng Reverse Proxy, hoàn toàn không gây tải tới Web App Gunicorn và Cơ sở dữ liệu PostgreSQL.

---

## 5. Khuyến nghị Nâng cao cho Môi trường Production

1. **Khóa tài khoản tạm thời (Account Lockout Policy):**
   - Triển khai bộ đếm số lần đăng nhập sai trong Redis hoặc PostgreSQL.
   - Nếu nhập sai quá 5 lần liên tiếp trong 15 phút, tạm khóa tài khoản trong 30 phút và gửi email cảnh báo tới chủ sở hữu tài khoản.
2. **Tích hợp cơ chế CAPTCHA bảo vệ:**
   - Sau 3 lần đăng nhập sai, bắt buộc hiển thị thử thách CAPTCHA (Cloudflare Turnstile hoặc Google reCAPTCHA v3) để ngăn chặn các bot tự động hóa.
3. **Phòng thủ chủ động bằng Fail2ban:**
   - Cấu hình Fail2ban đọc log từ Nginx hoặc Loki.
   - Khi phát hiện một IP sinh ra quá 5 lỗi 429 hoặc `LOGIN_FAILED` trong 1 phút, tự động thêm rule `iptables` / `nftables` chặn toàn bộ kết nối từ IP đó trong 24 giờ.
4. **Triển khai Web Application Firewall (WAF):**
   - Bổ sung module ModSecurity (kèm bộ quy tắc OWASP Core Rule Set - CRS) vào Nginx để nhận diện và ngăn chặn các mẫu payload dò quét tự động.
5. **Xác thực đa yếu tố (MFA / 2FA):**
   - Bắt buộc kích hoạt TOTP (Time-based One-Time Password qua Google Authenticator / Microsoft Authenticator) đối với tất cả tài khoản có vai trò Quản lý (`role = manager`).

---
**Người lập báo cáo:** NGUYEN THI QUYNH THO (MSSV: dtc245340007)
