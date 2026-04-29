/**
 * Payment gateway integration.
 *
 * TODO: Integrate a payment gateway (e.g. Razorpay, Stripe) here.
 *
 * Steps to implement:
 *  1. Install the SDK: npm install razorpay   (or stripe)
 *  2. Add RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET to .env
 *  3. Replace the stub functions below with real API calls
 *  4. Wire createOrder() into POST /api/orders for non-COD payments
 *  5. Wire verifyPayment() into a new POST /api/orders/:id/verify-payment route
 *  6. Update Order.paymentStatus to 'paid' on successful verification
 */

/**
 * Create a payment order with the gateway.
 * @param {object} params
 * @param {number} params.amount - Amount in paise (INR × 100)
 * @param {string} params.currency - e.g. 'INR'
 * @param {string} params.receipt - Internal order reference
 * @returns {Promise<{gatewayOrderId: string, amount: number, currency: string}>}
 */
async function createPaymentOrder({ amount, currency = 'INR', receipt }) {
  // TODO: replace with real gateway call
  throw new Error('Payment gateway not configured. Only COD orders are supported currently.');
}

/**
 * Verify a payment callback from the gateway.
 * @param {object} params
 * @param {string} params.gatewayOrderId
 * @param {string} params.gatewayPaymentId
 * @param {string} params.signature
 * @returns {Promise<boolean>} true if signature is valid
 */
async function verifyPayment({ gatewayOrderId, gatewayPaymentId, signature }) {
  // TODO: replace with real signature verification
  throw new Error('Payment gateway not configured.');
}

module.exports = { createPaymentOrder, verifyPayment };
