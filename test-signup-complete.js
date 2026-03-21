const http = require('http');

async function testSignup() {
  const signupData = {
    email: 'testuser@example.com',
    password: 'Pass123!@',
    name: 'Test User',
    phone: '+1234567890'  // Required field
  };

  return new Promise((resolve) => {
    const options = {
      hostname: '13.233.227.15',
      port: 80,
      path: '/api/auth/register',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Connection': 'close'
      },
      timeout: 10000
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', chunk => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          body: responseData,
          headers: res.headers
        });
      });
    });

    req.on('error', (err) => {
      resolve({
        status: 'ERROR',
        error: err.message
      });
    });

    req.write(JSON.stringify(signupData));
    req.end();
  });
}

async function runTest() {
  console.log('🧪 Testing Complete Signup with All Required Fields\n');
  
  const result = await testSignup();
  
  console.log(`Status: ${result.status}`);
  console.log(`Response:\n${JSON.stringify(JSON.parse(result.body), null, 2)}`);
  
  if (result.status === 201 || (result.status === 200 && JSON.parse(result.body).success)) {
    console.log('\n✅ SUCCESS! User signup working!');
  }
}

runTest().catch(console.error);
