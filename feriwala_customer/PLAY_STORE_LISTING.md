# Google Play Store Listing - Feriwala Customer App

## App Details

- **Package Name**: `in.feriwala.customer`
- **App Name**: Feriwala
- **Developer Name**: Feriwala
- **Developer Email**: support@feriwala.in
- **Privacy Policy URL**: https://api.feriwala.in/privacy
- **Terms URL**: https://api.feriwala.in/terms
- **Category**: Shopping
- **Content Rating**: Everyone

---

## Store Listing

### Short Description (80 chars max)
Clothes delivered in minutes from local stores near you. COD & online payments.

### Full Description (4000 chars max)
Feriwala delivers clothes and footwear from local stores to your doorstep in 25-45 minutes.

🛍️ SHOP LOCAL, GET IT FAST
Browse apparel from verified local retailers near you. From casual wear to ethnic, find what you need and get it delivered in minutes — not days.

⚡ HOW IT WORKS
1. Open the app and browse products from nearby stores
2. Add items to cart and place your order
3. Our delivery partner picks items from the store
4. Receive your order at your doorstep in 25-45 minutes

💰 PAYMENT OPTIONS
• Cash on Delivery (COD)
• UPI (GPay, PhonePe, Paytm)
• Credit/Debit Cards
• Net Banking
All online payments secured by Razorpay.

📦 EASY RETURNS
• Return within 24 hours for damaged or wrong items
• Hassle-free pickup by our delivery partner
• Refund to original payment method in 5-7 days

🚚 DELIVERY
• Free delivery on orders above ₹299
• Real-time order tracking
• Live delivery partner location on map

✨ FEATURES
• Browse by category — Men, Women, Kids, Ethnic, Western, Footwear
• Real-time order status updates
• Save multiple delivery addresses
• Order history and reorder
• Deals and promotional offers
• Rate and review products

📍 Currently available in select cities. Expanding soon!

---

## Data Safety Declaration

### Data Collected

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Name | Yes | With delivery partner | Order fulfillment |
| Email | Yes | No | Account, communications |
| Phone | Yes | With delivery partner | Order fulfillment |
| Address | Yes | With delivery partner | Delivery |
| Location (foreground) | Yes | No | Find nearby stores |
| Order history | Yes | No | App functionality |
| Payment info | No (handled by Razorpay) | No | — |

### Data Handling
- Data encrypted in transit (HTTPS)
- Users can request data deletion (email privacy@feriwala.in or in-app)
- Data deletion URL: https://api.feriwala.in/delete-account

### Permissions Used
| Permission | Reason |
|-----------|--------|
| Location (foreground) | To find nearby stores and calculate delivery estimates |
| Internet | To communicate with servers |
| Notifications | To send order status updates |

---

## Required Assets Checklist

- [ ] App icon: 512x512 PNG (no transparency)
- [ ] Feature graphic: 1024x500 PNG/JPG
- [ ] Screenshots: Min 2, recommended 8 (phone: 16:9 or 9:16)
- [ ] Short description (done above)
- [ ] Full description (done above)
- [ ] Privacy policy URL: https://api.feriwala.in/privacy
- [ ] Content rating questionnaire completed
- [ ] Target audience declaration (18+)
- [ ] Data safety form filled

---

## Release Signing

### Generate Upload Keystore (one-time)
```bash
keytool -genkey -v -keystore ~/feriwala-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias feriwala-upload \
  -storepass <your-store-password> \
  -keypass <your-key-password> \
  -dname "CN=Feriwala, O=Feriwala, L=India, C=IN"
```

### Configure signing
1. Copy keystore to `android/app/feriwala-upload-key.jks`
2. Create `android/key.properties` (DO NOT commit):
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=feriwala-upload
storeFile=feriwala-upload-key.jks
```
3. The `build.gradle.kts` is already configured for release signing (see below)

### Build Release AAB (for Play Store)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## Razorpay API Application Requirements

All URLs must be live and accessible:

| Requirement | URL |
|------------|-----|
| Website/App URL | https://api.feriwala.in |
| Privacy Policy | https://api.feriwala.in/privacy |
| Terms & Conditions | https://api.feriwala.in/terms |
| Refund/Cancellation Policy | https://api.feriwala.in/refund |
| Contact Us | https://api.feriwala.in/contact |
| About Us | https://api.feriwala.in/about |

### Razorpay Application Checklist
- [ ] Business PAN card
- [ ] Business bank account details
- [ ] GSTIN (if applicable)
- [ ] Website with all policy pages live
- [ ] App on Play Store (or test link)
- [ ] Business category: E-commerce / Retail
- [ ] Expected monthly volume estimate
