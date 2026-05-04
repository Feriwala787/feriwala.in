#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${API_BASE_URL:-https://api.feriwala.in/api}"
EMAIL="${DELIVERY_EMAIL:-}"
PASSWORD="${DELIVERY_PASSWORD:-}"

if [[ -z "$EMAIL" || -z "$PASSWORD" ]]; then
  echo "Set DELIVERY_EMAIL and DELIVERY_PASSWORD to run smoke flow."
  exit 1
fi

echo "[1/5] Login"
LOGIN_RESP=$(curl -sS -X POST "$BASE_URL/auth/login" -H 'Content-Type: application/json' \
  -d "{\"credential\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
ACCESS_TOKEN=$(echo "$LOGIN_RESP" | python -c "import sys, json; print(json.load(sys.stdin)['data']['accessToken'])")

echo "[2/5] Fetch tasks"
TASKS_RESP=$(curl -sS "$BASE_URL/delivery/my-tasks" -H "Authorization: Bearer $ACCESS_TOKEN")
TASK_ID=$(echo "$TASKS_RESP" | python -c "import sys, json; data=json.load(sys.stdin).get('data',[]); print(data[0]['id'] if data else '')")
if [[ -z "$TASK_ID" ]]; then
  echo "No tasks available in staging account."
  exit 0
fi

echo "[3/5] Accept task $TASK_ID"
curl -sS -X PUT "$BASE_URL/delivery/tasks/$TASK_ID/accept" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null

echo "[4/5] Move to in_transit (OTP steps must be done manually in app if required)"
curl -sS -X PUT "$BASE_URL/delivery/tasks/$TASK_ID/status" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d '{"status":"in_transit"}' >/dev/null || true

echo "[5/5] Complete smoke finished for task $TASK_ID"
echo "NOTE: OTP-required transitions should be verified manually in the app UI."
