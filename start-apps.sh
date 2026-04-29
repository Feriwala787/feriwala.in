#!/bin/bash
# Build and serve all three Flutter web apps locally for testing.
# Usage: bash start-apps.sh [--flutter /path/to/flutter] [--serve /path/to/serve]
#
# Defaults:
#   FLUTTER  — resolved from PATH, then ~/flutter/bin/flutter
#   SERVE    — resolved from PATH (npm install -g serve to install)
#   REPO_DIR — directory containing this script (repo root)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FLUTTER="${FLUTTER:-}"
SERVE="${SERVE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --flutter) FLUTTER="$2"; shift 2 ;;
    --serve)   SERVE="$2";   shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$FLUTTER" ]]; then
  if command -v flutter &>/dev/null; then
    FLUTTER="$(command -v flutter)"
  elif [[ -x "$HOME/flutter/bin/flutter" ]]; then
    FLUTTER="$HOME/flutter/bin/flutter"
  else
    echo "ERROR: flutter not found. Install Flutter or set FLUTTER=/path/to/flutter" >&2
    exit 1
  fi
fi

if [[ -z "$SERVE" ]]; then
  if command -v serve &>/dev/null; then
    SERVE="$(command -v serve)"
  else
    echo "ERROR: 'serve' not found. Run: npm install -g serve" >&2
    exit 1
  fi
fi

echo "Using flutter: $FLUTTER"
echo "Using serve:   $SERVE"
echo "Repo root:     $REPO_DIR"
echo ""

for APP in feriwala_shop feriwala_customer feriwala_delivery; do
  echo "=== Building $APP (release web) ==="
  (cd "$REPO_DIR/$APP" && "$FLUTTER" build web --release 2>&1 | tail -5)
done

echo ""
echo "=== Killing old servers on ports 8081-8083 ==="
kill -9 $(lsof -ti tcp:8081,8082,8083 2>/dev/null) 2>/dev/null || true
sleep 1

echo "=== Starting static servers ==="
nohup "$SERVE" -l 8081 -s "$REPO_DIR/feriwala_shop/build/web"      > /tmp/shop.log 2>&1 &
echo "Shop PID: $!"
nohup "$SERVE" -l 8082 -s "$REPO_DIR/feriwala_customer/build/web"  > /tmp/customer.log 2>&1 &
echo "Customer PID: $!"
nohup "$SERVE" -l 8083 -s "$REPO_DIR/feriwala_delivery/build/web"  > /tmp/delivery.log 2>&1 &
echo "Delivery PID: $!"

sleep 3

echo ""
echo "=== STATUS ==="
curl -s -o /dev/null -w "Shop     :8081 → HTTP %{http_code}\n" http://localhost:8081 || true
curl -s -o /dev/null -w "Customer :8082 → HTTP %{http_code}\n" http://localhost:8082 || true
curl -s -o /dev/null -w "Delivery :8083 → HTTP %{http_code}\n" http://localhost:8083 || true

echo ""
echo "Apps running on:"
echo "  Shop     → http://localhost:8081"
echo "  Customer → http://localhost:8082"
echo "  Delivery → http://localhost:8083"
