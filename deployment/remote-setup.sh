#!/bin/bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/home/bitnami/feriwala}"
APP_ENV_FILE="${APP_ENV_FILE:-${APP_ROOT}/deployment/.env}"
BACKEND_ENV_TARGET="${APP_ROOT}/backend/.env"

if [ ! -f "$APP_ENV_FILE" ]; then
  echo "Missing app environment file: $APP_ENV_FILE"
  echo "Create deployment/backend.env locally (from deployment/backend.env.example) and set APP_ENV_FILE when deploying."
  exit 1
fi

set -a
source "$APP_ENV_FILE"
set +a

required_vars=(PG_DATABASE PG_USER PG_PASSWORD)
for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "Required variable '$var' is missing in $APP_ENV_FILE"
    exit 1
  fi
done

echo "=== Setting up PostgreSQL ==="
sudo -u postgres psql -v db_user="$PG_USER" -v db_password="$PG_PASSWORD" -v db_name="$PG_DATABASE" <<'PGEOF'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = :'db_user') THEN
    EXECUTE format('CREATE USER %I WITH PASSWORD %L', :'db_user', :'db_password');
  ELSE
    EXECUTE format('ALTER USER %I WITH PASSWORD %L', :'db_user', :'db_password');
  END IF;
END
$$;
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user');
  END IF;
END
$$;
PGEOF
sudo -u postgres psql -v db_user="$PG_USER" -v db_name="$PG_DATABASE" <<'PGEOF'
GRANT ALL PRIVILEGES ON DATABASE :"db_name" TO :"db_user";
PGEOF

echo "=== Creating app directories ==="
mkdir -p "${APP_ROOT}/backend/uploads" "${APP_ROOT}/admin-portal/build" "${APP_ROOT}/logs"

echo "=== Writing backend .env from deployment env ==="
cp "$APP_ENV_FILE" "$BACKEND_ENV_TARGET"
chmod 600 "$BACKEND_ENV_TARGET"

echo "Done."
