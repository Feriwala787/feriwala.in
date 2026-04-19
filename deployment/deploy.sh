#!/bin/bash
# Run from local machine: bash deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ENV_FILE="${SCRIPT_DIR}/.env"
APP_ENV_FILE="${APP_ENV_FILE:-${SCRIPT_DIR}/backend.env}"

source_nonempty_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0

  while IFS='=' read -r key value; do
    key="${key%%[[:space:]]*}"
    value="${value:-}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    if [ -n "$value" ] && [ -z "${!key:-}" ]; then
      export "$key=$value"
    fi
  done < <(grep -Ev '^[[:space:]]*(#|$)' "$file")

  return 0
}

source_nonempty_env_file "$DEPLOY_ENV_FILE"

SERVER_HOST="${SERVER_HOST:-65.2.9.216}"
SSH_USER="${SSH_USER:-bitnami}"
KEY_PATH="${KEY_PATH:-./feriwala-key.pem}"
SSH_CERT_PATH="${SSH_CERT_PATH:-${KEY_PATH}-cert.pub}"
REMOTE_DIR="${REMOTE_DIR:-/home/bitnami/feriwala}"
TEMP_KEY_DIR=""

if { [ ! -s "$KEY_PATH" ] || [ ! -f "$KEY_PATH" ]; } && command -v aws >/dev/null 2>&1 && [ -n "${AWS_LIGHTSAIL_INSTANCE_NAME:-}" ]; then
  echo ">> Fetching temporary Lightsail SSH access via AWS CLI..."
  TEMP_KEY_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_KEY_DIR"' EXIT
  ACCESS_JSON="$TEMP_KEY_DIR/access.json"
  aws lightsail get-instance-access-details \
    --region "${AWS_REGION:-ap-south-1}" \
    --instance-name "$AWS_LIGHTSAIL_INSTANCE_NAME" \
    > "$ACCESS_JSON"
  python - "$ACCESS_JSON" "$TEMP_KEY_DIR" <<'PY'
import json
import os
import sys
from pathlib import Path
access_path = Path(sys.argv[1])
out_dir = Path(sys.argv[2])
payload = json.loads(access_path.read_text())['accessDetails']
(out_dir / 'lightsail.pem').write_text(payload['privateKey'])
cert = payload.get('certKey', '')
if cert:
    (out_dir / 'lightsail-cert.pub').write_text(cert + '\n')
if payload.get('ipAddress'):
    print(payload['ipAddress'])
PY
  SERVER_HOST="$(python -c 'import json,sys; print(json.load(open(sys.argv[1]))["accessDetails"].get("ipAddress",""))' "$ACCESS_JSON")"
  SSH_USER="$(python -c 'import json,sys; print(json.load(open(sys.argv[1]))["accessDetails"].get("username","bitnami"))' "$ACCESS_JSON")"
  KEY_PATH="$TEMP_KEY_DIR/lightsail.pem"
  SSH_CERT_PATH="$TEMP_KEY_DIR/lightsail-cert.pub"
fi

SERVER="${SSH_USER}@${SERVER_HOST}"
SSH_BASE="ssh -o StrictHostKeyChecking=no -i $KEY_PATH"
if [ -f "$SSH_CERT_PATH" ]; then
  SSH_BASE="$SSH_BASE -o CertificateFile=$SSH_CERT_PATH"
fi
RSYNC_SSH="$SSH_BASE"

echo "=== Feriwala Deployment ==="
echo "Target: ${SERVER}"

if [ ! -s "$KEY_PATH" ]; then
  echo "SSH access not available. Provide a valid key at $KEY_PATH or configure AWS CLI credentials plus AWS_LIGHTSAIL_INSTANCE_NAME."
  exit 1
fi

# Ensure remote directories exist
echo ">> Preparing remote directories..."
eval "$SSH_BASE" "$SERVER" "mkdir -p '$REMOTE_DIR/backend' '$REMOTE_DIR/admin-portal/build' '$REMOTE_DIR/deployment' '$REMOTE_DIR/logs'"

echo ">> Ensuring rsync is installed on the server..."
eval "$SSH_BASE" "$SERVER" "command -v rsync >/dev/null 2>&1 || (sudo apt-get update -y && sudo apt-get install -y rsync)"

# 1. Sync backend code
echo ">> Syncing backend..."
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude '.env' \
  --exclude 'uploads' \
  -e "$RSYNC_SSH" \
  "$SCRIPT_DIR/../backend/" "$SERVER:$REMOTE_DIR/backend/"

# 2. Sync admin portal build
echo ">> Building admin portal..."
cd "$SCRIPT_DIR/../admin-portal"
npm run build

echo ">> Syncing admin portal build..."
rsync -avz --delete \
  -e "$RSYNC_SSH" \
  "$SCRIPT_DIR/../admin-portal/build/" "$SERVER:$REMOTE_DIR/admin-portal/build/"

# 3. Sync deployment configs
echo ">> Syncing deployment configs..."
eval scp -o StrictHostKeyChecking=no -i "$KEY_PATH" ${SSH_CERT_PATH:+-o CertificateFile="$SSH_CERT_PATH"} "$SCRIPT_DIR/ecosystem.config.js" "$SCRIPT_DIR/remote-setup.sh" "$SCRIPT_DIR/setup-server.sh" "$SERVER:$REMOTE_DIR/deployment/"
eval scp -o StrictHostKeyChecking=no -i "$KEY_PATH" ${SSH_CERT_PATH:+-o CertificateFile="$SSH_CERT_PATH"} "$SCRIPT_DIR/nginx.conf" "$SERVER:/tmp/feriwala-nginx.conf"

if [ -f "$APP_ENV_FILE" ]; then
  eval scp -o StrictHostKeyChecking=no -i "$KEY_PATH" ${SSH_CERT_PATH:+-o CertificateFile="$SSH_CERT_PATH"} "$APP_ENV_FILE" "$SERVER:$REMOTE_DIR/deployment/.env"
elif [ -f "$DEPLOY_ENV_FILE" ] && grep -q "^MONGODB_URI=" "$DEPLOY_ENV_FILE"; then
  echo ">> APP_ENV_FILE not found; using legacy deployment/.env as backend env."
  eval scp -o StrictHostKeyChecking=no -i "$KEY_PATH" ${SSH_CERT_PATH:+-o CertificateFile="$SSH_CERT_PATH"} "$DEPLOY_ENV_FILE" "$SERVER:$REMOTE_DIR/deployment/.env"
else
  echo "Missing app env file. Create deployment/backend.env (from deployment/backend.env.example) or set APP_ENV_FILE."
  exit 1
fi

# 4. Remote setup and restart
echo ">> Running remote setup..."
eval "$SSH_BASE" "$SERVER" <<ENDSSH
  set -e
  cd "$REMOTE_DIR"
  chmod +x deployment/remote-setup.sh
  bash deployment/remote-setup.sh

  sudo cp /tmp/feriwala-nginx.conf /etc/nginx/sites-available/feriwala
  sudo ln -sf /etc/nginx/sites-available/feriwala /etc/nginx/sites-enabled/feriwala
  sudo nginx -t
  sudo systemctl restart nginx

  echo "=== Deployment complete ==="
  pm2 status
ENDSSH
