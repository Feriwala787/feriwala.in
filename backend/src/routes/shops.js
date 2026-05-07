const router = require('express').Router();
const { body, query, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const Shop = require('../models/pg/Shop');
const { Op } = require('sequelize');

// Seed shop location from GPS (shop admin only — must be physically at the shop)
router.put('/my/seed-location', authenticate, authorize('shop_admin'), [
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Valid latitude required'),
  body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Valid longitude required'),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    if (!req.user.shopId) return res.status(400).json({ success: false, message: 'No shop assigned to your account' });

    const shop = await Shop.findByPk(req.user.shopId);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });

    await shop.update({
      latitude: req.body.latitude,
      longitude: req.body.longitude,
      isActive: true, // activate shop once location is set
    });

    res.json({ success: true, message: 'Shop location saved. Your shop is now active!', data: shop });
  } catch (error) {
    routeError(res, error);
  }
});

// Get my shop (shop admin)
router.get('/my/shop', authenticate, authorize('shop_admin'), async (req, res) => {
  try {
    if (!req.user.shopId) return res.status(404).json({ success: false, message: 'No shop assigned' });
    const shop = await Shop.findByPk(req.user.shopId);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });
    res.json({ success: true, data: shop });
  } catch (error) {
    routeError(res, error);
  }
});

// Get all shops (public - for customers)
router.get('/', async (req, res) => {
  try {
    const { city, lat, lng, radius, page = 1, limit = 20 } = req.query;
    const where = { isActive: true };

    if (city) where.city = { [Op.iLike]: `%${city}%` };

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const shops = await Shop.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order: [['rating', 'DESC']],
    });

    res.json({
      success: true,
      data: shops.rows,
      pagination: {
        total: shops.count,
        page: parseInt(page),
        pages: Math.ceil(shops.count / parseInt(limit)),
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// Get shop by ID
router.get('/:id', async (req, res) => {
  try {
    const shop = await Shop.findByPk(req.params.id);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });
    res.json({ success: true, data: shop });
  } catch (error) {
    routeError(res, error);
  }
});

// Update shop (shop admin only)
router.put('/:id', authenticate, authorize('shop_admin', 'admin'), [
  body('name').optional().trim().notEmpty(),
  body('phone').optional().trim(),
  body('deliveryRadiusKm').optional().isFloat({ min: 0.5 }),
], async (req, res) => {
  try {
    const shop = await Shop.findByPk(req.params.id);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });

    if (req.user.role === 'shop_admin' && req.user.shopId !== shop.id) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const allowedFields = [
      'name', 'description', 'phone', 'email', 'coverImage', 'logo',
      'openingTime', 'closingTime', 'deliveryRadiusKm', 'minOrderAmount', 'deliveryFee',
    ];

    const updates = {};
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    });

    await shop.update(updates);
    res.json({ success: true, data: shop });
  } catch (error) {
    routeError(res, error);
  }
});

// Get shop dashboard stats (shop admin)
router.get('/:id/stats', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const Order = require('../models/pg/Order');
    const Product = require('../models/pg/Product');
    const shopId = parseInt(req.params.id);

    if (req.user.role === 'shop_admin' && req.user.shopId !== shopId) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [totalOrders, todayOrders, totalProducts, pendingOrders] = await Promise.all([
      Order.count({ where: { shopId } }),
      Order.count({ where: { shopId, createdAt: { [Op.gte]: today } } }),
      Product.count({ where: { shopId, isActive: true } }),
      Order.count({ where: { shopId, status: 'pending' } }),
    ]);

    res.json({
      success: true,
      data: { totalOrders, todayOrders, totalProducts, pendingOrders },
    });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
