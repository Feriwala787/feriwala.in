# AGENTS.md

## Project

**Feriwala** — quick-commerce platform for clothes delivery.  
Customers order clothes from nearby shops; delivery agents pick and deliver within minutes.

## Architecture

```
backend/              Node.js + Express API (port 3000)
admin-portal/         React admin web portal
feriwala_customer/    Flutter customer app (Android + Web)
feriwala_shop/        Flutter shop/outlet app (Android + Web)
feriwala_delivery/    Flutter delivery agent app (Android + Web)
deployment/           AWS Lightsail deploy scripts + nginx/PM2 configs
docs/                 Order flow and QA docs
```

## Tech Stack

| Layer | Technology |
|---|---|
| Backend API | Node.js 20, Express 4, Socket.IO 4 |
| User DB | MongoDB Atlas (Mongoose) |
| Product/Order DB | PostgreSQL (Sequelize) |
| Mobile/Web apps | Flutter (Dart) |
| Admin portal | React 18, Tailwind CSS |
| File storage | AWS S3 (multer-s3) |
| Server | AWS Lightsail (Bitnami, PM2, nginx) |

## Environment Setup

Copy and fill in the backend env file before running:

```bash
cp backend/.env.example backend/.env
# Edit backend/.env — fill in all <placeholder> values
```

Required env vars: `MONGODB_URI`, `PG_HOST`, `PG_DATABASE`, `PG_USER`, `PG_PASSWORD`, `JWT_SECRET`, `JWT_REFRESH_SECRET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GOOGLE_MAPS_API_KEY`.

## Commands

### Backend

```bash
cd backend
npm install
npm run dev          # nodemon dev server on port 3000
npm test             # smoke + health integration tests
npm run test:api     # API integration tests (requires live API_BASE_URL)
npm run test:all     # all tests
npm run smoke        # syntax check only (no DB needed)
```

### Admin Portal

```bash
cd admin-portal
npm install
npm start            # dev server on port 3001
npm run build        # production build
```

### Flutter Apps

```bash
cd feriwala_customer   # or feriwala_shop / feriwala_delivery
flutter pub get
flutter run            # run on connected device/emulator
flutter test           # unit + widget tests
flutter build apk --debug   # build debug APK
flutter build web --release # build web
```

### Local web testing (all three apps)

```bash
bash start-apps.sh
# Shop     → http://localhost:8081
# Customer → http://localhost:8082
# Delivery → http://localhost:8083
```

## Conventions

- **Branch naming:** `<type>/<short-description>` — e.g. `feat/add-ratings`, `fix/token-refresh`
- **Commit messages:** `<type>: <what and why>` — types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`
- **PRs target `main`**; squash merge preferred
- **Error handling in routes:** always use `routeError(res, error)` from `backend/src/utils/routeError.js` — never `res.status(500).json({ message: error.message })`
- **New backend routes:** add `const { routeError } = require('../utils/routeError');` at the top

## Key Files

| File | Purpose |
|---|---|
| `backend/src/server.js` | Express app, middleware, CORS, rate limiting, health endpoints |
| `backend/src/sockets/socketHandler.js` | Socket.IO with JWT auth |
| `backend/src/utils/routeError.js` | Shared error response helper |
| `backend/src/database/postgres.js` | Sequelize setup + model sync |
| `backend/src/models/pg/associations.js` | All Sequelize associations |
| `feriwala_customer/lib/config/app_config.dart` | API URL + Maps key (use `--dart-define`) |
| `deployment/LIGHTSAIL_DEPLOYMENT.md` | Full deploy guide |
| `docs/ORDER_FULFILLMENT_FLOW.md` | Order lifecycle |
| `docs/QA_WORKFLOW_CHECKLIST.md` | End-to-end QA steps |
| `TEST_CREDENTIALS.md` | Test accounts and manual test flow |

## Off-limits

- Do **not** commit real credentials, `.env` files, or `*.pem` keys
- Do **not** use `sequelize.sync({ alter: true })` — use migrations for schema changes
- Do **not** use `res.status(500).json({ message: error.message })` directly in routes
- Do **not** hardcode API keys in Flutter source — use `String.fromEnvironment` / `--dart-define`
- Do **not** modify `deployment/` scripts without testing on a staging instance first

## CI / GitHub Actions

| Workflow | Trigger | What it does |
|---|---|---|
| `automation-testing.yml` | push/PR to main | Backend tests, admin portal build, Flutter tests |
| `android-apk-build.yml` | push/PR touching app files | Builds debug APKs for all three Flutter apps |
| `deploy-backend.yml` | push to main touching `backend/` | rsync + PM2 restart on Lightsail |
| `deploy-portal.yml` | push to main touching `admin-portal/` | Build + rsync admin portal to Lightsail |

Required GitHub secrets: `LIGHTSAIL_SSH_KEY` (or `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`).

## Known TODOs

- **Payment gateway** — `online`, `upi`, `card` payment methods are modelled but not wired to a gateway (Razorpay/Stripe). See `backend/src/services/paymentService.js`.
- **FCM push notifications** — `fcmToken` is stored on users but notifications are not sent. See `backend/src/services/notificationService.js`.
- **Product reviews** — `avgRating`/`totalReviews` fields exist; write endpoint is at `POST /api/products/:id/reviews`.
- **Refund flow** — `ReturnRequest.refundStatus` exists but no refund processing is implemented.
