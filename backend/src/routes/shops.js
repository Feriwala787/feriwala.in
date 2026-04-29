const router = require('express').Router();
const { body, query, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const Shop = require('../models/pg/Shop');
const { Op } = require('sequelize');

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
