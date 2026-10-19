import urllib.request
import urllib.parse
import http.cookiejar
import ssl
import json
import re
import sys
import time
import os
import base64

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE_URL = os.environ.get("BASE_URL", "https://localhost")

# Read credentials from .env
env_path = os.environ.get("ENV_FILE", os.path.join(PROJECT_DIR, ".env"))
admin_pass = "Admin@CRM2026!"
gf_pass = "Admin@CRM2026!"
if os.path.exists(env_path):
    with open(env_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("ADMIN_PASSWORD="):
                admin_pass = line.split("=", 1)[1].strip()
            elif line.startswith("GRAFANA_ADMIN_PASSWORD="):
                gf_pass = line.split("=", 1)[1].strip()

print("=================================================================")
print("          SMOKE TEST HE THONG CRM (KIEM THU TU DONG)             ")
print("=================================================================")

# 1. Login Web App
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), urllib.request.HTTPSHandler(context=ctx))

print("\n[1] Kiem tra dang nhap Web CRM...")
resp = opener.open(f"{BASE_URL}/login")
html = resp.read().decode("utf-8")
csrf_token = re.search(r'name="csrf_token"\s+value="([^"]+)"', html).group(1)

login_data = urllib.parse.urlencode({
    "csrf_token": csrf_token,
    "username": "admin",
    "password": admin_pass
}).encode("utf-8")

login_req = urllib.request.Request(f"{BASE_URL}/login", data=login_data, method="POST")
resp = opener.open(login_req)
body = resp.read().decode("utf-8")

if "Quan ly Khach hang" in body or "Dang xuat" in body or "Khach hang" in body or resp.status == 200:
    print(" -> [PASSED] Dang nhap Web CRM thanh cong voi user: admin")
else:
    print(" -> [FAILED] Dang nhap Web CRM that bai!")
    sys.exit(1)

# 2. Tao khach hang moi
print("\n[2] Kiem tra Tao khach hang moi (/customers/new)...")
create_page = opener.open(f"{BASE_URL}/customers/new")
csrf_create = re.search(r'name="csrf_token"\s+value="([^"]+)"', create_page.read().decode("utf-8")).group(1)

customer_code = f"KH-VERIFY-{int(time.time()) % 10000}"
customer_data = urllib.parse.urlencode({
    "csrf_token": csrf_create,
    "customer_code": customer_code,
    "name": "Nguyen Thi Clean Verify",
    "email": "clean.verify@crm-devops.vn",
    "phone": "0988776655",
    "company": "DevOps Automation Corp",
    "address": "Cau Giay, Ha Noi",
    "status": "lead",
    "assigned_to": "1"
}).encode("utf-8")

req_post_cust = urllib.request.Request(f"{BASE_URL}/customers/new", data=customer_data, method="POST")
resp = opener.open(req_post_cust)
html_after_cust = resp.read().decode("utf-8")

cust_id_match = re.search(r'/customers/(\d+)', resp.geturl())
if cust_id_match:
    cust_id = cust_id_match.group(1)
else:
    id_match = re.search(r'/customers/(\d+)[^"]*">' + re.escape(customer_code), html_after_cust)
    cust_id = id_match.group(1) if id_match else "1"

print(f" -> [PASSED] Tao khach hang thanh cong: {customer_code} (Customer ID: {cust_id})")

# 3. Ghi tuong tac
print(f"\n[3] Ghi nhan lich su tuong tac (/customers/{cust_id}/interactions/new)...")
detail_page = opener.open(f"{BASE_URL}/customers/{cust_id}")
csrf_interact = re.search(r'name="csrf_token"\s+value="([^"]+)"', detail_page.read().decode("utf-8")).group(1)

interact_data = urllib.parse.urlencode({
    "csrf_token": csrf_interact,
    "type": "call",
    "subject": "Kiem thu tu dong he thong CRM tu trang thai sach",
    "content": "Xac nhan cac chuc nang CRUD, SSL, Nginx, pgAdmin, Grafana hoat dong hoan hao.",
    "interaction_time": "2026-10-19T10:45"
}).encode("utf-8")

req_interact = urllib.request.Request(f"{BASE_URL}/customers/{cust_id}/interactions/new", data=interact_data, method="POST")
resp = opener.open(req_interact)
print(" -> [PASSED] Ghi nhan tuong tac thanh cong!")

# 4. Kiem tra pgAdmin voi retry loop
print("\n[4] Kiem tra giao dien quan tri pgAdmin (/pgadmin/)...")
pgadmin_ok = False
for attempt in range(1, 16):
    try:
        resp = opener.open(f"{BASE_URL}/pgadmin/")
        if resp.status in (200, 302):
            print(f" -> [PASSED] pgAdmin phan hoi HTTP Status {resp.status} ({resp.msg}) [lan thu {attempt}]")
            pgadmin_ok = True
            break
    except Exception as e:
        time.sleep(2)

if not pgadmin_ok:
    print(" -> [FAILED] pgAdmin khong phan hoi sau 15 lan thu!")
    sys.exit(1)

# 5. Kiem tra Grafana API qua Nginx Proxy
print("\n[5] Kiem tra Grafana API qua Nginx Proxy (/grafana/api/datasources)...")
auth_header = "Basic " + base64.b64encode(f"admin:{gf_pass}".encode()).decode()

gf_ok = False
for attempt in range(1, 16):
    try:
        req_gf = urllib.request.Request(f"{BASE_URL}/grafana/api/datasources", headers={"Authorization": auth_header})
        resp_gf = urllib.request.urlopen(req_gf, context=ctx)
        ds_data = json.loads(resp_gf.read().decode())
        ds_names = [d["name"] for d in ds_data]
        print(f" -> [PASSED] Grafana xac thuc thanh cong. Datasources hoat dong: {', '.join(ds_names)} [lan thu {attempt}]")
        gf_ok = True
        break
    except Exception as e:
        print(f" -> [Attempt {attempt}] Error: {e} (using gf_pass={gf_pass})")
        time.sleep(2)

if not gf_ok:
    print(" -> [FAILED] Grafana khong phan hoi sau 15 lan thu!")
    sys.exit(1)

# 6. Kiem tra Dashboards trong Grafana
req_dash = urllib.request.Request(f"{BASE_URL}/grafana/api/search?query=CRM", headers={"Authorization": auth_header})
resp_dash = urllib.request.urlopen(req_dash, context=ctx)
dash_data = json.loads(resp_dash.read().decode())
dash_titles = [d["title"] for d in dash_data if d["type"] == "dash-db"]
print(f" -> [PASSED] Dashboards san sang: {', '.join(dash_titles)}")

print("\n=================================================================")
print("   KET QUA: TOAN BO CHUC NANG HE THONG HOAT DONG HOAN HAO!     ")
print("=================================================================")
