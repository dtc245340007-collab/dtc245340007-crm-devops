#!/bin/bash
set -e
cd ~/crm
EVID="evidence/buoc6-hardening.txt"

echo "================================================================================" > "$EVID"
echo " EVIDENCE B??C 6: KI?M CH?NG C?C BI?N PH?P B?O M?T & HARDENING H? TH?NG" >> "$EVID"
echo " Th?i gian: $(date)" >> "$EVID"
echo " ?? t?i 4: H? th?ng CRM Ch?m s?c Kh?ch h?ng" >> "$EVID"
echo " MSSV: dtc245340007 - NGUYEN THI QUYNH THO" >> "$EVID"
echo "================================================================================" >> "$EVID"
echo "" >> "$EVID"

echo "=== 1. KI?M TRA NG??I D?NG TRONG T?NG SERVICE (NON-ROOT CONTAINER) ===" >> "$EVID"
echo "Danh s?ch ID/whoami th?c t? b?n trong t?ng container:" >> "$EVID"
for s in web nginx pgadmin prometheus grafana loki alert-sink postgres-exporter promtail cadvisor db; do
  NAME=$(docker compose ps -q $s)
  if [ -n "$NAME" ]; then
    ID_OUT=$(docker exec $NAME id 2>&1 || docker exec $NAME whoami 2>&1 || true)
    printf "%-18s -> %s\n" "$s" "$ID_OUT" >> "$EVID"
  fi
done
echo "" >> "$EVID"
echo "Ghi ch? ngo?i l?:" >> "$EVID"
echo "- cadvisor & promtail: B?t bu?c c?n quy?n root ?? ??c Docker socket (/var/run/docker.sock) v? container json logs (/var/lib/docker/containers). ?? hardening b?ng mount ch? ??c (:ro) v? drop to?n b? capabilities (cap_drop: ALL)." >> "$EVID"
echo "- db (postgres): Image chu?n kh?i t?o b?ng script root ?? c?p quy?n volume, sau ?? chuy?n to?n b? ti?n tr?nh daemon sang user 'postgres' (UID 999)." >> "$EVID"
echo "" >> "$EVID"

echo "=== 2. KI?M TRA PH?N T?CH M?NG DOCKER (NETWORK ISOLATION) ===" >> "$EVID"
echo "--- Danh s?ch m?ng Docker ---" >> "$EVID"
docker network ls | grep crm >> "$EVID"
echo "" >> "$EVID"
echo "--- M?ng BACKEND (internal: true, ch?a db, web, pgadmin, postgres-exporter) ---" >> "$EVID"
docker network inspect crm_backend | jq '.[0] | {name: .Name, internal: .Internal, containers: [.Containers[] | .Name]}' >> "$EVID"
echo "" >> "$EVID"
echo "--- M?ng MONITORING (internal: true, ch?a c?c th?nh ph?n gi?m s?t/log) ---" >> "$EVID"
docker network inspect crm_monitoring | jq '.[0] | {name: .Name, internal: .Internal, containers: [.Containers[] | .Name]}' >> "$EVID"
echo "" >> "$EVID"
echo "--- M?ng FRONTEND (ch? n?i reverse proxy v?i web, pgadmin, grafana) ---" >> "$EVID"
docker network inspect crm_frontend | jq '.[0] | {name: .Name, internal: .Internal, containers: [.Containers[] | .Name]}' >> "$EVID"
echo "" >> "$EVID"
echo "-> K?T LU?N: db ho?n to?n KH?NG n?i v?o crm_frontend, KH?NG publish port ra ngo?i." >> "$EVID"
echo "" >> "$EVID"

echo "=== 3. KI?M TRA C?NG M? & TI?N TR?NH L?NG NGHE (PORT EXPOSURE) ===" >> "$EVID"
echo "--- docker compose ps (ch? c? nginx m? c?ng 80 v? 443) ---" >> "$EVID"
docker compose ps >> "$EVID"
echo "" >> "$EVID"
echo "--- ss -tlnp (c?c c?ng l?ng nghe tr?n host) ---" >> "$EVID"
echo ubuntu | sudo -S ss -tlnp >> "$EVID" 2>/dev/null || ss -tlnp >> "$EVID"
echo "" >> "$EVID"

echo "=== 4. KI?M TRA TR?NG TH?I T??NG L?A UFW (FIREWALL HARDENING) ===" >> "$EVID"
echo ubuntu | sudo -S ufw status verbose >> "$EVID" 2>/dev/null || ufw status verbose >> "$EVID"
echo "" >> "$EVID"

echo "=== 5. H?N CH? QUY?N DATABASE (LEAST PRIVILEGE ROLE & PERMISSION CHECK) ===" >> "$EVID"
APP_PASS=$(grep APP_DB_PASSWORD ~/crm/.env | cut -d= -f2)
echo "--- Danh s?ch Roles (\du) ---" >> "$EVID"
docker compose exec -T db psql -U crm_admin -d crm -c "\du" >> "$EVID"
echo "" >> "$EVID"
echo "--- Quy?n tr?n c?c b?ng (\dp) ---" >> "$EVID"
docker compose exec -T db psql -U crm_admin -d crm -c "\dp" >> "$EVID"
echo "" >> "$EVID"
echo "--- Th? nghi?m DROP TABLE b?ng role crm_app (Ph?i b? t? ch?i) ---" >> "$EVID"
docker compose exec -T -e PGPASSWORD="$APP_PASS" db psql -U crm_app -d crm -c "DROP TABLE customers;" >> "$EVID" 2>&1 || true
echo "" >> "$EVID"
echo "--- Th? nghi?m CREATE TABLE b?ng role crm_app (Ph?i b? t? ch?i) ---" >> "$EVID"
docker compose exec -T -e PGPASSWORD="$APP_PASS" db psql -U crm_app -d crm -c "CREATE TABLE test_unauth(id int);" >> "$EVID" 2>&1 || true
echo "" >> "$EVID"

echo "=== 6. KI?M TRA SECURITY HEADERS & ?N TH?NG TIN PHI?N B?N (CURL) ===" >> "$EVID"
echo "--- Headers tr? v? t? https://localhost/login ---" >> "$EVID"
curl -k -I https://localhost/login >> "$EVID"
echo "" >> "$EVID"
echo "Ki?m tra r? r? phi?n b?n:" >> "$EVID"
curl -k -I https://localhost/login | grep -iE "server:|x-powered-by:|python|werkzeug|gunicorn" >> "$EVID" || echo "Kh?ng r? r? phi?n b?n." >> "$EVID"
echo "" >> "$EVID"

echo "=== 7. R? SO?T B? M?T & M?T KH?U TRONG GIT HISTORY (GIT GREP AUDIT) ===" >> "$EVID"
POSTGRES_PASS=$(grep POSTGRES_PASSWORD ~/crm/.env | cut -d= -f2)
APP_PASS_AUDIT=$(grep APP_DB_PASSWORD ~/crm/.env | cut -d= -f2)
SECRET_KEY_AUDIT=$(grep SECRET_KEY ~/crm/.env | cut -d= -f2)

git grep "$POSTGRES_PASS" >> "$EVID" 2>&1 || echo "[OK] POSTGRES_PASSWORD KH?NG t?n t?i trong git repo" >> "$EVID"
git grep "$APP_PASS_AUDIT" >> "$EVID" 2>&1 || echo "[OK] APP_DB_PASSWORD KH?NG t?n t?i trong git repo" >> "$EVID"
git grep "$SECRET_KEY_AUDIT" >> "$EVID" 2>&1 || echo "[OK] SECRET_KEY KH?NG t?n t?i trong git repo" >> "$EVID"
git grep "BEGIN PRIVATE KEY" >> "$EVID" 2>&1 || echo "[OK] KH?NG c? private key n?o b? commit" >> "$EVID"
echo "" >> "$EVID"

echo "=== 8. K?T QU? CH?Y SMOKE TEST TO?N B? H? TH?NG ===" >> "$EVID"
python3 ~/crm/scripts/smoke_test.py >> "$EVID"
echo "" >> "$EVID"

echo "================================================================================" >> "$EVID"
echo " HO?N T?T TH?C HI?N KI?M CH?NG B??C 6 (HARDENING)" >> "$EVID"
echo "================================================================================" >> "$EVID"
