const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const User = require('../models/mongo/User');
const DeliveryAgentProfile = require('../models/mongo/DeliveryAgentProfile');
const { generateTokens, generateLoginId } = require('../utils/helpers');
const { authenticate } = require('../middleware/auth');
const { isMongoReady } = require('../database/mongodb');
const jwt = require('jsonwebtoken');

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
    res.status(500).json({ success: false, message: error.message });
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

    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account is deactivated' });
    }

    const tokens = generateTokens(user._id.toString());
    user.refreshToken = tokens.refreshToken;
    user.lastLogin = new Date();
    await user.save();

    res.json({ success: true, data: { user, ...tokens } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
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
    res.status(500).json({ success: false, message: error.message });
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
    res.status(500).json({ success: false, message: error.message });
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
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
