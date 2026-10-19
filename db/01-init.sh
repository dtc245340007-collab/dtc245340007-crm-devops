#!/bin/bash
set -e

echo "[01-init.sh] Initializing application role (${APP_DB_USER}) and monitoring role (exporter)..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        -- Role ứng dụng (crm_app)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_DB_USER}') THEN
            CREATE ROLE ${APP_DB_USER} WITH LOGIN PASSWORD '${APP_DB_PASSWORD}';
        ELSE
            ALTER ROLE ${APP_DB_USER} WITH PASSWORD '${APP_DB_PASSWORD}';
        END IF;

        -- Role giám sát (exporter)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'exporter') THEN
            CREATE ROLE exporter WITH LOGIN PASSWORD '${POSTGRES_EXPORTER_PASSWORD:-Ex9pLm4VwRt8Qz2Xn}';
        ELSE
            ALTER ROLE exporter WITH PASSWORD '${POSTGRES_EXPORTER_PASSWORD:-Ex9pLm4VwRt8Qz2Xn}';
        END IF;
    END
    \$\$;

    -- Phân quyền cho role crm_app
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_DB_USER};
    GRANT USAGE ON SCHEMA public TO ${APP_DB_USER};

    -- Phân quyền cho role exporter (pg_monitor)
    GRANT pg_monitor TO exporter;
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO exporter;
EOSQL
echo "[01-init.sh] Roles created and permissions granted successfully."
