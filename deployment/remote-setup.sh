#!/bin/bash
set -e

echo "=== Setting up PostgreSQL ==="
sudo -u postgres psql <<'PGEOF'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'feriwala') THEN
    CREATE USER feriwala WITH PASSWORD 'FeriwalaDB2024!';
  END IF;
END
$$;
CREATE DATABASE feriwala_db OWNER feriwala;
GRANT ALL PRIVILEGES ON DATABASE feriwala_db TO feriwala;
PGEOF
echo "PostgreSQL setup complete."

echo "=== Creating app directories ==="
mkdir -p /home/bitnami/feriwala/backend/uploads
mkdir -p /home/bitnami/feriwala/admin-portal/build
mkdir -p /home/bitnami/feriwala/logs

echo "=== Writing .env ==="
cat > /home/bitnami/feriwala/backend/.env <<'ENVEOF'
NODE_ENV=production
PORT=3000
MONGODB_URI=mongodb+srv://Feriwala:DTAv%4068RHLhinWm@cluster0.v2dvryi.mongodb.net/feriwala_users?retryWrites=true&w=majority&appName=Cluster0
PG_HOST=localhost
PG_PORT=5432
PG_DATABASE=feriwala_db
PG_USER=feriwala
PG_PASSWORD=FeriwalaDB2024!
JWT_SECRET=fw-jwt-s3cr3t-f3r1w4l4-pr0duct10n-2024
JWT_EXPIRES_IN=7d
JWT_REFRESH_SECRET=fw-r3fr3sh-s3cr3t-f3r1w4l4-2024
JWT_REFRESH_EXPIRES_IN=30d
GOOGLE_MAPS_API_KEY=AIzaSyDKijqkofbXiD1WOkPmW-6CQFEpRuLHCJ4
SERVER_URL=http://13.233.227.15:3000
MAX_FILE_SIZE=5242880
UPLOAD_PATH=./uploads
SOCKET_CORS_ORIGIN=*
ENVEOF
echo "Done."
