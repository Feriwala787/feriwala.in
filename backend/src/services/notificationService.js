/**
 * Push notification service (FCM).
 *
 * TODO: Implement Firebase Cloud Messaging push notifications.
 *
 * Steps to implement:
 *  1. Install the SDK: npm install firebase-admin
 *  2. Create a Firebase project and download the service account JSON
 *  3. Add FIREBASE_SERVICE_ACCOUNT_PATH (or FIREBASE_SERVICE_ACCOUNT_JSON) to .env
 *  4. Initialise the admin SDK in initFirebase() below
 *  5. Replace the stub sendPush() with a real FCM call
 *  6. Call sendPush() from the relevant route handlers:
 *     - New order placed       → notify shop admin
 *     - Order status changed   → notify customer
 *     - Delivery task assigned → notify delivery agent
 *     - Return approved        → notify customer
 *
 * FCM tokens are stored on User.fcmToken (MongoDB).
 * Update the token via PUT /api/auth/profile with { fcmToken: "<token>" }.
 */

let _firebaseApp = null;

function initFirebase() {
  // TODO: initialise firebase-admin here
  // const admin = require('firebase-admin');
  // const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  //   ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
  //   : require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
  // _firebaseApp = admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

/**
 * Send a push notification to a single device.
 * @param {object} params
 * @param {string} params.fcmToken - Device FCM token from User.fcmToken
 * @param {string} params.title    - Notification title
 * @param {string} params.body     - Notification body
 * @param {object} [params.data]   - Optional key-value payload
 * @returns {Promise<void>}
 */
async function sendPush({ fcmToken, title, body, data = {} }) {
  if (!fcmToken) return; // silently skip if no token registered

  // TODO: replace with real FCM send
  // const admin = require('firebase-admin');
  // await admin.messaging().send({
  //   token: fcmToken,
  //   notification: { title, body },
  //   data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
  // });

  // Stub: log in development so the call sites work without crashing
  if (process.env.NODE_ENV !== 'production') {
    console.log(`[FCM stub] → ${fcmToken.slice(0, 12)}... | ${title}: ${body}`);
  }
}

module.exports = { initFirebase, sendPush };
