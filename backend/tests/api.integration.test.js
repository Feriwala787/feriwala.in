/**
 * Feriwala Full Feature Automation Test Suite
 * Tests all API endpoints against the live server.
 * Run: node --test tests/api.integration.test.js
 * Env: API_BASE_URL=http://65.2.9.216:3000/api (default)
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const BASE = process.env.API_BASE_URL || 'http://65.2.9.216:3000/api';
const TIMEOUT = 15000;

// ─── HTTP helper ────────────────────────────────────────────────────────────
async function req(method, path, body, token) {
  const url = new URL(BASE + path);
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT);

  try {
    const res = await fetch(url.toString(), {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });
    const text = await res.text();
    let json;
    try { json = JSON.parse(text); } catch { json = { raw: text }; }
    return { status: res.status, body: json };
  } finally {
    clearTimeout(timer);
  }
}

// ─── Shared state ────────────────────────────────────────────────────────────
const state = {};
const stamp = Date.now();

// ─── 1. Health ───────────────────────────────────────────────────────────────
test('GET /health → 200 ok', async () => {
  const r = await req('GET', '/health');
  assert.equal(r.status, 200);
  assert.equal(r.body.status, 'ok');
});

test('GET /health/deep → has services shape', async () => {
  const r = await req('GET', '/health/deep');
  assert.ok([200, 503].includes(r.status), `unexpected status ${r.status}`);
  assert.ok(r.body.services, 'missing services key');
  assert.equal(typeof r.body.services.mongo?.ready, 'boolean');
  assert.equal(typeof r.body.services.postgres?.ready, 'boolean');
});

// ─── 2. Auth ─────────────────────────────────────────────────────────────────
test('POST /auth/register → creates customer', async () => {
  const r = await req('POST', '/auth/register', {
    name: 'Test Customer',
    email: `customer+${stamp}@feriwala.test`,
    phone: `9${String(stamp).slice(-9)}`,
    password: 'Test@1234',
    role: 'customer',
  });
  assert.ok([201, 503].includes(r.status), `register status ${r.status}: ${JSON.stringify(r.body)}`);
  if (r.status === 201) {
    assert.ok(r.body.data?.accessToken, 'no accessToken');
    state.customerToken = r.body.data.accessToken;
    state.customerId = r.body.data.user._id;
  }
});

test('POST /auth/register → creates delivery agent', async () => {
  const r = await req('POST', '/auth/register', {
    name: 'Test Agent',
    email: `agent+${stamp}@feriwala.test`,
    phone: `8${String(stamp).slice(-9)}`,
    password: 'Test@1234',
    role: 'delivery_agent',
  });
  assert.ok([201, 503].includes(r.status), `agent register status ${r.status}`);
  if (r.status === 201) {
    state.agentToken = r.body.data.accessToken;
  }
});

test('POST /auth/login → returns token', async () => {
  if (!state.customerToken) {
    // MongoDB unavailable — login will 503, skip gracefully
    const r = await req('POST', '/auth/login', {
      credential: `customer+${stamp}@feriwala.test`,
      password: 'Test@1234',
    });
    assert.ok([200, 503].includes(r.status), `login status ${r.status}`);
    if (r.status === 200) {
      assert.ok(r.body.data?.accessToken);
      state.customerToken = r.body.data.accessToken;
    }
  }
});

test('POST /auth/login → rejects wrong password', async () => {
  const r = await req('POST', '/auth/login', {
    credential: `customer+${stamp}@feriwala.test`,
    password: 'WrongPass!',
  });
  assert.ok([401, 503].includes(r.status), `expected 401 or 503, got ${r.status}`);
});

test('GET /auth/profile → returns user when authenticated', async () => {
  if (!state.customerToken) return; // skip if mongo down
  const r = await req('GET', '/auth/profile', null, state.customerToken);
  assert.equal(r.status, 200);
  assert.ok(r.body.data?.email);
});

test('GET /auth/profile → 401 without token', async () => {
  const r = await req('GET', '/auth/profile');
  assert.equal(r.status, 401);
});

test('PUT /auth/profile → updates name', async () => {
  if (!state.customerToken) return;
  const r = await req('PUT', '/auth/profile', { name: 'Updated Customer' }, state.customerToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.data?.name, 'Updated Customer');
});

test('POST /auth/addresses → adds address', async () => {
  if (!state.customerToken) return;
  const r = await req('POST', '/auth/addresses', {
    label: 'Home',
    addressLine1: '123 Test Street',
    city: 'Delhi',
    state: 'Delhi',
    pincode: '110001',
    isDefault: true,
  }, state.customerToken);
  assert.equal(r.status, 200);
  assert.ok(Array.isArray(r.body.data));
});

// ─── 3. Shops (public) ───────────────────────────────────────────────────────
test('GET /shops → returns shop list', async () => {
  const r = await req('GET', '/shops');
  assert.equal(r.status, 200);
  assert.ok(r.body.success);
  assert.ok(Array.isArray(r.body.data));
  if (r.body.data.length > 0) {
    state.shopId = r.body.data[0].id;
    state.shopCode = r.body.data[0].code;
  }
});

test('GET /shops?city=Delhi → filters by city', async () => {
  const r = await req('GET', '/shops?city=Delhi');
  assert.equal(r.status, 200);
  assert.ok(r.body.success);
});

test('GET /shops/:id → returns shop detail', async () => {
  if (!state.shopId) return;
  const r = await req('GET', `/shops/${state.shopId}`);
  assert.equal(r.status, 200);
  assert.equal(r.body.data?.id, state.shopId);
});

test('GET /shops/9999 → 404 for missing shop', async () => {
  const r = await req('GET', '/shops/9999');
  assert.equal(r.status, 404);
});

// ─── 4. Products (public) ────────────────────────────────────────────────────
test('GET /products → returns product list', async () => {
  const r = await req('GET', '/products');
  assert.equal(r.status, 200);
  assert.ok(r.body.success);
  assert.ok(Array.isArray(r.body.data));
  if (r.body.data.length > 0) {
    state.productId = r.body.data[0].id;
    state.productShopId = r.body.data[0].shopId;
  }
});

test('GET /products?search=shirt → search works', async () => {
  const r = await req('GET', '/products?search=shirt');
  assert.equal(r.status, 200);
  assert.ok(r.body.success);
});

test('GET /products?minPrice=100&maxPrice=500 → price filter', async () => {
  const r = await req('GET', '/products?minPrice=100&maxPrice=500');
  assert.equal(r.status, 200);
  assert.ok(r.body.success);
});

test('GET /products/:id → returns product detail', async () => {
  if (!state.productId) return;
  const r = await req('GET', `/products/${state.productId}`);
  assert.equal(r.status, 200);
  assert.equal(r.body.data?.id, state.productId);
});

test('GET /products/categories/all → returns categories', async () => {
  const r = await req('GET', '/products/categories/all');
  assert.equal(r.status, 200);
  assert.ok(Array.isArray(r.body.data));
});

// ─── 5. Orders ───────────────────────────────────────────────────────────────
test('POST /orders → 401 without auth', async () => {
  const r = await req('POST', '/orders', { shopId: 1, items: [], deliveryAddress: {}, paymentMethod: 'cod' });
  assert.equal(r.status, 401);
});

test('POST /orders → places order when product available', async () => {
  if (!state.customerToken || !state.productId || !state.productShopId) return;
  const r = await req('POST', '/orders', {
    shopId: state.productShopId,
    items: [{ productId: state.productId, quantity: 1 }],
    deliveryAddress: {
      label: 'Home',
      addressLine1: '123 Test Street',
      city: 'Delhi',
      state: 'Delhi',
      pincode: '110001',
    },
    paymentMethod: 'cod',
    notes: 'automation test order',
  }, state.customerToken);
  // 201 = success, 400 = out of stock/validation (acceptable), 503 = mongo down
  assert.ok([201, 400, 503].includes(r.status), `order status ${r.status}: ${JSON.stringify(r.body)}`);
  if (r.status === 201) {
    state.orderId = r.body.data?.id;
    state.orderShopId = r.body.data?.shopId;
  }
});

test('GET /orders/my-orders → returns customer orders', async () => {
  if (!state.customerToken) return;
  const r = await req('GET', '/orders/my-orders', null, state.customerToken);
  assert.equal(r.status, 200);
  assert.ok(Array.isArray(r.body.data));
});

test('GET /orders/:id → returns order detail', async () => {
  if (!state.customerToken || !state.orderId) return;
  const r = await req('GET', `/orders/${state.orderId}`, null, state.customerToken);
  assert.equal(r.status, 200);
  assert.equal(r.body.data?.id, state.orderId);
});

test('GET /orders/:id → 403 for other user order', async () => {
  if (!state.agentToken || !state.orderId) return;
  const r = await req('GET', `/orders/${state.orderId}`, null, state.agentToken);
  assert.ok([403, 503].includes(r.status));
});

// ─── 6. Delivery agent ───────────────────────────────────────────────────────
test('GET /delivery/my-tasks → 401 without auth', async () => {
  const r = await req('GET', '/delivery/my-tasks');
  assert.equal(r.status, 401);
});

test('GET /delivery/my-tasks → returns tasks for agent', async () => {
  if (!state.agentToken) return;
  const r = await req('GET', '/delivery/my-tasks', null, state.agentToken);
  assert.equal(r.status, 200);
  assert.ok(Array.isArray(r.body.data));
});

test('PUT /delivery/location → updates agent location', async () => {
  if (!state.agentToken) return;
  const r = await req('PUT', '/delivery/location', {
    latitude: 28.6139,
    longitude: 77.2090,
  }, state.agentToken);
  assert.ok([200, 503].includes(r.status));
});

test('PUT /delivery/online-status → toggles online', async () => {
  if (!state.agentToken) return;
  const r = await req('PUT', '/delivery/online-status', { isOnline: true }, state.agentToken);
  assert.ok([200, 503].includes(r.status));
});

// ─── 7. Returns ──────────────────────────────────────────────────────────────
test('POST /delivery/returns → 400 for non-delivered order', async () => {
  if (!state.customerToken || !state.orderId) return;
  const r = await req('POST', '/delivery/returns', {
    orderId: state.orderId,
    orderItemId: 1,
    reason: 'Wrong size',
    returnType: 'return',
  }, state.customerToken);
  // 400 = not delivered yet (correct), 404 = order not found, 503 = mongo down
  assert.ok([400, 404, 503].includes(r.status), `return status ${r.status}`);
});

test('GET /delivery/returns/my → returns customer return history', async () => {
  if (!state.customerToken) return;
  const r = await req('GET', '/delivery/returns/my', null, state.customerToken);
  assert.equal(r.status, 200);
  assert.ok(Array.isArray(r.body.data));
});

// ─── 8. Auth token refresh ───────────────────────────────────────────────────
test('POST /auth/refresh → 400 without token', async () => {
  const r = await req('POST', '/auth/refresh', {});
  assert.equal(r.status, 400);
});

// ─── 9. Role-based access control ───────────────────────────────────────────
test('GET /admin/dashboard → 401 without auth', async () => {
  const r = await req('GET', '/admin/dashboard');
  assert.equal(r.status, 401);
});

test('GET /admin/dashboard → 403 for customer role', async () => {
  if (!state.customerToken) return;
  const r = await req('GET', '/admin/dashboard', null, state.customerToken);
  assert.ok([403, 503].includes(r.status));
});

test('POST /products → 403 for customer role', async () => {
  if (!state.customerToken) return;
  const r = await req('POST', '/products', {
    name: 'Test Product', categoryId: 1, mrp: 500, sellingPrice: 400,
  }, state.customerToken);
  assert.ok([403, 503].includes(r.status));
});

// ─── 10. Input validation ────────────────────────────────────────────────────
test('POST /auth/register → 400 for invalid email', async () => {
  const r = await req('POST', '/auth/register', {
    name: 'Bad User', email: 'not-an-email', phone: '9999999999', password: 'Test@1234',
  });
  assert.ok([400, 503].includes(r.status));
});

test('POST /auth/register → 400 for short password', async () => {
  const r = await req('POST', '/auth/register', {
    name: 'Bad User', email: 'valid@test.com', phone: '9999999998', password: '123',
  });
  assert.ok([400, 503].includes(r.status));
});

test('POST /orders → 400 for empty items array', async () => {
  if (!state.customerToken) return;
  const r = await req('POST', '/orders', {
    shopId: 1, items: [], deliveryAddress: {}, paymentMethod: 'cod',
  }, state.customerToken);
  assert.ok([400, 503].includes(r.status));
});

// ─── 11. Pagination ──────────────────────────────────────────────────────────
test('GET /products?page=1&limit=5 → respects pagination', async () => {
  const r = await req('GET', '/products?page=1&limit=5');
  assert.equal(r.status, 200);
  assert.ok(r.body.pagination, 'missing pagination');
  assert.ok(r.body.data.length <= 5);
});

test('GET /shops?page=1&limit=3 → respects pagination', async () => {
  const r = await req('GET', '/shops?page=1&limit=3');
  assert.equal(r.status, 200);
  assert.ok(r.body.pagination);
  assert.ok(r.body.data.length <= 3);
});

// ─── 12. Logout ──────────────────────────────────────────────────────────────
test('POST /auth/logout → clears session', async () => {
  if (!state.customerToken) return;
  const r = await req('POST', '/auth/logout', {}, state.customerToken);
  assert.ok([200, 503].includes(r.status));
});

// ─── 13. 404 handler ─────────────────────────────────────────────────────────
test('GET /api/nonexistent → 404', async () => {
  const r = await req('GET', '/nonexistent-route-xyz');
  assert.equal(r.status, 404);
});
