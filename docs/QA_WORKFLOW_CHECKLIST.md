# Workflow QA Checklist (Order, Delivery, Return/Replace)

## A. Order placement (Customer)
- [ ] Place COD order successfully.
- [ ] Duplicate tap on place-order does not create duplicate order (manual guard check).
- [ ] Order appears in customer order list and shop order list.

## B. Shop preparation
- [ ] Shop updates order: `pending -> confirmed -> preparing -> ready_for_pickup`.
- [ ] Inventory reserved/released correctly on confirm/cancel scenarios.

## C. Delivery assignment
- [ ] On `ready_for_pickup`, delivery task auto-created.
- [ ] If agent online+available exists, task status is `assigned`.
- [ ] If no agent available, task status is `pending`.

## D. Delivery app progression
- [ ] Agent can go online/offline from app (`/delivery/online` compatibility route).
- [ ] Agent accepts task.
- [ ] Pickup OTP required for `picked_up`.
- [ ] Delivery OTP required for `completed`.
- [ ] Order status syncs: `picked_up` -> `out_for_delivery` -> `delivered`.

## E. Return/Replace flow
- [ ] Customer can submit return request with bank details.
- [ ] Customer can submit replace request.
- [ ] Shop sees return list.
- [ ] Shop approve/reject works.
- [ ] For replace approval, replacement order is auto-created.
- [ ] For refund flow, refund status/reference can be set and viewed.
- [ ] Customer sees return timeline/status in tracking screen.

## F. Day-end return batch plan
- [ ] Shop selects return requests and creates day-end pickup plan.
- [ ] `return_pickup` tasks are created.
- [ ] Return request status set to `pickup_assigned`.
- [ ] Shop can monitor planned pickups and completion.

## G. Security and role checks
- [ ] Customer cannot access other customer orders/returns.
- [ ] Shop cannot access other shop returns.
- [ ] Delivery agent cannot update task not assigned to them.

