# Checkout Flow Diagram

## New Multi-Screen Checkout Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CHECKOUT FLOW                                │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│  Cart Screen │
│              │
│ • View items │
│ • Quantities │
│ • Promo code │
│ • Subtotal   │
└──────┬───────┘
       │
       │ [Checkout Button]
       ▼
┌──────────────────┐
│ Checkout Screen  │ ◄── Router/Coordinator
│                  │     (Simplified)
└──────┬───────────┘
       │
       │ Auto-navigate
       ▼
┌────────────────────────────────────────────────────────────────┐
│           Address Selection Screen                             │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ 📍 Home • 400001                                      │     │
│  │ John Doe                                              │     │
│  │ 123 Main Street, Landmark: Near Park                 │     │
│  │ Mumbai, Maharashtra - 400001                          │     │
│  │ Phone: 9876543210                                     │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ 🏢 Work • 400002                                      │     │
│  │ John Doe                                              │     │
│  │ 456 Office Complex                                    │     │
│  │ Mumbai, Maharashtra - 400002                          │     │
│  │ Phone: 9876543210                                     │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  [+ Add New Address]                                           │
│  [Deliver Here] ──────────────────────────────────────┐       │
└────────────────────────────────────────────────────────┼───────┘
                                                         │
                                                         ▼
┌────────────────────────────────────────────────────────────────┐
│  Add Address Dialog (if clicked)                               │
│                                                                 │
│  Address Type: [Home ▼]                                        │
│                                                                 │
│  [📍 Use Current Location] ◄── Auto-captures GPS               │
│  ✓ Location Captured: 19.0760, 72.8777                        │
│                                                                 │
│  Receiver Name: [____________]                                 │
│  Phone: [____________]                                         │
│  Address Line 1: [____________]                                │
│  Landmark: [____________]                                      │
│  City: [Mumbai] ◄── Auto-filled from location                 │
│  State: [Maharashtra] ◄── Auto-filled from location           │
│  Pincode: [____________]                                       │
│                                                                 │
│  ☐ Set as default address                                      │
│                                                                 │
│  [Cancel]  [Save]                                              │
└────────────────────────────────────────────────────────────────┘
                                                         │
                                                         ▼
┌────────────────────────────────────────────────────────────────┐
│           Payment Selection Screen                             │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ ● 💵 Cash on Delivery                                │     │
│  │   Pay when you receive your order                    │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ ○ 💳 UPI                          [Coming Soon]      │     │
│  │   Google Pay, PhonePe, Paytm                         │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ ○ 💳 Credit/Debit Card            [Coming Soon]      │     │
│  │   Visa, Mastercard, Rupay                            │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  [Continue] ──────────────────────────────────────────┐       │
└────────────────────────────────────────────────────────┼───────┘
                                                         │
                                                         ▼
┌────────────────────────────────────────────────────────────────┐
│           Order Review Screen                                  │
│                                                                 │
│  Order Items                                                   │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ [img] Blue T-Shirt                                   │     │
│  │       Qty: 2 • ₹499.00                      ₹998.00  │     │
│  └──────────────────────────────────────────────────────┘     │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ [img] Black Jeans                                    │     │
│  │       Qty: 1 • ₹1299.00                    ₹1299.00  │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  Delivery Address                                              │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ 📍 Home                                               │     │
│  │ John Doe                                              │     │
│  │ 123 Main Street, Landmark: Near Park                 │     │
│  │ Mumbai, Maharashtra - 400001                          │     │
│  │ Phone: 9876543210                                     │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  Payment Method                                                │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ 💵 Cash on Delivery                                   │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  Price Details                                                 │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ Subtotal                                   ₹2297.00  │     │
│  │ Discount                                    -₹100.00  │     │
│  │ Delivery Fee                                  ₹30.00  │     │
│  │ Taxes                                        ₹114.85  │     │
│  │ ─────────────────────────────────────────────────────│     │
│  │ Total                                      ₹2341.85  │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                                 │
│  ℹ️ Estimated delivery: 25-45 mins                             │
│     Cancellation available before pickup                       │
│                                                                 │
│  [Place Order • ₹2341.85] ────────────────────────────┐       │
└────────────────────────────────────────────────────────┼───────┘
                                                         │
                                                         ▼
                                              ┌──────────────────┐
                                              │ Order Validation │
                                              │                  │
                                              │ • Check stock    │
                                              │ • Verify prices  │
                                              │ • Serviceability │
                                              │ • Place order    │
                                              └────────┬─────────┘
                                                       │
                                                       ▼
                                              ┌──────────────────┐
                                              │ Order Success!   │
                                              │                  │
                                              │ • Clear cart     │
                                              │ • Track analytics│
                                              │ • Navigate to    │
                                              │   tracking       │
                                              └──────────────────┘
```

## Key Improvements

### 1. Separate Screens
- Each step has its own dedicated screen
- Better focus and clarity
- Easier to navigate back/forward

### 2. Auto-Location Feature
- One-click location capture
- Auto-fills city and state
- Shows GPS coordinates with accuracy
- Visual feedback when location is captured

### 3. Better Validation
- Address validation before proceeding
- Cart validation (stock, prices)
- Serviceability check
- Idempotency for duplicate prevention

### 4. Clear Price Breakdown
- Subtotal, discount, delivery, taxes
- Grand total prominently displayed
- All calculations shown transparently

### 5. Error Handling
- User-friendly error messages
- Proper navigation on errors
- Analytics tracking for debugging

## Navigation Flow

```
Cart → Checkout (Router) → Address → Payment → Review → Success
  ↑                          ↓         ↓         ↓         ↓
  └──────────────────────────┴─────────┴─────────┴─────────┘
              [Back button navigation supported]
```

## User Actions

1. **Cart Screen**: Review items, apply promo, click checkout
2. **Address Screen**: Select existing or add new address with auto-location
3. **Payment Screen**: Choose payment method (currently COD)
4. **Review Screen**: Final review and place order
5. **Success**: Navigate to order tracking

## Technical Flow

```
CheckoutScreen (Router)
    ↓
    ├─→ Check authentication
    ├─→ Navigate to AddressSelectionScreen
    │       ↓
    │       └─→ Return selected address
    ├─→ Navigate to PaymentSelectionScreen
    │       ↓
    │       └─→ Return payment method
    └─→ Navigate to OrderReviewScreen
            ↓
            ├─→ Load quote from API
            ├─→ Validate cart
            ├─→ Check serviceability
            ├─→ Place order with idempotency
            └─→ Navigate to tracking on success
```
