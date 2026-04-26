# Feriwala Test Credentials
# ─────────────────────────────────────────────────────────────────────────────
# DO NOT COMMIT REAL PRODUCTION CREDENTIALS HERE
# This file is for QA / manual testing only
# ─────────────────────────────────────────────────────────────────────────────

## Live URLs

| Service       | URL                                  |
|---------------|--------------------------------------|
| API           | https://api.feriwala.in/api          |
| Admin Portal  | https://feriwala.in                  |
| Health Check  | https://api.feriwala.in/api/health   |

## Web Test Apps (IDX — run `bash start-apps.sh` to start)

| App           | Port | Local URL                  |
|---------------|------|----------------------------|
| Shop App      | 8081 | http://localhost:8081      |
| Customer App  | 8082 | http://localhost:8082      |
| Delivery App  | 8083 | http://localhost:8083      |

---

## Test Accounts

### Shop Admin
| Field    | Value                        |
|----------|------------------------------|
| Email    | shopadmin@feriwala.test      |
| Password | Feriwala@123                 |
| Role     | shop_admin                   |
| Shop ID  | 1 (Feriwala Test Shop)       |
| Login ID | shopadmin                    |

### Customer
| Field    | Value                        |
|----------|------------------------------|
| Email    | customer@feriwala.test       |
| Password | Feriwala@123                 |
| Role     | customer                     |
| Phone    | 9300000003                   |

### Delivery Agent
| Field    | Value                        |
|----------|------------------------------|
| Email    | delivery@feriwala.test       |
| Password | Feriwala@123                 |
| Role     | delivery_agent               |
| Phone    | 9300000002                   |

### Platform Admin
| Field    | Value                        |
|----------|------------------------------|
| Email    | admin@feriwala.com           |
| Password | FwAdmin@2026!                |
| Role     | admin                        |
| Login ID | adminferiwala                |

---

## Test Shop Data

| Field         | Value                        |
|---------------|------------------------------|
| Shop Name     | Feriwala Test Shop           |
| Shop Code     | FWTESTSHOP                   |
| Shop ID       | 1                            |
| City          | Delhi                        |

---

## Test Promo Codes

| Code     | Type       | Value | Min Order | Notes              |
|----------|------------|-------|-----------|--------------------|
| SAVE50   | flat       | ₹50   | ₹200      | Create via shop app|

---

## Manual Test Flow

1. **Shop App** → Login → Add product → Set inventory → Create promo
2. **Customer App** → Register/Login → Browse → Add to cart → Apply promo → Place order
3. **Shop App** → Confirm order → Preparing → Ready for pickup
4. **Delivery App** → Login → Go online → Accept task → Pickup OTP → In transit → Delivery OTP
5. **Customer App** → Verify delivered → Request return
6. **Shop App** → Approve return → Day-end plan
7. **Delivery App** → Verify return pickup

---

## AWS Infrastructure

| Resource      | Value                                          |
|---------------|------------------------------------------------|
| Server        | Node-js-1 (AWS Lightsail, ap-south-1)          |
| Public IP     | 65.2.9.216                                     |
| S3 Bucket     | feriwala-media (ap-south-1)                    |
| MongoDB       | Atlas Free (cluster0.lftgouo.mongodb.net)      |
| PostgreSQL    | Lightsail instance (localhost:5432)            |

---

## Running Tests

```bash
# From backend/
npm run test:all          # 51 tests against live API
node tests/live-feature-check.js   # Full e2e flow check
```
