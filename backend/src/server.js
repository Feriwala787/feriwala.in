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

// ─── Landing page ─────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Feriwala - Clothes Delivered in Minutes</title>
<meta name="description" content="Feriwala delivers clothes and footwear from local stores to your doorstep in 25-45 minutes. Download the app now!">
<meta property="og:title" content="Feriwala - Clothes Delivered in Minutes">
<meta property="og:description" content="Quick commerce for fashion. Get clothes from nearby stores delivered in minutes.">
<meta property="og:type" content="website">
<meta property="og:url" content="https://feriwala.in">
<link rel="icon" type="image/png" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>\uD83D\uDC55</text></svg>">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#333;background:#fff;overflow-x:hidden}
a{color:#F47721;text-decoration:none}

/* Nav */
.nav{position:fixed;top:0;width:100%;background:rgba(255,255,255,0.95);backdrop-filter:blur(10px);border-bottom:1px solid #f0f0f0;padding:12px 24px;display:flex;align-items:center;justify-content:space-between;z-index:100}
.nav-brand{font-size:22px;font-weight:800;color:#F47721}
.nav-links{display:flex;gap:16px;align-items:center}
.nav-links a{font-size:13px;color:#555;font-weight:500;transition:color 0.2s}
.nav-links a:hover{color:#F47721}
.nav-btn{background:#F47721;color:#fff!important;padding:8px 16px;border-radius:8px;font-size:12px;font-weight:600}
.nav-btn:hover{background:#e0650f}

/* Hero */
.hero{min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:100px 20px 60px;background:linear-gradient(180deg,#FFF5EE 0%,#fff 40%,#fff 100%)}
.brand{font-size:56px;font-weight:900;color:#F47721;margin-bottom:12px;letter-spacing:-1px}
.tagline{font-size:22px;color:#555;margin-bottom:12px;font-weight:400}
.sub-tagline{font-size:15px;color:#888;margin-bottom:48px;max-width:500px}

/* Stats */
.stats{display:flex;gap:48px;margin-bottom:56px;flex-wrap:wrap;justify-content:center}
.stat{text-align:center}
.stat-value{font-size:32px;font-weight:800;color:#F47721}
.stat-label{font-size:12px;color:#888;margin-top:4px;text-transform:uppercase;letter-spacing:0.5px}

/* Features */
.features-section{padding:80px 20px;background:#FAFAFA}
.section-title{text-align:center;font-size:28px;font-weight:700;margin-bottom:12px;color:#222}
.section-sub{text-align:center;font-size:14px;color:#888;margin-bottom:48px}
.features{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:24px;max-width:960px;margin:0 auto}
.feature{background:#fff;border:1px solid #f0f0f0;border-radius:16px;padding:28px;box-shadow:0 2px 12px rgba(0,0,0,0.03);transition:transform 0.2s,box-shadow 0.2s}
.feature:hover{transform:translateY(-4px);box-shadow:0 8px 24px rgba(244,119,33,0.1)}
.feature-icon{font-size:36px;margin-bottom:12px}
.feature h3{font-size:16px;margin-bottom:6px;color:#222}
.feature p{font-size:13px;color:#666;line-height:1.6}

/* How it works */
.how-section{padding:80px 20px;max-width:700px;margin:0 auto}
.steps{display:flex;flex-direction:column;gap:20px}
.step{display:flex;align-items:center;gap:20px;background:#fff;border:1px solid #f0f0f0;border-radius:12px;padding:20px;box-shadow:0 2px 8px rgba(0,0,0,0.03)}
.step-num{width:44px;height:44px;border-radius:50%;background:linear-gradient(135deg,#F47721,#FF9A56);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:16px;flex-shrink:0}
.step-text{font-size:15px;color:#444}

/* Download */
.download-section{padding:80px 20px;text-align:center;background:linear-gradient(135deg,#FFF5EE,#FFF)}
.download-btn{display:inline-flex;align-items:center;gap:12px;background:#F47721;color:#fff;padding:18px 36px;border-radius:14px;text-decoration:none;font-size:17px;font-weight:700;box-shadow:0 6px 24px rgba(244,119,33,0.35);transition:transform 0.2s,box-shadow 0.2s}
.download-btn:hover{transform:translateY(-3px);box-shadow:0 10px 32px rgba(244,119,33,0.4)}
.download-btn svg{width:26px;height:26px;fill:#fff}
.coming-soon{font-size:13px;color:#999;margin-top:14px}

/* Footer */
footer{background:#1a1a1a;color:#ccc;padding:48px 24px 32px}
.footer-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:32px;max-width:960px;margin:0 auto 32px}
.footer-col h4{color:#fff;font-size:14px;margin-bottom:12px;font-weight:600}
.footer-col p,.footer-col a{font-size:13px;color:#aaa;line-height:2;display:block}
.footer-col a:hover{color:#F47721}
.footer-bottom{border-top:1px solid #333;padding-top:20px;text-align:center;font-size:12px;color:#666;max-width:960px;margin:0 auto}
.footer-bottom a{color:#888;margin:0 6px}

@media(max-width:600px){.brand{font-size:38px}.tagline{font-size:18px}.stats{gap:24px}.nav-links a:not(.nav-btn){display:none}}
</style></head><body>

<nav class="nav">
  <div class="nav-brand">Feriwala</div>
  <div class="nav-links">
    <a href="#features">Features</a>
    <a href="#how-it-works">How It Works</a>
    <a href="#download">Download</a>
    <a href="/admin" class="nav-btn">Admin Portal</a>
  </div>
</nav>

<section class="hero">
  <h1 class="brand">Feriwala</h1>
  <p class="tagline">Clothes delivered in minutes \u26A1</p>
  <p class="sub-tagline">Quick commerce for fashion. Shop from local stores near you and get clothes & footwear delivered to your doorstep.</p>

  <div class="stats">
    <div class="stat"><div class="stat-value">25-45</div><div class="stat-label">Min Delivery</div></div>
    <div class="stat"><div class="stat-value">\u20B90</div><div class="stat-label">Delivery 299+</div></div>
    <div class="stat"><div class="stat-value">24hr</div><div class="stat-label">Easy Returns</div></div>
    <div class="stat"><div class="stat-value">COD</div><div class="stat-label">& Online Pay</div></div>
  </div>
</section>

<section class="features-section" id="features">
  <h2 class="section-title">Why Feriwala?</h2>
  <p class="section-sub">Everything you need for quick fashion shopping</p>
  <div class="features">
    <div class="feature"><div class="feature-icon">\uD83D\uDC55</div><h3>Local Fashion, Fast</h3><p>Shop from verified clothing stores near you. Men, Women, Kids, Ethnic, Western, Footwear \u2014 all categories available.</p></div>
    <div class="feature"><div class="feature-icon">\uD83D\uDEF5</div><h3>Lightning Delivery</h3><p>Our delivery partners pick from the store and bring it to your doorstep in 25-45 minutes. Track live on map.</p></div>
    <div class="feature"><div class="feature-icon">\uD83D\uDCB0</div><h3>Flexible Payments</h3><p>Pay with Cash on Delivery or use UPI, cards, net banking. All online payments secured by Razorpay.</p></div>
    <div class="feature"><div class="feature-icon">\uD83D\uDD04</div><h3>Hassle-free Returns</h3><p>Not satisfied? Return within 24 hours. Our delivery partner picks it up from your doorstep. No questions asked.</p></div>
    <div class="feature"><div class="feature-icon">\uD83D\uDCCD</div><h3>Real-time Tracking</h3><p>Track your order live on the map. Know exactly when your delivery partner is arriving.</p></div>
    <div class="feature"><div class="feature-icon">\uD83C\uDF1F</div><h3>Deals & Offers</h3><p>Exclusive deals from local stores. Save more with promotional offers and free delivery on orders above \u20B9299.</p></div>
  </div>
</section>

<section class="how-section" id="how-it-works">
  <h2 class="section-title">How It Works</h2>
  <p class="section-sub">4 simple steps to get clothes delivered</p>
  <div class="steps">
    <div class="step"><div class="step-num">1</div><div class="step-text">Open the app and browse products from nearby stores</div></div>
    <div class="step"><div class="step-num">2</div><div class="step-text">Add items to cart and place your order</div></div>
    <div class="step"><div class="step-num">3</div><div class="step-text">Our delivery partner picks items from the store</div></div>
    <div class="step"><div class="step-num">4</div><div class="step-text">Delivered to your doorstep in 25-45 minutes!</div></div>
  </div>
</section>

<section class="download-section" id="download">
  <h2 class="section-title">Download the App</h2>
  <p class="section-sub">Available for Android</p>
  <a href="#" id="playstore-link" class="download-btn">
    <svg viewBox="0 0 24 24"><path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.61 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.5,12.92 20.16,13.19L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/></svg>
    Get it on Google Play
  </a>
  <p class="coming-soon">\uD83D\uDEA7 Coming soon on Play Store. Stay tuned!</p>
</section>

<footer>
  <div class="footer-grid">
    <div class="footer-col">
      <h4>Feriwala</h4>
      <p>Quick commerce for clothes & footwear. Delivering fashion from local stores in minutes.</p>
      <p style="margin-top:8px">\u00A9 2025 Feriwala. All rights reserved.</p>
    </div>
    <div class="footer-col">
      <h4>Quick Links</h4>
      <a href="/about">About Us</a>
      <a href="/privacy">Privacy Policy</a>
      <a href="/terms">Terms & Conditions</a>
      <a href="/refund">Refund & Cancellation</a>
      <a href="/shipping">Shipping & Delivery</a>
    </div>
    <div class="footer-col">
      <h4>For Business</h4>
      <a href="/admin">Admin Portal Login</a>
      <a href="mailto:business@feriwala.in">Partner With Us</a>
      <a href="/contact">Contact Us</a>
    </div>
    <div class="footer-col">
      <h4>Get In Touch</h4>
      <p>\uD83D\uDCE7 <a href="mailto:care@feriwala.in">care@feriwala.in</a></p>
      <p>\uD83D\uDCDE <a href="tel:+919399584823">+91 93995 84823</a></p>
      <p>\uD83D\uDCCD India</p>
      <p style="margin-top:8px;font-size:11px;color:#666">Mon-Sat, 9:00 AM \u2013 8:00 PM IST</p>
    </div>
  </div>
  <div class="footer-bottom">
    <a href="/privacy">Privacy</a>\u2022
    <a href="/terms">Terms</a>\u2022
    <a href="/refund">Refunds</a>\u2022
    <a href="/contact">Contact</a>\u2022
    <a href="/admin">Admin</a>
  </div>
</footer>
</body></html>`);
});

// ─── Admin portal redirect ────────────────────────────────────────────────────
app.get('/admin', (req, res) => {
  res.redirect('http://65.2.9.216');
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
