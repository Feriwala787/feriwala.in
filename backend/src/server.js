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
