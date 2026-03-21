const jwt = require('jsonwebtoken');

function generateTokens(userId) {
  const accessToken = jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );

  const refreshToken = jwt.sign(
    { userId },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d' }
  );

  return { accessToken, refreshToken };
}

function generateOrderNumber() {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `FW-${timestamp}-${random}`;
}

function generateInvoiceNumber(shopCode) {
  const date = new Date();
  const y = date.getFullYear().toString().slice(-2);
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const random = Math.random().toString(36).substring(2, 7).toUpperCase();
  return `INV-${shopCode}-${y}${m}-${random}`;
}

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function generateLoginId(name) {
  // Create base from name: convert to lowercase, remove spaces, remove special chars
  const baseId = name
    .toLowerCase()
    .replace(/\s+/g, '') // remove spaces
    .replace(/[^a-z0-9]/g, '') // keep only alphanumeric
    .substring(0, 12); // limit to 12 chars
  
  // Add random suffix for uniqueness
  const randomSuffix = Math.random().toString(36).substring(2, 6);
  return `${baseId}${randomSuffix}`;
}

module.exports = {
  generateTokens,
  generateOrderNumber,
  generateInvoiceNumber,
  generateOtp,
  calculateDistance,
  generateLoginId,
};
