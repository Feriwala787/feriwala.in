const http = require('http');

function testSignup() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      email: `test-${Date.now()}@feriwala.test`,
      password: 'TestPass123!',
      name: 'Test User',
      phone: '9876543210',
      role: 'customer'
    });

    const options = {
      hostname: '13.233.227.15',
      port: 80,
      path: '/api/auth/register',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      },
      timeout: 5000
    };

    console.log('📝 Attempting signup...');
    console.log(`   Target: ${options.hostname}:${options.port}${options.path}`);
    const req = http.request(options, (res) => {
      console.log(`   Response Status: ${res.statusCode}`);
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        console.log(`   Response Body: ${body}\n`);
        resolve({ status: res.statusCode, body });
      });
    });

    req.on('error', (err) => {
      console.log(`   ✗ Error: ${err.message}\n`);
      reject(err);
    });

    req.on('timeout', () => {
      req.destroy();
      console.log(`   ✗ Error: Request timeout\n`);
      reject(new Error('Request timeout'));
    });

    req.write(data);
    req.end();
  });
}

function testHealth() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '13.233.227.15',
      port: 80,
      path: '/api/health',
      method: 'GET',
      timeout: 5000
    };

    console.log('🏥 Testing health endpoint...');
    console.log(`   Target: ${options.hostname}:${options.port}${options.path}`);
    const req = http.request(options, (res) => {
      console.log(`   Response Status: ${res.statusCode}`);
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        console.log(`   Response Body: ${body}\n`);
        resolve({ status: res.statusCode, body });
      });
    });

    req.on('error', (err) => {
      console.log(`   ✗ Error: ${err.message}\n`);
      reject(err);
    });

    req.on('timeout', () => {
      req.destroy();
      console.log(`   ✗ Error: Request timeout\n`);
      reject(new Error('Request timeout'));
    });

    req.end();
  });
}

async function run() {
  console.log('🧪 Feriwala API Diagnostic Tests\n');
  console.log('═'.repeat(50) + '\n');

  // Test 1: Health check
  try {
    await testHealth();
  } catch (err) {
    console.log(`Backend health check failed: ${err.message}`);
  }

  // Test 2: Signup
  try {
    await testSignup();
  } catch (err) {
    console.log(`Signup test failed: ${err.message}`);
  }

  console.log('═'.repeat(50));
  console.log('\n✅ Diagnostic tests complete\n');
  process.exit(0);
}

run();
