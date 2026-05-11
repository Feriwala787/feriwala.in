const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const User = require('../models/mongo/User');
const DeliveryAgentProfile = require('../models/mongo/DeliveryAgentProfile');
const { generateTokens, generateLoginId } = require('../utils/helpers');
const { authenticate } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const { isMongoReady } = require('../database/mongodb');
const jwt = require('jsonwebtoken');
const { sendOtpEmail } = require('../services/emailService');
const crypto = require('crypto');

function requireMongoReady(req, res, next) {
  if (!isMongoReady()) {
    res.set('Retry-After', '5');
    return res.status(503).json({
      success: false,
      message: 'Authentication service temporarily unavailable. Please retry shortly.',
    });
  }
  return next();
}

router.use(requireMongoReady);

// Register
router.post('/register', [
  body('name').trim().notEmpty().withMessage('Name is required'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('phone').trim().notEmpty().withMessage('Phone is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('role').optional().isIn(['customer', 'delivery_agent']),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { name, email, phone, password, role } = req.body;

    const existing = await User.findOne({ $or: [{ email }, { phone }] });
    if (existing) {
      return res.status(409).json({ success: false, message: 'Email or phone already registered' });
    }

    // Generate unique loginId
    let loginId = generateLoginId(name);
    let loginIdExists = await User.findOne({ loginId });
    while (loginIdExists) {
      loginId = generateLoginId(name); // Regenerate if collision occurs
      loginIdExists = await User.findOne({ loginId });
    }

    const user = new User({
      name,
      loginId,
      email,
      phone,
      passwordHash: password,
      role: role || 'customer',
    });
    await user.save();

    // Create delivery agent profile if applicable
    if (user.role === 'delivery_agent') {
      await DeliveryAgentProfile.create({ userId: user._id });
    }

    const tokens = generateTokens(user._id.toString());
    user.refreshToken = tokens.refreshToken;
    await user.save();

    res.status(201).json({
      success: true,
      data: { user, ...tokens },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// Register Shop (self-registration, pending approval)
router.post('/register-shop', [
  body('name').trim().notEmpty().withMessage('Name is required'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('phone').trim().notEmpty().withMessage('Phone is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('shopName').trim().notEmpty().withMessage('Shop name is required'),
  body('shopAddress').trim().notEmpty().withMessage('Shop address is required'),
  body('city').trim().notEmpty().withMessage('City is required'),
  body('state').trim().notEmpty().withMessage('State is required'),
  body('pincode').trim().notEmpty().withMessage('Pincode is required'),
  body('businessType').trim().notEmpty().withMessage('Business type is required'),
  body('gstNumber').optional().trim(),
  body('openingTime').optional().trim(),
  body('closingTime').optional().trim(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { name, email, phone, password, shopName, shopAddress, city, state, pincode, businessType, gstNumber, openingTime, closingTime } = req.body;

    const existing = await User.findOne({ $or: [{ email }, { phone }] });
    if (existing) return res.status(409).json({ success: false, message: 'Email or phone already registered' });

    let loginId = generateLoginId(name);
    while (await User.findOne({ loginId })) loginId = generateLoginId(name);

    const user = await User.create({
      name, loginId, email, phone,
      passwordHash: password,
      role: 'shop_admin',
      isActive: false,
      isVerified: false,
      approvalStatus: 'pending',
      registrationData: { shopName, shopAddress, city, state, pincode, businessType, gstNumber: gstNumber || null, openingTime: openingTime || '09:00', closingTime: closingTime || '21:00' },
    });

    res.status(201).json({ success: true, message: 'Registration submitted. You will be notified once approved by admin.' });
  } catch (error) {
    routeError(res, error);
  }
});

// Register Delivery Agent (self-registration, pending approval)
router.post('/register-delivery', [
  body('name').trim().notEmpty().withMessage('Name is required'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('phone').trim().notEmpty().withMessage('Phone is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
  body('licenseNumber').trim().notEmpty().withMessage('License number is required'),
  body('vehicleType').isIn(['bike', 'scooter', 'bicycle', 'walk']).withMessage('Valid vehicle type required'),
  body('vehicleNumber').optional().trim(),
  body('aadharNumber').trim().notEmpty().withMessage('Aadhar number is required'),
  body('emergencyContact').trim().notEmpty().withMessage('Emergency contact is required'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { name, email, phone, password, licenseNumber, vehicleType, vehicleNumber, aadharNumber, emergencyContact } = req.body;

    const existing = await User.findOne({ $or: [{ email }, { phone }] });
    if (existing) return res.status(409).json({ success: false, message: 'Email or phone already registered' });

    let loginId = generateLoginId(name);
    while (await User.findOne({ loginId })) loginId = generateLoginId(name);

    const user = await User.create({
      name, loginId, email, phone,
      passwordHash: password,
      role: 'delivery_agent',
      isActive: false,
      isVerified: false,
      approvalStatus: 'pending',
      registrationData: { licenseNumber, vehicleType, vehicleNumber: vehicleNumber || null, aadharNumber, emergencyContact },
    });

    await DeliveryAgentProfile.create({ userId: user._id, vehicleType });

    res.status(201).json({ success: true, message: 'Registration submitted. You will be notified once approved by admin.' });
  } catch (error) {
    routeError(res, error);
  }
});

// Login
router.post('/login', [
  body('credential').notEmpty().withMessage('Email, phone, or login ID required'),
  body('password').notEmpty().withMessage('Password required'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { credential, password } = req.body;
    
    // Find user by email, phone, or loginId
    const user = await User.findOne({ 
      $or: [
        { email: credential.toLowerCase() },
        { phone: credential },
        { loginId: credential.toLowerCase() }
      ]
    });

    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ success: false, message: 'Invalid credentials' });
    }

    if (user.approvalStatus === 'pending') {
      return res.status(403).json({ success: false, message: 'Your account is pending admin approval. Please wait.' });
    }
    if (user.approvalStatus === 'rejected') {
      return res.status(403).json({ success: false, message: `Your registration was rejected. Reason: ${user.rejectionReason || 'Contact support.'}` });
    }
    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account is deactivated' });
    }

    const tokens = generateTokens(user._id.toString());
    user.refreshToken = tokens.refreshToken;
    user.lastLogin = new Date();
    await user.save();

    res.json({ success: true, data: { user, ...tokens } });
  } catch (error) {
    routeError(res, error);
  }
});

// Refresh Token
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ success: false, message: 'Refresh token required' });
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    const user = await User.findById(decoded.userId);

    if (!user || user.refreshToken !== refreshToken) {
      return res.status(401).json({ success: false, message: 'Invalid refresh token' });
    }

    const tokens = generateTokens(user._id.toString());
    user.refreshToken = tokens.refreshToken;
    await user.save();

    res.json({ success: true, data: tokens });
  } catch (error) {
    res.status(401).json({ success: false, message: 'Invalid refresh token' });
  }
});

// Get Profile
router.get('/profile', authenticate, async (req, res) => {
  res.json({ success: true, data: req.user });
});

// Update Profile
router.put('/profile', authenticate, [
  body('name').optional().trim().notEmpty(),
  body('phone').optional().trim().notEmpty(),
], async (req, res) => {
  try {
    const { name, phone, avatar, fcmToken } = req.body;
    const updates = {};
    if (name) updates.name = name;
    if (phone) updates.phone = phone;
    if (avatar) updates.avatar = avatar;
    if (fcmToken) updates.fcmToken = fcmToken;

    const user = await User.findByIdAndUpdate(req.user._id, updates, { new: true });
    res.json({ success: true, data: user });
  } catch (error) {
    routeError(res, error);
  }
});

// Add Address
router.post('/addresses', authenticate, [
  body('addressLine1').trim().notEmpty(),
  body('city').trim().notEmpty(),
  body('state').trim().notEmpty(),
  body('pincode').trim().notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const user = await User.findById(req.user._id);
    if (req.body.isDefault) {
      user.addresses.forEach(addr => { addr.isDefault = false; });
    }
    user.addresses.push(req.body);
    await user.save();
    res.json({ success: true, data: user.addresses });
  } catch (error) {
    routeError(res, error);
  }
});

// Logout
router.post('/logout', authenticate, async (req, res) => {
  try {
    req.user.refreshToken = null;
    req.user.fcmToken = null;
    await req.user.save();
    res.json({ success: true, message: 'Logged out' });
  } catch (error) {
    routeError(res, error);
  }
});

// Forgot Password — send OTP
router.post('/forgot-password', [
  body('email').isEmail().normalizeEmail(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { email } = req.body;
    const user = await User.findOne({ email });
    // Always return success to prevent email enumeration
    if (!user) return res.json({ success: true, message: 'If that email exists, an OTP has been sent.' });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
    user.passwordResetOtp = otpHash;
    user.passwordResetOtpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 min
    await user.save();

    await sendOtpEmail({ to: email, otp, name: user.name });
    res.json({ success: true, message: 'If that email exists, an OTP has been sent.' });
  } catch (error) {
    routeError(res, error);
  }
});

// Reset Password — verify OTP and set new password
router.post('/reset-password', [
  body('email').isEmail().normalizeEmail(),
  body('otp').isLength({ min: 6, max: 6 }),
  body('newPassword').isLength({ min: 6 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { email, otp, newPassword } = req.body;
    const user = await User.findOne({ email });
    if (!user || !user.passwordResetOtp || !user.passwordResetOtpExpiry) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP' });
    }

    if (user.passwordResetOtpExpiry < new Date()) {
      return res.status(400).json({ success: false, message: 'OTP has expired. Please request a new one.' });
    }

    const otpHash = crypto.createHash('sha256').update(otp).digest('hex');
    if (otpHash !== user.passwordResetOtp) {
      return res.status(400).json({ success: false, message: 'Incorrect OTP' });
    }

    user.passwordHash = newPassword;
    user.passwordResetOtp = null;
    user.passwordResetOtpExpiry = null;
    user.refreshToken = null; // Invalidate all sessions
    await user.save();

    res.json({ success: true, message: 'Password reset successfully. Please login.' });
  } catch (error) {
    routeError(res, error);
  }
});

// Reset Password via Phone (after Appwrite OTP verified on client)
router.post('/reset-password-phone', [
  body('phone').trim().notEmpty(),
  body('newPassword').isLength({ min: 6 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { phone, newPassword } = req.body;
    const cleanPhone = phone.replace(/^\+91/, '').trim();
    const user = await User.findOne({ $or: [{ phone: cleanPhone }, { phone }] });
    if (!user) {
      return res.status(404).json({ success: false, message: 'No account found with this phone number' });
    }

    user.passwordHash = newPassword;
    user.refreshToken = null;
    await user.save();

    res.json({ success: true, message: 'Password reset successfully. Please login.' });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
