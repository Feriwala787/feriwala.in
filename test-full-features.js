const http = require('http');

async function testFeature(path, method = 'GET', data = null, timeout = 5000, token = null) {
  return new Promise((resolve) => {
    const headers = {
      'Content-Type': 'application/json',
      'Connection': 'close'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const options = {
      hostname: '13.233.227.15',
      port: 80,
      path: path,
      method: method,
      headers,
      timeout: timeout
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      res.on('data', chunk => responseData += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseData);
          resolve({
            status: res.statusCode,
            success: parsed.success !== false,
            data: parsed,
            error: null
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            success: res.statusCode >= 200 && res.statusCode < 300,
            data: responseData,
            error: e.message
          });
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({ status: 'TIMEOUT', success: false, error: 'Request timeout' });
    });

    req.on('error', (err) => {
      resolve({ status: 'ERROR', success: false, error: err.message });
    });

    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function runTests() {
  console.log('🧪 Feriwala Platform Feature Test Suite\n');
  const runId = Date.now();

  // Test 1: Health
  console.log('1. Health Check...');
  const health = await testFeature('/api/health');
  console.log(`   ${health.status === 200 ? '✅' : '❌'} Status: ${health.status}\n`);

  // Test 2: Products (no auth needed)
  console.log('2. Product Listing (no auth)...');
  const products = await testFeature('/api/products');
  console.log(`   ${products.success ? '✅' : '❌'} Status: ${products.status}`);
  if (products.data.data) {
    console.log(`   Found ${products.data.data.length} products\n`);
  }

  // Test 3: Signup
  console.log('3. User Signup...');
  const email = `test${runId}@example.com`;
  const phone = `+91${String(runId).slice(-10)}`;
  const signup = await testFeature('/api/auth/register', 'POST', {
    email: email,
    password: 'TestPass123!@',
    name: 'Test User',
    phone: phone
  });
  
  let authToken = null;
  let loginId = null;
  if (signup.success) {
    console.log(`   ✅ Signup successful`);
    if (signup.data.data && signup.data.data.user && signup.data.data.user.loginId) {
      loginId = signup.data.data.user.loginId;
      console.log(`   📝 Login ID: ${loginId}`);
    }
    if (signup.data.accessToken || signup.data.token) {
      authToken = signup.data.accessToken || signup.data.token;
      console.log(`   🔑 Auth token received\n`);
    } else if (signup.data.data && (signup.data.data.accessToken || signup.data.data.token)) {
      authToken = signup.data.data.accessToken || signup.data.data.token;
      console.log(`   🔑 Auth token received\n`);
    }
  } else {
    console.log(`   ❌ Signup failed: ${signup.status}`);
    console.log(`   Error: ${JSON.stringify(signup.data || signup.error || 'unknown').substring(0, 160)}\n`);
  }

  // Test 4: Login with email
  console.log('4. User Login (with email)...');
  const login = await testFeature('/api/auth/login', 'POST', {
    credential: email,
    password: 'TestPass123!@'
  });
  
  if (login.success) {
    console.log(`   ✅ Login successful (email)`);
    if (!authToken && (login.data.accessToken || login.data.token || (login.data.data && (login.data.data.accessToken || login.data.data.token)))) {
      authToken = login.data.accessToken || login.data.token || login.data.data.accessToken || login.data.data.token;
      console.log(`   🔑 Auth token received\n`);
    }
  } else {
    console.log(`   ❌ Login failed: ${login.status}\n`);
  }

  // Test 4b: Login with loginId (if available)
  let loginWithId = { success: false };
  if (loginId) {
    console.log('4b. User Login (with Login ID)...');
    loginWithId = await testFeature('/api/auth/login', 'POST', {
      credential: loginId,
      password: 'TestPass123!@'
    });
    
    if (loginWithId.success) {
      console.log(`   ✅ Login successful (login ID: ${loginId})\n`);
    } else {
      console.log(`   ❌ Login failed with login ID: ${loginWithId.status}\n`);
    }
  }

  // Test 5: Orders (requires auth)
  let orderResult = { success: false, status: 'SKIPPED' };
  if (authToken) {
    console.log('5. Order Creation (with auth)...');
    orderResult = await testFeature('/api/orders', 'POST', {
      shopId: 1,
      items: [{ productId: 1, quantity: 1 }],
      deliveryAddress: {
        line1: 'Test Address',
        city: 'Delhi',
        state: 'Delhi',
        zip: '110001'
      },
      paymentMethod: 'cod'
    }, 5000, authToken);
    console.log(`   ${orderResult.success ? '✅' : '❌'} Status: ${orderResult.status}`);
    if (!orderResult.success) {
      console.log(`   Error: ${JSON.stringify(orderResult.data || orderResult.error || 'unknown').substring(0, 160)}`);
    }
    console.log();
  }

  // Summary
  console.log('📊 TEST SUMMARY:');
  console.log(`   Health: ${health.status === 200 ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Products: ${products.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Signup: ${signup.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Login (email): ${login.success ? '✅ PASS' : '❌ FAIL'}`);
  if (loginId) {
    console.log(`   Login (ID): ${loginWithId.success ? '✅ PASS' : '❌ FAIL'}`);
  }
  console.log(`   Orders: ${orderResult.status === 'SKIPPED' ? '⚪ SKIPPED' : orderResult.success ? '✅ PASS' : '❌ FAIL'}`);

  const allPass = health.status === 200 && products.success && signup.success && login.success && orderResult.success;
  if (allPass) {
    console.log('\n🎉 All critical tests passed! Platform is working!');
  } else {
    console.log('\n⚠️  Some tests failed. Check details above.');
  }
}

runTests().catch(console.error);
