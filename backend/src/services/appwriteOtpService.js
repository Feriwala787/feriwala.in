const axios = require('axios');

const APPWRITE_ENDPOINT = process.env.APPWRITE_ENDPOINT || 'https://tor.cloud.appwrite.io/v1';
const APPWRITE_PROJECT_ID = process.env.APPWRITE_PROJECT_ID || '6a022ea60030dfa3545e';
const APPWRITE_API_KEY = process.env.APPWRITE_API_KEY || '';

const headers = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': APPWRITE_API_KEY,
};

/**
 * Send SMS OTP to phone number via Appwrite Phone auth.
 * @param {string} phone - E.164 format e.g. +919876543210
 * @returns {{ success: boolean, userId?: string, error?: string }}
 */
async function sendPhoneOtp(phone) {
  try {
    const res = await axios.post(
      `${APPWRITE_ENDPOINT}/users/create-token`,
      { userId: 'unique()', phone },
      { headers }
    );
    return { success: true, userId: res.data.userId || res.data.$id };
  } catch (error) {
    // Fallback: try the account tokens endpoint (client-style)
    try {
      const res2 = await axios.post(
        `${APPWRITE_ENDPOINT}/account/tokens/phone`,
        { userId: 'unique()', phone },
        { headers: { 'Content-Type': 'application/json', 'X-Appwrite-Project': APPWRITE_PROJECT_ID } }
      );
      return { success: true, userId: res2.data.userId || res2.data.$id };
    } catch (err2) {
      const msg = err2.response?.data?.message || error.response?.data?.message || error.message;
      return { success: false, error: msg };
    }
  }
}

/**
 * Verify SMS OTP code.
 * @param {string} userId - User ID from sendPhoneOtp
 * @param {string} otp - 6-digit code
 * @returns {{ success: boolean, error?: string }}
 */
async function verifyPhoneOtp(userId, otp) {
  try {
    await axios.put(
      `${APPWRITE_ENDPOINT}/account/sessions/phone`,
      { userId, secret: otp },
      { headers: { 'Content-Type': 'application/json', 'X-Appwrite-Project': APPWRITE_PROJECT_ID } }
    );
    return { success: true };
  } catch (error) {
    const msg = error.response?.data?.message || error.message;
    return { success: false, error: msg };
  }
}

module.exports = { sendPhoneOtp, verifyPhoneOtp };
