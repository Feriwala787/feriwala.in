# Feriwala - Quick Commerce Platform

Delivering clothes in minutes.

## Architecture

```
├── backend/          # Node.js API server
├── admin-portal/     # React.js admin web portal
├── feriwala_customer/ # Flutter customer app
├── feriwala_shop/     # Flutter shop/outlet app
├── feriwala_delivery/ # Flutter delivery/picker app
└── deployment/        # Server configs & scripts
```

## Tech Stack

| Component        | Technology              |
|-----------------|------------------------|
| Mobile Apps      | Flutter (Android)       |
| Backend API      | Node.js + Express       |
| Admin Portal     | React.js                |
| User Database    | MongoDB (Atlas Free)    |
| Product Database | PostgreSQL              |
| Maps             | Google Maps API         |
| Server           | AWS Bitnami             |

## Services

- **Customer App**: Browse products, place orders, track delivery, manage returns
- **Shop App**: Manage inventory, create deals/promos, handle orders, invoicing
- **Delivery App**: Pick items, deliver orders, handle returns with verification
- **Admin Portal**: Register shops, manage platform settings

## Server

- Public IPv4: 13.233.227.15
- Public IPv6: 2406:da1a:19e:d100:a0e2:d3b3:4b57:29ef

## Deployment

- See `deployment/LIGHTSAIL_DEPLOYMENT.md` for AWS Lightsail deployment instructions.

- See `docs/ORDER_FULFILLMENT_FLOW.md` for COD order lifecycle (customer -> shop prep -> delivery task -> delivered).

- See `docs/QA_WORKFLOW_CHECKLIST.md` for end-to-end QA validation steps.

## CI APK Builds

- GitHub Actions workflow: `.github/workflows/android-apk-build.yml`
- Builds installable **debug APKs** for:
  - `feriwala_customer`
  - `feriwala_shop`
  - `feriwala_delivery`
- Trigger manually from **Actions → Build Android APKs → Run workflow**
- Download APKs from workflow artifacts and install directly on Android phones (unknown sources enabled).
- Auto-runs on:
  - pushes that touch app/workflow files (any branch)
  - pull requests that touch app/workflow files

### If you cannot see APK artifacts

- Open the run, then scroll to the **Artifacts** section (right side / bottom, depending on GitHub UI).
- You should see:
  - `feriwala_customer-debug-apk`
  - `feriwala_shop-debug-apk`
  - `feriwala_delivery-debug-apk`
- If artifacts are missing:
  - ensure the workflow run status is **green** (successful),
  - verify the change touched one of the configured paths, or run it manually with **Run workflow**.
