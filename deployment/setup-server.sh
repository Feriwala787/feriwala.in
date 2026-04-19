#!/bin/bash
# Initial server setup for Feriwala on AWS Bitnami

set -euo pipefail

APP_ROOT="${APP_ROOT:-/home/bitnami/feriwala}"
APP_ENV_FILE="${APP_ENV_FILE:-${APP_ROOT}/deployment/.env}"

echo "=== Feriwala Server Setup ==="

# Update system
sudo apt-get update

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
sudo npm install -g pm2

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create app directories
mkdir -p "${APP_ROOT}/backend/uploads" "${APP_ROOT}/admin-portal/build" "${APP_ROOT}/logs"

if [ ! -f "$APP_ENV_FILE" ]; then
  echo "Missing $APP_ENV_FILE"
  echo "Create this file from deployment/backend.env.example and re-run setup."
  exit 1
fi

echo "=== Base packages installed. ==="
echo "Next steps:"
echo "1) Ensure $APP_ENV_FILE exists with production secrets"
echo "2) Run deployment/remote-setup.sh to configure PostgreSQL and backend .env"
