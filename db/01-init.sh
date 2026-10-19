#!/bin/bash
set -e

# Kh?i t?o role cho ?ng d?ng web (kh?ng superuser, quy?n t?i thi?u)
# S? d?ng password_encryption = scram-sha-256
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SET password_encryption = 'scram-sha-256';

    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${APP_DB_USER}') THEN
            CREATE ROLE ${APP_DB_USER} WITH LOGIN PASSWORD '${APP_DB_PASSWORD}';
        ELSE
            ALTER ROLE ${APP_DB_USER} WITH PASSWORD '${APP_DB_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Hardening quy?n tr?n schema public
    REVOKE CREATE ON SCHEMA public FROM PUBLIC;
    REVOKE ALL ON SCHEMA public FROM ${APP_DB_USER};
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${APP_DB_USER};
    GRANT USAGE ON SCHEMA public TO ${APP_DB_USER};
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${APP_DB_USER};
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${APP_DB_USER};

    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_DB_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ${APP_DB_USER};

    -- Kh?i t?o role cho Prometheus Postgres Exporter (pg_monitor)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'exporter') THEN
            CREATE ROLE exporter WITH LOGIN PASSWORD '${POSTGRES_EXPORTER_PASSWORD}';
            GRANT pg_monitor TO exporter;
        ELSE
            ALTER ROLE exporter WITH PASSWORD '${POSTGRES_EXPORTER_PASSWORD}';
            GRANT pg_monitor TO exporter;
        END IF;
    END
    \$\$;
EOSQL
