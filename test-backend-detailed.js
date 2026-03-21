const http = require('http');

const host = '13.233.227.15';
const port = 80;

async function testEndpoint(path, method = 'GET', data = null) {
  return new Promise((resolve) => {
    const startTime = Date.now();
    
    const options = {
      hostname: host,
      port: port,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Connection': 'close'
      },
      timeout: 5000
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', chunk => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        const duration = Date.now() - startTime;
        resolve({
          path,
          status: res.statusCode,
          headers: res.headers,
          body: responseData,
          duration: `${duration}ms`
        });
      });
    });

    req.on('timeout', () => {
      req.destroy();
      const duration = Date.now() - startTime;
      resolve({
        path,
        status: 'TIMEOUT',
        error: 'Request timed out after 5 seconds',
        duration: `${duration}ms`
      });
    });

    req.on('error', (err) => {
      const duration = Date.now() - startTime;
      resolve({
        path,
        status: 'ERROR',
        error: err.message,
        duration: `${duration}ms`
      });
    });

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

async function runTests() {
  console.log('🔍 Backend Detailed Diagnostic Test\n');
  
  // Test 1: Health check
  console.log('Test 1: Health Check (/api/health)');
  const health = await testEndpoint('/api/health');
  console.log(`  Status: ${health.status}`);
  console.log(`  Duration: ${health.duration}`);
  if (health.body) console.log(`  Body: ${health.body}`);
  if (health.error) console.log(`  Error: ${health.error}`);
  console.log();

  // Test 2: Products endpoint (should be fast if DB is connected)
  console.log('Test 2: Products List (/api/products) - (should be fast)');
  const products = await testEndpoint('/api/products');
  console.log(`  Status: ${products.status}`);
  console.log(`  Duration: ${products.duration}`);
  if (products.body) console.log(`  Body: ${products.body.substring(0, 100)}...`);
  if (products.error) console.log(`  Error: ${products.error}`);
  console.log();

  // Test 3: Signup (will timeout if DB not connected)
  console.log('Test 3: Signup (/api/auth/register) - timing out means DB not connected');
  const signup = await testEndpoint('/api/auth/register', 'POST', {
    email: 'test@example.com',
    password: 'Pass123!',
    name: 'Test User'
  });
  console.log(`  Status: ${signup.status}`);
  console.log(`  Duration: ${signup.duration}`);
  if (signup.body) console.log(`  Body: ${signup.body}`);
  if (signup.error) console.log(`  Error: ${signup.error}`);
  console.log();

  // Summary
  console.log('📊 Summary:');
  console.log(`  Health: ${health.status === 200 ? '✅ OK' : '❌ FAILED'}`);
  console.log(`  Products: ${products.status === 200 ? '✅ OK' : products.status === 'TIMEOUT' ? '⏱️ TIMEOUT' : '❌ FAILED'}`);
  console.log(`  Signup: ${signup.status === 201 ? '✅ OK' : signup.status === 'TIMEOUT' ? '⏱️ TIMEOUT (MongoDB not connected)' : '❌ FAILED'}`);
  
  if (signup.status === 'TIMEOUT') {
    console.log('\n⚠️  Signup endpoint is timing out, which typically means:');
    console.log('   - MongoDB is not yet accepting connections from this IP');
    console.log('   - The whitelist propagation is still in progress (5-10 minutes typically)');
    console.log('   - Backend process is waiting for DB connection before handling requests');
  }
}

runTests().catch(console.error);
