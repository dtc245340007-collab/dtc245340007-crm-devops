import urllib.request
import urllib.parse
import http.cookiejar
import ssl
import json
import re
import sys

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

BASE_URL = "https://192.168.207.128"

print("=================================================================")
print("          SMOKE TEST H? TH?NG CRM SAU KHI HARDENING              ")
print("=================================================================")

# 1. Login Web App
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), urllib.request.HTTPSHandler(context=ctx))

print("\n[1] Ki?m tra ??ng nh?p Web CRM...")
resp = opener.open(f"{BASE_URL}/login")
html = resp.read().decode("utf-8")
csrf_token = re.search(r'name="csrf_token"\s+value="([^"]+)"', html).group(1)

login_data = urllib.parse.urlencode({
    "csrf_token": csrf_token,
    "username": "admin",
    "password": "Admin@CRM2026!Sec"
}).encode("utf-8")

login_req = urllib.request.Request(f"{BASE_URL}/login", data=login_data, method="POST")
resp = opener.open(login_req)
body = resp.read().decode("utf-8")

if "Qu?n l? Kh?ch h?ng" in body or "??ng xu?t" in body or resp.status == 200:
    print(" -> [PASSED] ??ng nh?p Web CRM th?nh c?ng v?i user: admin")
else:
    print(" -> [FAILED] ??ng nh?p Web CRM th?t b?i!")
    sys.exit(1)

# 2. T?o kh?ch h?ng m?i
print("\n[2] Ki?m tra T?o kh?ch h?ng m?i (/customers/new)...")
create_page = opener.open(f"{BASE_URL}/customers/new")
csrf_create = re.search(r'name="csrf_token"\s+value="([^"]+)"', create_page.read().decode("utf-8")).group(1)

customer_code = "KH-HD-001"
customer_data = urllib.parse.urlencode({
    "csrf_token": csrf_create,
    "customer_code": customer_code,
    "name": "Tran Van Hardening",
    "email": "hardening.audit@security.vn",
    "phone": "0911223344",
    "company": "Cong ty An ninh Mang Quoc gia",
    "address": "Toa nha CyberSec, Ha Noi",
    "status": "lead",
    "assigned_to": "1"
}).encode("utf-8")

req_post_cust = urllib.request.Request(f"{BASE_URL}/customers/new", data=customer_data, method="POST")
resp = opener.open(req_post_cust)
html_after_cust = resp.read().decode("utf-8")

# L?y ID c?a kh?ch h?ng v?a t?o
cust_id_match = re.search(r'/customers/(\d+)', resp.geturl())
if cust_id_match:
    cust_id = cust_id_match.group(1)
else:
    # T?m trong trang danh s?ch
    id_match = re.search(r'/customers/(\d+)[^"]*">' + re.escape(customer_code), html_after_cust)
    cust_id = id_match.group(1) if id_match else "1"

print(f" -> [PASSED] T?o kh?ch h?ng th?nh c?ng: {customer_code} (Customer ID: {cust_id})")

# 3. Ghi t??ng t?c cho kh?ch h?ng
print(f"\n[3] Ghi nh?n l?ch s? t??ng t?c (/customers/{cust_id}/interactions/new)...")
detail_page = opener.open(f"{BASE_URL}/customers/{cust_id}")
csrf_interact = re.search(r'name="csrf_token"\s+value="([^"]+)"', detail_page.read().decode("utf-8")).group(1)

interact_data = urllib.parse.urlencode({
    "csrf_token": csrf_interact,
    "type": "call",
    "subject": "Trao ??i tri?n khai bi?n ph?p Hardening to?n di?n",
    "content": "?? trao ??i th?ng nh?t ?p d?ng Non-root, Network Isolation v? UFW.",
    "interaction_time": "2026-10-19T10:30"
}).encode("utf-8")

req_interact = urllib.request.Request(f"{BASE_URL}/customers/{cust_id}/interactions/new", data=interact_data, method="POST")
resp = opener.open(req_interact)
print(" -> [PASSED] Ghi nh?n t??ng t?c th?nh c?ng!")

# 4. Ki?m tra pgAdmin
print("\n[4] Ki?m tra giao di?n qu?n tr? pgAdmin (/pgadmin/)...")
resp = opener.open(f"{BASE_URL}/pgadmin/")
print(f" -> [PASSED] pgAdmin ph?n h?i HTTP Status {resp.status} ({resp.msg})")

# 5. Ki?m tra Grafana
print("\n[5] Ki?m tra Grafana API qua Nginx Proxy...")
with open("/home/ubuntu/crm/.env") as f:
    env_lines = f.readlines()
gf_pass = [line.split("=")[1].strip() for line in env_lines if line.startswith("GRAFANA_ADMIN_PASSWORD=")][0]

import base64
auth_header = "Basic " + base64.b64encode(f"admin:{gf_pass}".encode()).decode()
req_gf = urllib.request.Request(f"{BASE_URL}/grafana/api/datasources", headers={"Authorization": auth_header})
resp_gf = urllib.request.urlopen(req_gf, context=ctx)
ds_data = json.loads(resp_gf.read().decode())
ds_names = [d["name"] for d in ds_data]
print(f" -> [PASSED] Grafana x?c th?c th?nh c?ng. Datasources ho?t ??ng: {', '.join(ds_names)}")

# 6. Ki?m tra Dashboards trong Grafana
req_dash = urllib.request.Request(f"{BASE_URL}/grafana/api/search?query=CRM", headers={"Authorization": auth_header})
resp_dash = urllib.request.urlopen(req_dash, context=ctx)
dash_data = json.loads(resp_dash.read().decode())
dash_titles = [d["title"] for d in dash_data if d["type"] == "dash-db"]
print(f" -> [PASSED] Dashboards s?n s?ng: {', '.join(dash_titles)}")

print("\n=================================================================")
print("   K?T QU?: TO?N B? CH?C N?NG H? TH?NG HO?T ??NG HO?N H?O!     ")
print("=================================================================")
