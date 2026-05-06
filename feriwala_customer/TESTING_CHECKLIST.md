# Testing Checklist - Customer App Improvements

## Pre-Testing Setup
- [ ] Build and install the latest APK on Android device
- [ ] Ensure device has location services enabled
- [ ] Grant location permissions to the app
- [ ] Have test account credentials ready
- [ ] Ensure backend API is running and accessible

---

## 1. Home Screen Testing

### Initial Load
- [ ] App opens successfully
- [ ] Home screen displays without errors
- [ ] At least 3 rows (6 products) are visible initially
- [ ] Product images load correctly
- [ ] Product prices and names display properly

### Gender Tabs
- [ ] Men tab is selected by default
- [ ] Clicking Women tab loads women's products
- [ ] Clicking Kids tab loads kids' products
- [ ] Tab selection is visually indicated

### Product Type Filter
- [ ] "All" chip is selected by default
- [ ] Clicking T-Shirt filter shows only T-shirts
- [ ] Clicking Jeans filter shows only jeans
- [ ] Other product type filters work correctly
- [ ] Filter selection is visually indicated
- [ ] Products reload when filter changes

### Category Sections
- [ ] "Recently Viewed" section appears (if applicable)
- [ ] "Picked for You" section appears
- [ ] "Party Wear" section appears with products
- [ ] "Casual Wear" section appears with products
- [ ] "Gym Wear" section appears with products
- [ ] Other category sections display correctly

### Category Navigation
- [ ] Clicking "See all" on any category opens new screen
- [ ] Category products screen shows correct title
- [ ] Category products screen shows filtered products
- [ ] Back button returns to home screen
- [ ] Products in category screen are clickable

### Product Grid
- [ ] Products display in 2-column grid
- [ ] Product cards show image, name, price
- [ ] Discount percentage shows (if applicable)
- [ ] Brand name shows (if available)
- [ ] Clicking product card opens product detail

### Pagination
- [ ] "Load more" button appears at bottom
- [ ] Clicking "Load more" loads next page
- [ ] Loading indicator shows during fetch
- [ ] New products append to existing list
- [ ] Button disappears when no more products

### Search
- [ ] Clicking search icon shows search field
- [ ] Typing in search filters products
- [ ] Search results update after typing stops
- [ ] Closing search clears results
- [ ] Search works with product names

### Cart Badge
- [ ] Cart icon shows item count badge
- [ ] Badge updates when items added
- [ ] Clicking cart icon navigates to cart

### Pull to Refresh
- [ ] Pulling down refreshes home feed
- [ ] Loading indicator shows during refresh
- [ ] Products reload after refresh

---

## 2. Checkout Flow Testing

### Cart Screen
- [ ] Cart displays all added items
- [ ] Item images, names, prices show correctly
- [ ] Quantity controls work (+ and -)
- [ ] Removing item (quantity to 0) works
- [ ] "Save for later" moves item correctly
- [ ] Promo code input field present
- [ ] Applying valid promo code works
- [ ] Applying invalid promo code shows error
- [ ] Subtotal calculates correctly
- [ ] Delivery fee shows (₹30)
- [ ] Taxes calculate correctly (5%)
- [ ] Total amount is correct
- [ ] "Checkout" button is visible and enabled

### Checkout Initiation
- [ ] Clicking "Checkout" from cart works
- [ ] If not logged in, redirects to login
- [ ] If logged in, proceeds to address selection
- [ ] Loading indicator shows briefly

### Address Selection Screen
- [ ] Screen opens successfully
- [ ] All saved addresses display
- [ ] Address cards show complete information
- [ ] Radio buttons work for selection
- [ ] Selected address is highlighted
- [ ] "Add New Address" button is visible

### Add New Address
- [ ] Clicking "Add New Address" opens dialog
- [ ] Address type dropdown works (Home/Work/Other)
- [ ] "Use Current Location" button is visible
- [ ] Clicking location button requests permission
- [ ] Location permission granted successfully
- [ ] GPS coordinates captured and displayed
- [ ] City and state auto-fill (placeholder)
- [ ] Location accuracy shows
- [ ] All form fields are present
- [ ] Form validation works (required fields)
- [ ] Phone number validation (10 digits)
- [ ] Pincode validation (6 digits)
- [ ] "Set as default" toggle works
- [ ] "Cancel" button closes dialog
- [ ] "Save" button validates and saves
- [ ] New address appears in list
- [ ] Success message shows after save

### Address Selection Continuation
- [ ] Selecting address enables "Deliver Here"
- [ ] Clicking "Deliver Here" proceeds to payment
- [ ] Back button returns to cart

### Payment Selection Screen
- [ ] Screen opens successfully
- [ ] Cash on Delivery option is available
- [ ] COD is selected by default
- [ ] UPI shows "Coming Soon" badge
- [ ] Card shows "Coming Soon" badge
- [ ] Net Banking shows "Coming Soon"
- [ ] Radio selection works
- [ ] "Continue" button is enabled
- [ ] Clicking "Continue" proceeds to review
- [ ] Back button returns to address selection

### Order Review Screen
- [ ] Screen opens successfully
- [ ] Loading indicator shows while fetching quote
- [ ] All cart items display with images
- [ ] Item quantities and prices correct
- [ ] Selected address displays completely
- [ ] Address label shows (Home/Work/Other)
- [ ] Payment method shows correctly
- [ ] Price breakdown section present
- [ ] Subtotal matches cart
- [ ] Discount shows (if promo applied)
- [ ] Delivery fee shows (₹30)
- [ ] Taxes calculate correctly
- [ ] Grand total is correct
- [ ] Delivery estimate shows (25-45 mins)
- [ ] Cancellation policy shows
- [ ] "Place Order" button shows total
- [ ] Back button returns to payment selection

### Order Placement
- [ ] Clicking "Place Order" shows loading
- [ ] Serviceability check runs
- [ ] Cart validation runs (stock, prices)
- [ ] Order places successfully
- [ ] Success message/navigation occurs
- [ ] Cart clears after successful order
- [ ] Navigates to order tracking screen
- [ ] Order ID is passed correctly

### Error Scenarios
- [ ] Out of stock item shows error
- [ ] Price change shows error
- [ ] Invalid address shows error
- [ ] Network error shows user-friendly message
- [ ] Duplicate order prevented (idempotency)
- [ ] Cart not cleared on error

---

## 3. Edge Cases & Error Handling

### Location Permissions
- [ ] Permission denied shows appropriate message
- [ ] Permission permanently denied shows settings prompt
- [ ] Manual address entry works without location
- [ ] Location timeout handled gracefully

### Network Issues
- [ ] Offline mode shows error message
- [ ] Slow network shows loading indicators
- [ ] API errors show user-friendly messages
- [ ] Retry mechanism works

### Empty States
- [ ] Empty cart shows appropriate message
- [ ] No addresses shows "Add Address" prompt
- [ ] No products shows appropriate message
- [ ] No search results shows message

### Validation
- [ ] Invalid phone number rejected
- [ ] Invalid pincode rejected
- [ ] Empty required fields rejected
- [ ] Form shows validation errors clearly

### Navigation
- [ ] Back button works on all screens
- [ ] App doesn't crash on back navigation
- [ ] State preserved on back navigation
- [ ] Deep linking works (if applicable)

---

## 4. Performance Testing

### Load Times
- [ ] Home screen loads within 2 seconds
- [ ] Product images load progressively
- [ ] Category navigation is instant
- [ ] Checkout flow is smooth

### Memory
- [ ] No memory leaks during navigation
- [ ] App doesn't crash with many products
- [ ] Images cached properly

### Responsiveness
- [ ] UI responds immediately to taps
- [ ] No lag during scrolling
- [ ] Animations are smooth

---

## 5. Visual/UI Testing

### Layout
- [ ] All screens display correctly on device
- [ ] No text overflow or truncation
- [ ] Images aspect ratios correct
- [ ] Spacing and padding consistent
- [ ] Colors match brand (orange #F47721)

### Accessibility
- [ ] Text is readable (font sizes)
- [ ] Buttons are tappable (min 48dp)
- [ ] Color contrast is sufficient
- [ ] Icons are clear and recognizable

### Responsive Design
- [ ] Works on different screen sizes
- [ ] Portrait orientation works
- [ ] Landscape orientation works (if supported)

---

## 6. Integration Testing

### Cart Integration
- [ ] Adding product from detail updates cart
- [ ] Cart persists across app restarts
- [ ] Cart syncs with backend (if applicable)

### Authentication
- [ ] Login required for checkout
- [ ] Session persists correctly
- [ ] Logout clears sensitive data

### Analytics
- [ ] Events tracked correctly
- [ ] Checkout funnel tracked
- [ ] Error events logged

---

## 7. Regression Testing

### Existing Features
- [ ] Product detail screen still works
- [ ] Orders screen still works
- [ ] Profile screen still works
- [ ] Order tracking still works
- [ ] Login/Register still works

### Data Persistence
- [ ] Cart persists across sessions
- [ ] Recent products persist
- [ ] User preferences persist

---

## Test Results Summary

| Category | Pass | Fail | Notes |
|----------|------|------|-------|
| Home Screen | __ / __ | __ | |
| Checkout Flow | __ / __ | __ | |
| Edge Cases | __ / __ | __ | |
| Performance | __ / __ | __ | |
| Visual/UI | __ / __ | __ | |
| Integration | __ / __ | __ | |
| Regression | __ / __ | __ | |

**Total: __ / __ tests passed**

---

## Critical Issues Found
1. 
2. 
3. 

## Minor Issues Found
1. 
2. 
3. 

## Recommendations
1. 
2. 
3. 

---

## Sign-off

**Tested by:** ___________________  
**Date:** ___________________  
**Device:** ___________________  
**OS Version:** ___________________  
**App Version:** ___________________  

**Status:** [ ] Approved [ ] Needs Fixes [ ] Rejected
