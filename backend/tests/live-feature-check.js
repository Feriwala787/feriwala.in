const http = require('http');

const baseUrl = process.env.API_BASE_URL || 'http://13.233.227.15:3000/api';

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const url = new URL(baseUrl + path);
    const payload = body ? JSON.stringify(body) : null;
    const options = {
      method,
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers.Authorization = `Bearer ${token}`;
    }
    if (payload) {
      options.headers['Content-Length'] = Buffer.byteLength(payload);
    }

    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => {
        raw += chunk;
      });
      res.on('end', () => {
        let parsed;
        try {
          parsed = raw ? JSON.parse(raw) : {};
        } catch {
          parsed = raw;
        }
        resolve({ status: res.statusCode, body: parsed });
      });
    });

    req.on('error', reject);
    req.setTimeout(15000, () => {
      req.destroy(new Error(`Request timeout for ${method} ${path}`));
    });
    if (payload) {
      req.write(payload);
    }
    req.end();
  });
}

async function main() {
  const stamp = Date.now();
  const user = {
    name: 'Automation User',
    email: `automation+${stamp}@example.com`,
    phone: `9${String(stamp).slice(-9)}`,
    password: 'Test@1234',
    role: 'customer',
  };

  console.log('step: register');
  const register = await request('POST', '/auth/register', user);
  console.log('register:', register.status, JSON.stringify(register.body));

  console.log('step: login');
  const login = await request('POST', '/auth/login', {
    email: user.email,
    password: user.password,
  });
  console.log('login:', login.status, JSON.stringify(login.body));

  const token =
    (register.body && register.body.data && register.body.data.accessToken) ||
    (login.body && login.body.data && login.body.data.accessToken);

  if (!token) {
    throw new Error('No access token from register/login.');
  }

  console.log('step: profile');
  const profile = await request('GET', '/auth/profile', null, token);
  console.log('profile:', profile.status, JSON.stringify(profile.body));

  console.log('step: products');
  const products = await request('GET', '/products?limit=5', null, token);
  console.log('products:', products.status, `count=${Array.isArray(products.body?.data) ? products.body.data.length : 0}`);

  if (!Array.isArray(products.body?.data) || products.body.data.length === 0) {
    console.log('No products available. Skipping order placement.');
    return;
  }

  const product = products.body.data[0];
  const orderPayload = {
    shopId: product.shopId,
    items: [
      {
        productId: product.id,
        quantity: 1,
      },
    ],
    deliveryAddress: {
      label: 'Home',
      addressLine1: 'Test Street',
      city: 'Delhi',
      state: 'Delhi',
      pincode: '110001',
      isDefault: true,
    },
    paymentMethod: 'cod',
    notes: 'live automation feature check',
  };

  console.log('step: place-order');
  const order = await request('POST', '/orders', orderPayload, token);
  console.log('order:', order.status, JSON.stringify(order.body));

  console.log('step: my-orders');
  const myOrders = await request('GET', '/orders/my-orders?limit=5', null, token);
  console.log('my-orders:', myOrders.status, `count=${Array.isArray(myOrders.body?.data) ? myOrders.body.data.length : 0}`);
}

main().catch((err) => {
  console.error('live-feature-check failed:', err.message);
  process.exit(1);
});
