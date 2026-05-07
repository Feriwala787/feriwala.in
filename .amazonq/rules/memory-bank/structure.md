# Project Structure

## Directory Organization

```
dd/
├── backend/              # Node.js API server
├── admin-portal/         # React.js admin web portal
├── feriwala_customer/    # Flutter customer mobile app
├── feriwala_shop/        # Flutter shop/outlet mobile app
├── feriwala_delivery/    # Flutter delivery/picker mobile app
├── deployment/           # Server configs & deployment scripts
├── docs/                 # Documentation
├── branding/             # Brand assets
└── .github/workflows/    # CI/CD pipelines
```

## Core Components

### Backend (`backend/`)
Node.js + Express API server handling all business logic.

**Structure:**
- `src/server.js` - Main entry point
- `src/routes/` - API endpoint definitions
- `src/models/` - Database models (MongoDB + PostgreSQL)
- `src/services/` - Business logic layer
- `src/middleware/` - Auth, validation, rate limiting
- `src/database/` - DB connections and migrations
- `src/sockets/` - WebSocket handlers for real-time features
- `src/utils/` - Helper functions
- `src/constants/` - Shared constants (e.g., apparel categories)
- `tests/` - Integration and smoke tests

### Admin Portal (`admin-portal/`)
React.js web application for platform administration.

**Structure:**
- `src/App.js` - Main React component
- `src/pages/` - Page components
- `src/components/` - Reusable UI components
- `src/services/` - API client services
- `src/context/` - React context providers
- `public/` - Static assets

### Flutter Apps (`feriwala_customer/`, `feriwala_shop/`, `feriwala_delivery/`)
Android mobile applications built with Flutter.

**Common Structure:**
- `lib/main.dart` - App entry point
- `lib/screens/` - UI screens
- `lib/providers/` - State management (Provider pattern)
- `lib/services/` - API and business logic
- `lib/config/` - Configuration (customer app)
- `lib/utils/` - Utilities (customer app)
- `android/` - Android-specific configuration
- `assets/images/` - Image assets
- `test/` - Unit and smoke tests

### Deployment (`deployment/`)
Server configuration and deployment automation.

**Contents:**
- `ecosystem.config.js` - PM2 process manager config
- `deploy.sh` - Local deployment script
- `deploy-from-github.sh` - Remote deployment script
- `setup-server.sh` - Initial server setup
- `nginx.conf` / `apache-proxy.conf` - Reverse proxy configs
- `LIGHTSAIL_DEPLOYMENT.md` - Deployment guide

### Documentation (`docs/`)
- `ORDER_FULFILLMENT_FLOW.md` - COD order lifecycle
- `QA_WORKFLOW_CHECKLIST.md` - End-to-end testing guide
- `DELIVERY_E2E_TEST_PLAN.md` - Delivery testing
- `DELIVERY_REALTIME_AND_TELEMETRY_CONTRACT.md` - Real-time specs

### CI/CD (`.github/workflows/`)
- `android-apk-build.yml` - Build debug APKs for all Flutter apps
- `deploy-backend.yml` - Backend deployment automation
- `deploy-portal.yml` - Admin portal deployment
- `automation-testing.yml` - Automated testing

## Architectural Patterns

### Multi-Tier Architecture
- **Presentation Layer**: Flutter apps + React portal
- **API Layer**: Express.js REST API + WebSocket
- **Business Logic**: Service layer in backend
- **Data Layer**: MongoDB (users) + PostgreSQL (products)

### Real-Time Communication
- Socket.IO for live delivery tracking
- WebSocket connections for order status updates
- Real-time location telemetry

### State Management
- **Flutter Apps**: Provider pattern for reactive state
- **React Portal**: Context API for global state
- **Backend**: Stateless API with JWT authentication

### Database Strategy
- **MongoDB**: User accounts, authentication, sessions
- **PostgreSQL**: Product catalog, orders, transactions
- Dual-database approach for optimized data access

### Deployment Architecture
- AWS Lightsail instance (ap-south-1)
- PM2 for process management
- Nginx/Apache reverse proxy
- GitHub Actions for CI/CD
