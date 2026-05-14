require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');

const { connectMongoDB, isMongoReady } = require('./database/mongodb');
const { sequelize, connectPostgres, syncModels } = require('./database/postgres');
const socketHandler = require('./sockets/socketHandler');

// Route imports
const authRoutes = require('./routes/auth');
const shopRoutes = require('./routes/shops');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const deliveryRoutes = require('./routes/delivery');
const promoRoutes = require('./routes/promos');
const adminRoutes = require('./routes/admin');
const customerRoutes = require('./routes/customers');
const aiRoutes = require('./routes/ai');
const locationRoutes = require('./routes/location');

// ─── DB status (declared before any route handler references it) ──────────────
const dbStatus = {
  mongo: { connected: false, lastError: null, lastSuccessAt: null, attempts: 0 },
  postgres: { connected: false, lastError: null, lastSuccessAt: null, attempts: 0 },
};

const PORT = process.env.PORT || 3000;
const DB_RETRY_INTERVAL_MS = parseInt(process.env.DB_RETRY_INTERVAL_MS || '30000', 10);
const HEALTHCHECK_TIMEOUT_MS = parseInt(process.env.HEALTHCHECK_TIMEOUT_MS || '2000', 10);

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function withTimeout(promise, timeoutMs, timeoutMessage) {
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
  });
  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId);
  }
}

async function probePostgres() {
  await withTimeout(
    sequelize.authenticate(),
    HEALTHCHECK_TIMEOUT_MS,
    `PostgreSQL probe timed out after ${HEALTHCHECK_TIMEOUT_MS}ms`
  );
}

// ─── CORS config from environment ────────────────────────────────────────────
const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

// Fall back to wildcard only when no origins are configured (local dev without .env)
const corsOptions = allowedOrigins.length > 0
  ? {
      origin: (origin, callback) => {
        // Allow requests with no origin (mobile apps, curl, server-to-server)
        if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
        callback(new Error(`CORS: origin ${origin} not allowed`));
      },
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }
  : {
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    };

const socketCorsOrigins = (process.env.SOCKET_CORS_ORIGIN || '')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: socketCorsOrigins.length > 0
    ? { origin: socketCorsOrigins, methods: ['GET', 'POST'] }
    : { origin: '*' },
});

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors(corsOptions));
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// ─── Rate limiting ────────────────────────────────────────────────────────────
const RATE_LIMIT_DISABLED = process.env.DISABLE_RATE_LIMIT === 'true';

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => RATE_LIMIT_DISABLED,
});

// Tighter limiter for auth endpoints to prevent brute-force
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: parseInt(process.env.AUTH_RATE_LIMIT_MAX || '20', 10),
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' },
  skip: () => RATE_LIMIT_DISABLED,
});

app.use('/api/', generalLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/auth/refresh', authLimiter);

// Make io accessible to routes
app.set('io', io);

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/shops', shopRoutes);
app.use('/api/products', productRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/delivery', deliveryRoutes);
app.use('/api/promos', promoRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/location', locationRoutes);

// One-time admin seed (protected by secret key)
app.post('/api/seed-admin', async (req, res) => {
  try {
    if (req.body.secret !== (process.env.SEED_SECRET || 'feriwala-seed-2025')) {
      return res.status(403).json({ success: false, message: 'Invalid secret' });
    }
    const User = require('./models/mongo/User');
    const email = 'masa00483429@gmail.com';
    const existing = await User.findOne({ email });
    if (existing) {
      existing.role = 'admin';
      existing.isActive = true;
      existing.isVerified = true;
      existing.passwordHash = 'Ssb9119@$%'; // triggers pre-save bcrypt hash
      await existing.save();
      return res.json({ success: true, message: 'Admin role and password updated' });
    }
    await User.create({
      name: 'Feriwala Admin',
      loginId: 'feriwala_admin',
      email,
      phone: '9000000001',
      passwordHash: 'Ssb9119@$%',
      role: 'admin',
      isVerified: true,
      isActive: true,
    });
    res.json({ success: true, message: 'Admin seeded successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// ─── Legal pages (required for Play Store / App Store) ────────────────────────
app.get('/privacy', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Privacy Policy - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}</style></head><body>
<h1>Privacy Policy</h1><p><em>Last updated: May 2025</em></p>
<h2>1. Information We Collect</h2><p>We collect: name, email, phone number, delivery addresses, order history, and device location (foreground only, to find nearby stores).</p>
<h2>2. How We Use Your Information</h2><p>To process orders, send delivery updates, show nearby stores, and improve our service. We do <strong>not</strong> sell your data.</p>
<h2>3. Location Data</h2><p>Location is accessed only while the app is open (foreground). We do not track location in the background.</p>
<h2>4. Data Storage &amp; Security</h2><p>Data is stored on AWS servers in Mumbai (ap-south-1). All transmission uses HTTPS. Passwords are hashed.</p>
<h2>5. Data Sharing</h2><p>We share your name and address with delivery partners only to fulfil your order. No data is shared with advertisers.</p>
<h2>6. Your Rights</h2><p>You may request data access, correction, or deletion by emailing <a href="mailto:privacy@feriwala.in">privacy@feriwala.in</a>.</p>
<h2>7. Children</h2><p>Feriwala is not directed at children under 13.</p>
<h2>8. Contact</h2><p>Email: <a href="mailto:privacy@feriwala.in">privacy@feriwala.in</a></p>
</body></html>`);
});

app.get('/terms', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Terms &amp; Conditions - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}</style></head><body>
<h1>Terms &amp; Conditions</h1><p><em>Last updated: May 2025</em></p>
<h2>1. Acceptance</h2><p>By downloading, installing, or using the Feriwala mobile application, you agree to be bound by these Terms &amp; Conditions. If you do not agree, please uninstall the app.</p>
<h2>2. Service Description</h2><p>Feriwala is a quick-commerce marketplace that connects customers with local clothing and footwear retailers for rapid delivery. Feriwala acts as an intermediary platform and does not own or stock inventory.</p>
<h2>3. Eligibility</h2><p>You must be at least 18 years old to use Feriwala. By using the app, you represent that you meet this requirement.</p>
<h2>4. Account</h2><p>You are responsible for maintaining the confidentiality of your account credentials. One account per individual. We reserve the right to suspend accounts involved in fraudulent activity.</p>
<h2>5. Orders &amp; Pricing</h2><p>All orders are subject to product availability and serviceability. Prices displayed include applicable taxes unless stated otherwise. We reserve the right to cancel orders due to stock unavailability, pricing errors, or suspected fraud.</p>
<h2>6. Payments</h2><p>We support Cash on Delivery (COD) and online payments (UPI, cards, net banking) via Razorpay. Online payments are processed securely through Razorpay's PCI-DSS compliant infrastructure. Feriwala does not store your card or bank details.</p>
<h2>7. Delivery</h2><p>Estimated delivery times are indicative and may vary due to traffic, weather, or operational constraints. You must be available at the delivery address to receive the order. Delivery is limited to serviceable pin codes.</p>
<h2>8. Cancellation</h2><p>Orders can be cancelled before the shop starts preparing them at no charge. A cancellation fee of ₹20 applies if cancelled after preparation begins. See our <a href="/refund">Refund &amp; Cancellation Policy</a> for details.</p>
<h2>9. Returns &amp; Refunds</h2><p>Returns are accepted within 24 hours of delivery for damaged, defective, or wrong items only. Items must be unused with original tags. Refunds are processed within 5-7 business days. See our <a href="/refund">Refund &amp; Cancellation Policy</a>.</p>
<h2>10. Intellectual Property</h2><p>All content, logos, and trademarks on Feriwala are owned by Feriwala. Reproduction or distribution without written permission is prohibited.</p>
<h2>11. Limitation of Liability</h2><p>Feriwala is not liable for delays caused by force majeure events. Our maximum liability is limited to the order value paid by the customer.</p>
<h2>12. Governing Law &amp; Jurisdiction</h2><p>These terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of courts in India.</p>
<h2>13. Changes</h2><p>We may update these terms. Continued use of the app after changes constitutes acceptance.</p>
<h2>14. Contact</h2><p>Email: <a href="mailto:support@feriwala.in">support@feriwala.in</a></p>
</body></html>`);
});

app.get('/refund', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Refund &amp; Cancellation Policy - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}table{border-collapse:collapse;width:100%;margin:12px 0}th,td{border:1px solid #ddd;padding:10px;text-align:left}th{background:#f9f9f9}</style></head><body>
<h1>Refund &amp; Cancellation Policy</h1><p><em>Last updated: May 2025</em></p>
<h2>1. Cancellation by Customer</h2>
<table><tr><th>When</th><th>Charge</th></tr>
<tr><td>Before shop starts preparing</td><td>No charge — full refund</td></tr>
<tr><td>After preparation starts</td><td>₹20 cancellation fee</td></tr>
<tr><td>After dispatch</td><td>Cannot be cancelled (return after delivery)</td></tr></table>
<h2>2. Cancellation by Feriwala</h2><p>We may cancel orders due to stock unavailability, serviceability issues, or suspected fraud. In such cases, a full refund is issued with no charges.</p>
<h2>3. Returns</h2><p>Returns are accepted within <strong>24 hours</strong> of delivery under the following conditions:</p><ul><li>Item is damaged or defective</li><li>Wrong item delivered</li><li>Size mismatch from what was ordered</li></ul><p>Items must be unused, unwashed, and with original tags intact. The delivery partner will verify the item condition during pickup.</p>
<h2>4. Non-Returnable Items</h2><ul><li>Innerwear and undergarments</li><li>Items without original tags</li><li>Items showing signs of use or washing</li></ul>
<h2>5. Refund Timelines</h2>
<table><tr><th>Payment Method</th><th>Refund Timeline</th></tr>
<tr><td>Online (UPI/Card/Net Banking)</td><td>5-7 business days to original payment method</td></tr>
<tr><td>Cash on Delivery</td><td>Credited as store wallet balance within 24 hours, or bank transfer in 5-7 business days on request</td></tr></table>
<h2>6. How to Request</h2><p>Open the order in the app → Tap "Return/Refund" → Select reason → Our delivery partner will pick up the item.</p>
<h2>7. Contact</h2><p>For refund queries: <a href="mailto:support@feriwala.in">support@feriwala.in</a></p>
</body></html>`);
});

app.get('/contact', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Contact Us - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}</style></head><body>
<h1>Contact Us</h1>
<h2>Customer Support</h2><p>Email: <a href="mailto:support@feriwala.in">support@feriwala.in</a></p><p>Hours: Monday to Saturday, 9:00 AM – 8:00 PM IST</p>
<h2>Business Enquiries</h2><p>Email: <a href="mailto:business@feriwala.in">business@feriwala.in</a></p>
<h2>Privacy &amp; Data Requests</h2><p>Email: <a href="mailto:privacy@feriwala.in">privacy@feriwala.in</a></p>
<h2>Registered Address</h2><p>Feriwala<br>India</p>
<h2>Grievance Officer</h2><p>Name: Feriwala Support Team<br>Email: <a href="mailto:grievance@feriwala.in">grievance@feriwala.in</a><br>Response time: Within 48 hours</p>
</body></html>`);
});

app.get('/about', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>About Us - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}</style></head><body>
<h1>About Feriwala</h1>
<p>Feriwala is a quick-commerce platform delivering clothes and footwear in minutes from local stores to your doorstep.</p>
<h2>What We Do</h2><p>We connect customers with nearby clothing retailers, enabling ultra-fast delivery of apparel products. Our platform empowers local shop owners to reach more customers while providing buyers with the convenience of instant fashion delivery.</p>
<h2>How It Works</h2><ol><li>Browse products from stores near you</li><li>Place your order</li><li>Our delivery partner picks items from the store</li><li>Delivered to your doorstep in 25-45 minutes</li></ol>
<h2>Our Promise</h2><ul><li>Genuine products from verified local retailers</li><li>Real-time order tracking</li><li>Easy returns within 24 hours</li><li>Secure payments via Razorpay</li><li>Cash on Delivery available</li></ul>
<h2>Contact</h2><p>Email: <a href="mailto:support@feriwala.in">support@feriwala.in</a><br>Website: <a href="https://api.feriwala.in">feriwala.in</a></p>
</body></html>`);
});

app.get('/shipping', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Shipping &amp; Delivery Policy - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}table{border-collapse:collapse;width:100%;margin:12px 0}th,td{border:1px solid #ddd;padding:10px;text-align:left}th{background:#f9f9f9}</style></head><body>
<h1>Shipping &amp; Delivery Policy</h1><p><em>Last updated: May 2025</em></p>
<h2>1. Delivery Area</h2><p>Feriwala delivers within serviceable pin codes only. Availability is shown in the app based on your location.</p>
<h2>2. Delivery Time</h2><p>Estimated delivery: <strong>25-45 minutes</strong> from order confirmation, subject to store preparation time, distance, and traffic conditions.</p>
<h2>3. Delivery Charges</h2>
<table><tr><th>Order Value</th><th>Delivery Fee</th></tr>
<tr><td>Above ₹299</td><td>FREE</td></tr>
<tr><td>Below ₹299</td><td>₹20</td></tr></table>
<h2>4. Delivery Verification</h2><p>Our delivery partner may ask for an OTP or signature to confirm delivery at your doorstep.</p>
<h2>5. Failed Delivery</h2><p>If you are unavailable at the delivery address, the partner will attempt to contact you. If unreachable, the order will be returned to the store and a refund will be initiated minus delivery charges.</p>
<h2>6. Contact</h2><p>For delivery issues: <a href="mailto:support@feriwala.in">support@feriwala.in</a></p>
</body></html>`);
});

app.get('/delete-account', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Delete Account - Feriwala</title><style>body{font-family:sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.7;color:#333}h1{color:#F47721}h2{margin-top:28px}a{color:#F47721}</style></head><body>
<h1>Account &amp; Data Deletion</h1>
<h2>How to Delete Your Account</h2><p>You can request account deletion by:</p><ol><li>Opening the Feriwala app → Profile → Help &amp; Support → Request Account Deletion</li><li>Or emailing <a href="mailto:privacy@feriwala.in">privacy@feriwala.in</a> from your registered email with subject "Delete My Account"</li></ol>
<h2>What Gets Deleted</h2><ul><li>Your profile information (name, email, phone)</li><li>Saved addresses</li><li>Order history</li><li>Wallet balance and rewards</li></ul>
<h2>Timeline</h2><p>Account deletion is processed within <strong>72 hours</strong> of request. You will receive a confirmation email once completed.</p>
<h2>Important Notes</h2><ul><li>Pending orders must be completed or cancelled before deletion</li><li>Any pending refunds will be processed before account removal</li><li>This action is irreversible</li></ul>
</body></html>`);
});

// ─── Health checks ────────────────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/health/deep', async (req, res) => {
  const mongoConnected = isMongoReady();
  let postgresConnected = false;

  try {
    await probePostgres();
    postgresConnected = true;
    dbStatus.postgres.connected = true;
    dbStatus.postgres.lastSuccessAt = new Date().toISOString();
  } catch (err) {
    dbStatus.postgres.connected = false;
    dbStatus.postgres.lastError = err.message;
  }

  dbStatus.mongo.connected = mongoConnected;
  if (!mongoConnected) {
    dbStatus.mongo.lastError = dbStatus.mongo.lastError || 'MongoDB not connected';
  }

  const healthy = mongoConnected && postgresConnected;
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    services: {
      mongo: { ...dbStatus.mongo, ready: mongoConnected },
      postgres: { ...dbStatus.postgres, ready: postgresConnected },
    },
  });
});

// ─── Socket.IO ────────────────────────────────────────────────────────────────
socketHandler(io);

// ─── Error handling ───────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  // Don't leak internal error details to clients in production
  const message = process.env.NODE_ENV === 'production'
    ? 'Internal Server Error'
    : (err.message || 'Internal Server Error');
  res.status(err.status || 500).json({ success: false, message });
});

app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// ─── DB connection helpers ────────────────────────────────────────────────────
async function connectDatabases() {
  const mongoRetry = async (attempts = 5) => {
    for (let i = 1; i <= attempts; i++) {
      dbStatus.mongo.attempts += 1;
      try {
        await connectMongoDB();
        dbStatus.mongo.connected = true;
        dbStatus.mongo.lastError = null;
        dbStatus.mongo.lastSuccessAt = new Date().toISOString();
        console.log('MongoDB connected');
        return;
      } catch (err) {
        dbStatus.mongo.connected = false;
        dbStatus.mongo.lastError = err.message;
        console.error(`MongoDB connection attempt ${i}/${attempts} failed:`, err.message);
        if (i < attempts) await sleep(10000);
      }
    }
    console.error('MongoDB unavailable — routes requiring it will error until reconnected');
  };

  const pgRetry = async (attempts = 5) => {
    for (let i = 1; i <= attempts; i++) {
      dbStatus.postgres.attempts += 1;
      try {
        await connectPostgres();
        await syncModels();
        dbStatus.postgres.connected = true;
        dbStatus.postgres.lastError = null;
        dbStatus.postgres.lastSuccessAt = new Date().toISOString();
        console.log('PostgreSQL connected and models synced');
        return;
      } catch (err) {
        dbStatus.postgres.connected = false;
        dbStatus.postgres.lastError = err.message;
        console.error(`PostgreSQL connection attempt ${i}/${attempts} failed:`, err.message);
        if (i < attempts) await sleep(10000);
      }
    }
    console.error('PostgreSQL unavailable — routes requiring it will error until reconnected');
  };

  await Promise.all([mongoRetry(), pgRetry()]);
}

function startDatabaseRecoveryLoop() {
  let running = false;
  setInterval(async () => {
    if (running) return;
    running = true;
    try {
      if (!isMongoReady()) {
        dbStatus.mongo.attempts += 1;
        try {
          await connectMongoDB();
          dbStatus.mongo.connected = true;
          dbStatus.mongo.lastError = null;
          dbStatus.mongo.lastSuccessAt = new Date().toISOString();
          console.log('MongoDB reconnected by recovery loop');
        } catch (err) {
          dbStatus.mongo.connected = false;
          dbStatus.mongo.lastError = err.message;
        }
      }

      try {
        await probePostgres();
        dbStatus.postgres.connected = true;
        dbStatus.postgres.lastError = null;
        dbStatus.postgres.lastSuccessAt = new Date().toISOString();
      } catch (err) {
        dbStatus.postgres.connected = false;
        dbStatus.postgres.lastError = err.message;
      }
    } finally {
      running = false;
    }
  }, DB_RETRY_INTERVAL_MS);
}

async function startServer() {
  server.listen(PORT, () => {
    console.log(`Feriwala API server running on port ${PORT}`);
  });

  connectDatabases().catch(err => console.error('DB connection error:', err.message));
  startDatabaseRecoveryLoop();
}

startServer();
