# COD Order Fulfillment Flow

This document explains where a customer order goes after cart checkout and who prepares/picks/delivers it.

## 1) Customer places order (COD supported)
- Endpoint: `POST /orders`
- Role: `customer`
- `paymentMethod` can be `cod`.
- System reserves inventory immediately.
- Order starts in `pending`.

## 2) Shop receives order and prepares items
- Shop app polls/opens shop orders:
  - `GET /orders/shop/:shopId`
- Shop updates order status via:
  - `PUT /orders/:id/status`
- Typical transitions:
  - `pending -> confirmed -> preparing -> ready_for_pickup`

## 3) Delivery task creation and assignment
- When order becomes `ready_for_pickup`, backend auto-creates/assigns a delivery task.
- Endpoint used by backend service logic:
  - delivery task entity in `delivery_tasks`
- Agent selection:
  - nearest online + available delivery agent matching shop assignment
- Task statuses start at:
  - `assigned` (if an agent found) or `pending` (if not yet assigned)

## 4) Delivery agent picks and delivers
- Delivery app reads tasks:
  - `GET /delivery/my-tasks`
- Accept task:
  - `PUT /delivery/tasks/:id/accept`
- Update task status:
  - `PUT /delivery/tasks/:id/status`
- OTP checks:
  - pickup OTP required for `picked_up`
  - delivery OTP required for `completed` (delivery task)

## 5) Order status sync with delivery progress
- On delivery task `picked_up` -> order status becomes `picked_up`
- On delivery task `in_transit`/`arrived` -> order status becomes `out_for_delivery`
- On delivery task `completed` -> order status becomes `delivered`

## 6) Who does what?
- **Customer app**: place COD order, track status, receive updates
- **Shop app**: confirm & prepare order
- **Delivery app**: accept task, pickup from shop, deliver to customer

## 7) Visibility
- Shop can view order and attached delivery tasks:
  - `GET /orders/:id`
- Customer can see order status via:
  - `GET /orders/my-orders`

## 8) Returns / replacements and refund to bank
- Customer raises return/replace request:
  - `POST /delivery/returns`
  - Supports `returnType` (`return` / `replace`) + `bankDetails`
- Shop views all return requests:
  - `GET /delivery/returns/shop/:shopId`
- Shop can approve/reject/process refund metadata:
  - `PUT /delivery/returns/:id/process`
- End of day: shop can batch all return pickups at once:
  - `POST /delivery/returns/day-end-plan`
  - Creates pending `return_pickup` tasks and marks requests as `pickup_assigned`.
