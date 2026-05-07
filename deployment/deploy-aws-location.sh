#!/bin/bash

# Production Deployment Script for AWS Location Service Integration
# Run this on the production server (65.2.9.216)

set -e

echo "🚀 Starting AWS Location Service deployment..."

# Navigate to project directory
cd /home/bitnami/feriwala.in

# Pull latest code
echo "📥 Pulling latest code from GitHub..."
git pull origin main

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend
npm install

# Verify new files exist
echo "✅ Verifying new files..."
if [ ! -f "src/services/awsLocationService.js" ]; then
    echo "❌ Error: awsLocationService.js not found"
    exit 1
fi

if [ ! -f "src/routes/location.js" ]; then
    echo "❌ Error: location.js not found"
    exit 1
fi

if [ ! -f "scripts/setup-aws-location.js" ]; then
    echo "❌ Error: setup-aws-location.js not found"
    exit 1
fi

# Check if AWS SDK is installed
echo "🔍 Checking AWS SDK installation..."
if npm list @aws-sdk/client-location > /dev/null 2>&1; then
    echo "✅ AWS Location SDK installed"
else
    echo "❌ AWS Location SDK not found"
    exit 1
fi

# Validate code syntax
echo "🔍 Validating code syntax..."
node --check src/services/awsLocationService.js
node --check src/routes/location.js
node --check src/server.js

# Restart backend
echo "🔄 Restarting backend..."
pm2 restart feriwala-backend

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 5

# Check health
echo "🏥 Checking server health..."
curl -f http://localhost:3000/api/health || {
    echo "❌ Health check failed"
    pm2 logs feriwala-backend --lines 50
    exit 1
}

echo ""
echo "✅ Deployment successful!"
echo ""
echo "📋 Next steps:"
echo "1. Configure AWS credentials in .env:"
echo "   AWS_REGION=ap-south-1"
echo "   AWS_ACCESS_KEY_ID=your_key"
echo "   AWS_SECRET_ACCESS_KEY=your_secret"
echo ""
echo "2. Create AWS Location Service resources:"
echo "   node scripts/setup-aws-location.js"
echo ""
echo "3. Create shop geofences:"
echo "   curl -X POST https://api.feriwala.in/api/location/geofence/batch-create \\"
echo "     -H 'Authorization: Bearer ADMIN_TOKEN'"
echo ""
echo "4. Test serviceability:"
echo "   curl -X POST https://api.feriwala.in/api/location/serviceability \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"latitude\":19.0760,\"longitude\":72.8777,\"shopId\":1}'"
echo ""
echo "🎉 AWS Location Service integration deployed!"
