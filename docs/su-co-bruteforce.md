# B?o C?o X? L? S? C? An To?n Th?ng Tin: T?n C?ng Brute-Force X?c Th?c CRM

**M?n h?c:** Tri?n khai v? Qu?n tr? H? th?ng Ph?n m?m  
**H?c vi?n:** NGUYEN THI QUYNH THO  
**MSSV:** dtc245340007  
**?? t?i 4:** H? th?ng CRM Ch?m s?c Kh?ch h?ng  
**M? s? c?:** `INC-SEC-2026-001`  
**M?c ?? nghi?m tr?ng:** `CRITICAL` (P1)  
**Tr?ng th?i:** `RESOLVED / MITIGATED`  

---

## 1. M? t? K?ch b?n v? M?c ti?u T?n c?ng

### 1.1. B?i c?nh s? c?
H? th?ng CRM Ch?m s?c Kh?ch h?ng cung c?p c?ng ??ng nh?p t?p trung t?i `https://192.168.207.128/login` cho Qu?n l? v? Nh?n vi?n CSKH. C?ng ??ng nh?p n?y l? ?i?m truy c?p tr?ng y?u b?o v? d? li?u kh?ch h?ng, l?ch s? giao d?ch v? th?ng tin kinh doanh nh?y c?m.

### 1.2. K?ch b?n & K? thu?t t?n c?ng
- **K? thu?t:** T?n c?ng d? qu?t m?t kh?u t? ??ng (Brute-Force Attack / Password Guessing / Credential Stuffing).
- **M?c ti?u:** T?i kho?n qu?n tr? c?p cao `admin`.
- **H?nh vi c?a k? t?n c?ng:**
  1. S? d?ng script t? ??ng h?a (`scripts/simulate_bruteforce.sh`) g?i y?u c?u GET t?i `https://192.168.207.128/login` ?? tr?ch xu?t `csrf_token` v? session cookie h?p l? nh?m v??t qua l?p b?o v? CSRF.
  2. G?i d?n d?p 20 y?u c?u HTTP POST li?n ti?p th? c?c m?t kh?u ph? bi?n (`123456`, `password`, `admin123`, `qwerty`,...) v?i t?n su?t cao (kho?ng 0.5s/request).
- **M?c ??ch:** Chi?m quy?n ?i?u khi?n t?i kho?n qu?n tr? vi?n t?i cao c?a h? th?ng CRM nh?m ??nh c?p ho?c ph? ho?i d? li?u kh?ch h?ng.

---

## 2. C? ch? Ph?t hi?n S? c? (Detection)

### 2.1. D?u hi?u nh?n bi?t
- **T?n su?t y?u c?u b?t th??ng:** Xu?t hi?n nhi?u y?u c?u POST t?i endpoint `/login` t? m?t ??a ch? IP duy nh?t trong kho?ng th?i gian r?t ng?n (< 15 gi?y).
- **Th?ng ?i?p nh?t k? ?ng d?ng:** Web application li?n t?c ghi nh?n s? ki?n th?t b?i v?o lu?ng `STDERR` v?i m?u ??nh d?ng:
  ```
  LOGIN_FAILED ip=<IP> user=admin reason=wrong_password
  ```

### 2.2. Bi?u th?c gi?m s?t & C?nh b?o (Grafana / LogQL Alert Rule)
H? th?ng thi?t l?p lu?t c?nh b?o t? ??ng tr?n Grafana Alerting:
- **T?n c?nh b?o:** `CRM_BruteForce_Detected`
- **M?c ??:** `critical`
- **Bi?u th?c LogQL ph?t hi?n:**
  ```logql
  sum(count_over_time({job="webapp"} |= "LOGIN_FAILED" [1m]))
  ```
- **?i?u ki?n k?ch ho?t:** Gi? tr? t?ng s? l?n ??ng nh?p th?t b?i v??t qu? **5 l?n trong v?ng 1 ph?t** (`threshold: gt 5`).
- **Chu k? ??nh gi? (Evaluation Interval):** 10 gi?y.
- **Th?i gian duy tr? tr??c khi b?n c?nh b?o (For):** 0 gi?y (b?n t?c th? khi v??t ng??ng).
- **?i?m ti?p nh?n c?nh b?o (Contact Point):** Webhook n?i b? g?i v? `alert-sink:5000/alert`.

### 2.3. B?ng ch?ng k?ch ho?t c?nh b?o
Khi script t?n c?ng g?i ??n request th? 6, t?ng s? l?n `LOGIN_FAILED` v??t ng??ng 5. Grafana Alerting l?p t?c chuy?n tr?ng th?i sang `firing` v? ph?t webhook notification:
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

## 3. Truy v?t Nguy?n nh?n G?c r? qua Log t?p trung Loki (Incident Tracing)

Nh? h? t?ng thu th?p nh?t k? Promtail v? l?u tr? t?p trung Loki, k? s? DevOps c? th? truy v?t to?n di?n s? c? theo 3 g?c nh?n t??ng quan:

### 3.1. G?c nh?n Nginx Reverse Proxy (`{job="nginx"}`)
Truy v?n:
```logql
{job="nginx"} |= "POST /login"
```
**K?t qu? ghi nh?n:**
```
192.168.207.128 - - [19/Oct/2026:10:20:51 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.100 ...
192.168.207.128 - - [19/Oct/2026:10:20:51 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.095 ...
192.168.207.128 - - [19/Oct/2026:10:20:52 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.086 ...
192.168.207.128 - - [19/Oct/2026:10:20:53 +0000] "POST /login HTTP/2.0" 200 1723 "-" "curl/8.18.0" rt=0.090 ...
...
```
*Nh?n x?t:* X?c ??nh ch?nh x?c ??a ch? IP ngu?n t?n c?ng l? `192.168.207.128`, User-Agent s? d?ng c?ng c? t? ??ng `curl/8.18.0`.

### 3.2. G?c nh?n Web Application (`{job="webapp"}`)
Truy v?n:
```logql
{job="webapp"} |= "LOGIN_FAILED"
```
**K?t qu? ghi nh?n:**
```
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
LOGIN_FAILED ip=192.168.207.128 user=admin reason=wrong_password
...
```
*Nh?n x?t:* X?c nh?n ?ng d?ng ghi nh?n li?n ti?p 20 l?n th? m?t kh?u sai ??i v?i duy nh?t t?i kho?n `admin`. T?t c? request ??u t? IP `192.168.207.128`.

### 3.3. G?c nh?n Alert Notification (`{job="alert-sink"}`)
Truy v?n:
```logql
{job="alert-sink"}
```
**K?t qu? ghi nh?n:**
```
[ALERT-SINK] WEBHOOK ALERT RECEIVED AT 2026-10-19T10:18:50Z
Endpoint: /alert
Alert Details:
  - Alert Name: CRM_BruteForce_Detected
    Status:     firing
    Severity:   critical
    Summary:    CRM Brute-Force Authentication Attack Detected
```
*Nh?n x?t:* K?nh ti?p nh?n c?nh b?o ho?t ??ng ho?n h?o, th?ng b?o ???c ghi nh?n trong v?ng d??i 10 gi?y k? t? khi h?nh vi t?n c?ng di?n ra.

---

## 4. Bi?n ph?p Kh?c ph?c ?? Tri?n khai (Remediation)

### 4.1. Gi?i h?n t?n su?t y?u c?u tr?n Nginx (Rate Limiting)
?? c?u h?nh tr?c ti?p trong `nginx/nginx.conf`:
- Kh?i t?o b? nh? chia s? `crm_login` dung l??ng 10MB (l?u tr? t?i 160.000 ??a ch? IP) v?i t?n su?t t?i ?a cho ph?p l? **5 y?u c?u / ph?t** (`rate=5r/m`).
- ?p d?ng v?o ri?ng kh?i `location = /login`:
  - `burst=5`: Cho ph?p ??m t?i ?a 5 y?u c?u g?i nhanh.
  - `nodelay`: X? l? t?c th? c?c y?u c?u trong burst m? kh?ng tr? ho?n.
  - T? y?u c?u v??t ng??ng tr? ?i, Nginx ch? ??ng t? ch?i v? tr? v? m? l?i **HTTP 429 Too Many Requests**.

#### Tr?ch ?o?n c?u h?nh Nginx sau kh?c ph?c:
```nginx
http {
    ...
    # Rate Limiting: Ph?ng th? t?n c?ng Brute-Force v?o trang x?c th?c
    limit_req_zone $binary_remote_addr zone=crm_login:10m rate=5r/m;
    limit_req_status 429;

    server {
        listen 443 ssl;
        ...

        # ---------------------------------------------------------------------
        # CRM Login v?i Rate Limiting (Ph?ng th? Brute-Force)
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

### 4.2. K?t qu? ki?m th? sau khi ?p d?ng Rate Limiting
G?i li?n ti?p 10 y?u c?u t?i `/login`:
- Request #1 ??n #6: Tr? v? **HTTP 200** (cho ph?p ng??i d?ng h?p l? thao t?c).
- Request #7 ??n #10: Ngay l?p t?c b? Nginx ch?n ??ng v? tr? v? **HTTP 429** (Too Many Requests).
- L?u l??ng t?n c?ng b? tri?t ti?u ngay t?i t?ng Reverse Proxy, ho?n to?n kh?ng g?y t?i t?i Web App Gunicorn v? C? s? d? li?u PostgreSQL.

---

## 5. Khuy?n ngh? N?ng cao cho M?i tr??ng Production

1. **Kh?a t?i kho?n t?m th?i (Account Lockout Policy):**
   - Tri?n khai b? ??m s? l?n ??ng nh?p sai trong Redis ho?c PostgreSQL.
   - N?u nh?p sai qu? 5 l?n li?n ti?p trong 15 ph?t, t?m kh?a t?i kho?n trong 30 ph?t v? g?i email c?nh b?o t?i ch? s? h?u t?i kho?n.
2. **T?ch h?p c? ch? CAPTCHA b?o v?:**
   - Sau 3 l?n ??ng nh?p sai, b?t bu?c hi?n th? th? th?ch CAPTCHA (Cloudflare Turnstile ho?c Google reCAPTCHA v3) ?? ng?n ch?n c?c bot t? ??ng h?a.
3. **Ph?ng th? ch? ??ng b?ng Fail2ban:**
   - C?u h?nh Fail2ban ??c log t? Nginx ho?c Loki.
   - Khi ph?t hi?n m?t IP sinh ra qu? 5 l?i 429 ho?c `LOGIN_FAILED` trong 1 ph?t, t? ??ng th?m rule `iptables` / `nftables` ch?n to?n b? k?t n?i t? IP ?? trong 24 gi?.
4. **Tri?n khai Web Application Firewall (WAF):**
   - B? sung module ModSecurity (k?m b? quy t?c OWASP Core Rule Set - CRS) v?o Nginx ?? nh?n di?n v? ng?n ch?n c?c m?u payload d? qu?t t? ??ng.
5. **X?c th?c ?a y?u t? (MFA / 2FA):**
   - B?t bu?c k?ch ho?t TOTP (Time-based One-Time Password qua Google Authenticator / Microsoft Authenticator) ??i v?i t?t c? t?i kho?n c? vai tr? Qu?n l? (`role = manager`).

---
**Ng??i l?p b?o c?o:** NGUYEN THI QUYNH THO (MSSV: dtc245340007)
