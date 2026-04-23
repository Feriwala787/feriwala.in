#!/bin/bash
set -e
FLUTTER=/home/user/flutter/bin/flutter

echo "=== Building Shop (release web) ==="
cd /home/user/dd/feriwala_shop
$FLUTTER build web --release 2>&1 | tail -3

echo "=== Building Customer (release web) ==="
cd /home/user/dd/feriwala_customer
$FLUTTER build web --release 2>&1 | tail -3

echo "=== Building Delivery (release web) ==="
cd /home/user/dd/feriwala_delivery
$FLUTTER build web --release 2>&1 | tail -3

echo ""
echo "=== Killing old servers ==="
kill -9 $(lsof -ti tcp:8081,8082,8083 2>/dev/null) 2>/dev/null || true
sleep 1

echo "=== Starting static servers ==="
cd /home/user/dd/feriwala_shop/build/web
nohup npx --yes serve -l 8081 -s . > /tmp/shop.log 2>&1 &
echo "Shop PID: $!"

cd /home/user/dd/feriwala_customer/build/web
nohup npx --yes serve -l 8082 -s . > /tmp/customer.log 2>&1 &
echo "Customer PID: $!"

cd /home/user/dd/feriwala_delivery/build/web
nohup npx --yes serve -l 8083 -s . > /tmp/delivery.log 2>&1 &
echo "Delivery PID: $!"

sleep 5

echo ""
echo "=== STATUS ==="
curl -s -o /dev/null -w "Shop     :8081 → HTTP %{http_code}\n" http://localhost:8081
curl -s -o /dev/null -w "Customer :8082 → HTTP %{http_code}\n" http://localhost:8082
curl -s -o /dev/null -w "Delivery :8083 → HTTP %{http_code}\n" http://localhost:8083

echo ""
echo "=== OPEN THESE URLS ==="
echo "Shop     → https://8081-firebase-dd-1776795244268.cluster-73qgvk7hjjadkrjeyexca5ivva.cloudworkstations.dev"
echo "Customer → https://8082-firebase-dd-1776795244268.cluster-73qgvk7hjjadkrjeyexca5ivva.cloudworkstations.dev"
echo "Delivery → https://8083-firebase-dd-1776795244268.cluster-73qgvk7hjjadkrjeyexca5ivva.cloudworkstations.dev"
