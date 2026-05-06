# Quick Start Guide - Customer App Updates

## What Changed?

### 🏠 Home Screen
- Shows 3+ rows of products initially (was showing less)
- Category sections now open in separate pages (cleaner UI)
- Removed tag filters (kept only product type filters)
- Better product grid layout

### 🛒 Checkout Flow
- **NEW**: Separate screen for address selection
- **NEW**: Auto-location capture in address form
- **NEW**: Separate screen for payment selection
- **NEW**: Dedicated order review screen
- **FIXED**: Order placement now works correctly
- **IMPROVED**: Better error handling throughout

---

## Files Added (4 new screens)

```
lib/screens/
├── category_products_screen.dart      # Category product listing
├── address_selection_screen.dart      # Address selection/addition
├── payment_selection_screen.dart      # Payment method selection
└── order_review_screen.dart           # Final order review
```

---

## Files Modified

```
lib/screens/
├── home_screen.dart                   # UI improvements
└── checkout_screen.dart               # Simplified to router

lib/
└── main.dart                          # Added new routes
```

---

## Quick Build & Test

### 1. Install Dependencies
```bash
cd feriwala_customer
flutter pub get
```

### 2. Run in Debug Mode
```bash
flutter run
```

### 3. Build APK
```bash
# Debug APK
flutter build apk

# Release APK
flutter build apk --release
```

### 4. Install on Device
```bash
# Debug APK location
build/app/outputs/flutter-apk/app-debug.apk

# Release APK location
build/app/outputs/flutter-apk/app-release.apk
```

---

## Testing the Changes

### Test Home Screen
1. Open app → Home screen
2. Verify 3+ rows of products visible
3. Click "See all" on any category → Opens new screen
4. Verify product type filters work
5. Test pagination with "Load more"

### Test Checkout Flow
1. Add items to cart
2. Click "Checkout"
3. **Address Screen**: Select or add address
4. **Add Address**: Click "Use Current Location"
5. **Payment Screen**: Select payment method
6. **Review Screen**: Verify all details
7. Click "Place Order"
8. Verify order places successfully

---

## Key Features to Demo

### 1. Auto-Location in Address Form
```
1. Click "Add New Address"
2. Click "Use Current Location" button
3. Grant location permission
4. GPS coordinates captured automatically
5. City and state auto-filled
6. Location accuracy displayed
```

### 2. Category Navigation
```
1. Scroll to any category section (e.g., "Party Wear")
2. Click "See all" arrow
3. Opens dedicated category page
4. Shows filtered products
5. Back button returns to home
```

### 3. Multi-Step Checkout
```
Cart → Address → Payment → Review → Success
  ↑                                    ↓
  └────────────────────────────────────┘
         (Back navigation supported)
```

---

## API Endpoints Used

### Checkout Flow
- `GET /products` - Fetch products
- `GET /shops` - Fetch nearby shops
- `POST /auth/addresses` - Save new address
- `POST /orders/quote` - Get price quote
- `POST /orders/serviceability` - Check delivery
- `POST /orders` - Place order

### Required Headers
- `Authorization: Bearer <token>` - For authenticated requests
- `Idempotency-Key: <unique-id>` - For order placement

---

## Environment Variables

```dart
// lib/config/app_config.dart
static const String apiBaseUrl = 'https://api.feriwala.in/api';
static const String socketUrl = 'https://api.feriwala.in';
```

---

## Common Issues & Solutions

### Issue: Location not capturing
**Solution:** 
- Check location permissions in device settings
- Ensure GPS is enabled
- Try in open area for better accuracy

### Issue: Order not placing
**Solution:**
- Check network connection
- Verify backend API is running
- Check console logs for errors
- Ensure cart has valid items

### Issue: Products not loading
**Solution:**
- Check API endpoint is accessible
- Verify authentication token
- Check network connectivity

### Issue: Build fails
**Solution:**
```bash
flutter clean
flutter pub get
flutter build apk
```

---

## Code Structure

### Home Screen Flow
```dart
HomeScreen
  ├─ Gender Tabs (Men/Women/Kids)
  ├─ Product Type Chips (T-Shirt, Jeans, etc.)
  ├─ Category Sections (Recently Viewed, Party Wear, etc.)
  │   └─ "See all" → CategoryProductsScreen
  └─ Product Grid (2 columns, paginated)
```

### Checkout Flow
```dart
CheckoutScreen (Router)
  ├─ Check authentication
  ├─ AddressSelectionScreen
  │   ├─ Display saved addresses
  │   └─ Add new address (with auto-location)
  ├─ PaymentSelectionScreen
  │   └─ Select payment method
  └─ OrderReviewScreen
      ├─ Show order summary
      ├─ Validate cart
      ├─ Check serviceability
      └─ Place order
```

---

## Analytics Events

The following events are tracked:

```dart
// Checkout flow
'begin_checkout'
'checkout_step_continue'
'place_order_attempt'
'place_order_success'
'place_order_failed'
'place_order_blocked_validation'

// Cart
'add_to_cart'
```

---

## Next Steps

### Immediate
1. ✅ Test on physical device
2. ✅ Verify all checkout scenarios
3. ✅ Test location permissions
4. ✅ Validate order placement

### Short-term
1. Integrate reverse geocoding (AWS Location Service)
2. Add address edit/delete functionality
3. Implement UPI payment gateway
4. Add order cancellation

### Long-term
1. Add product reviews
2. Implement wishlist
3. Add push notifications
4. Optimize performance

---

## Documentation

- **Full Changes**: See `IMPROVEMENTS_SUMMARY.md`
- **Flow Diagram**: See `CHECKOUT_FLOW_DIAGRAM.md`
- **Testing**: See `TESTING_CHECKLIST.md`
- **Deployment**: See `../deployment/LIGHTSAIL_DEPLOYMENT.md`

---

## Support

For issues or questions:
1. Check console logs for errors
2. Review API responses in network tab
3. Verify backend is running
4. Check device permissions

---

## GitHub Actions

The CI/CD pipeline will automatically:
- Build debug APKs on push
- Run tests
- Create artifacts for download

Trigger manually:
```
Actions → Build Android APKs → Run workflow
```

---

## Success Criteria

✅ Home screen shows 3+ rows of products  
✅ Category sections navigate to separate pages  
✅ Product type filters work correctly  
✅ Address selection screen functional  
✅ Auto-location captures GPS coordinates  
✅ Payment selection screen functional  
✅ Order review shows complete summary  
✅ Order placement works end-to-end  
✅ Cart clears after successful order  
✅ Navigation to order tracking works  

---

## Version Info

**Updated:** January 2025  
**Flutter SDK:** >=3.0.0 <4.0.0  
**Target:** Android  
**Min SDK:** 21  
**Target SDK:** 34  

---

## Quick Commands

```bash
# Run app
flutter run

# Build debug APK
flutter build apk

# Build release APK
flutter build apk --release

# Analyze code
flutter analyze

# Run tests
flutter test

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Check outdated packages
flutter pub outdated
```

---

**Ready to test!** 🚀
