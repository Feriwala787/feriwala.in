const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const PromoCode = require('../models/pg/PromoCode');
const Order = require('../models/pg/Order');
const { Op } = require('sequelize');

// Get available promos for a shop (public)
router.get('/shop/:shopId', async (req, res) => {
  try {
    const now = new Date();
    const promos = await PromoCode.findAll({
      where: {
        shopId: parseInt(req.params.shopId),
        isActive: true,
        validFrom: { [Op.lte]: now },
        validTo: { [Op.gte]: now },
      },
      attributes: ['id', 'code', 'description', 'discountType', 'discountValue', 'minOrderAmount', 'maxDiscount', 'validTo', 'firstOrderOnly'],
    });
    res.json({ success: true, data: promos });
  } catch (error) {
    routeError(res, error);
  }
});

// Create promo code (shop admin)
router.post('/', authenticate, authorize('shop_admin', 'admin'), [
  body('code').trim().notEmpty().isLength({ max: 30 }),
  body('discountType').isIn(['percentage', 'flat']),
  body('discountValue').isFloat({ min: 0 }),
  body('validFrom').isISO8601(),
  body('validTo').isISO8601(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const shopId = req.user.shopId;
    if (!shopId) return res.status(400).json({ success: false, message: 'No shop assigned' });

    const existing = await PromoCode.findOne({
      where: { shopId, code: req.body.code.toUpperCase() },
    });
    if (existing) {
      return res.status(409).json({ success: false, message: 'Promo code already exists for this shop' });
    }

    const promo = await PromoCode.create({
      ...req.body,
      code: req.body.code.toUpperCase(),
      shopId,
    });

    res.status(201).json({ success: true, data: promo });
  } catch (error) {
    routeError(res, error);
  }
});

// Update promo code
router.put('/:id', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const promo = await PromoCode.findByPk(req.params.id);
    if (!promo) return res.status(404).json({ success: false, message: 'Promo not found' });

    if (req.user.role === 'shop_admin' && req.user.shopId !== promo.shopId) {
      return res.status(403).json({ success: false, message: 'Not your promo code' });
    }

    const allowedFields = [
      'description', 'discountType', 'discountValue', 'minOrderAmount',
      'maxDiscount', 'usageLimit', 'perUserLimit', 'validFrom', 'validTo',
      'isActive', 'applicableCategories', 'firstOrderOnly',
    ];

    const updates = {};
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    });

    await promo.update(updates);
    res.json({ success: true, data: promo });
  } catch (error) {
    routeError(res, error);
  }
});

// Delete promo code
router.delete('/:id', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const promo = await PromoCode.findByPk(req.params.id);
    if (!promo) return res.status(404).json({ success: false, message: 'Promo not found' });

    if (req.user.role === 'shop_admin' && req.user.shopId !== promo.shopId) {
      return res.status(403).json({ success: false, message: 'Not your promo code' });
    }

    await promo.update({ isActive: false });
    res.json({ success: true, message: 'Promo code deactivated' });
  } catch (error) {
    routeError(res, error);
  }
});

// Validate promo code
router.post('/validate', authenticate, [
  body('code').trim().notEmpty(),
  body('shopId').isInt(),
  body('orderAmount').isFloat({ min: 0 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { code, shopId, orderAmount } = req.body;
    const now = new Date();

    const promo = await PromoCode.findOne({
      where: {
        shopId: parseInt(shopId),
        code: code.toUpperCase(),
        isActive: true,
        validFrom: { [Op.lte]: now },
        validTo: { [Op.gte]: now },
      },
    });

    if (!promo) {
      return res.status(404).json({ success: false, message: 'Invalid or expired promo code' });
    }

    if (orderAmount < promo.minOrderAmount) {
      return res.status(400).json({
        success: false,
        message: `Minimum order amount is ₹${promo.minOrderAmount}`,
      });
    }

    if (promo.usageLimit !== null && promo.usedCount >= promo.usageLimit) {
      return res.status(400).json({ success: false, message: 'Promo code usage limit reached' });
    }


    if (promo.perUserLimit !== null) {
      const userUsageCount = await Order.count({
        where: {
          customerId: req.user._id.toString(),
          promoCodeId: promo.id,
          status: { [Op.notIn]: ['cancelled'] },
        },
      });
      if (userUsageCount >= promo.perUserLimit) {
        return res.status(400).json({ success: false, message: 'Per-user promo usage limit reached' });
      }
    }


    if (promo.firstOrderOnly) {
      const priorOrders = await Order.count({
        where: {
          customerId: req.user._id.toString(),
          shopId: parseInt(shopId),
          status: { [Op.notIn]: ['cancelled'] },
        },
      });
      if (priorOrders > 0) {
        return res.status(400).json({ success: false, message: 'This promo is valid for first order only' });
      }
    }

    let discount;
    if (promo.discountType === 'percentage') {
      discount = (orderAmount * promo.discountValue) / 100;
      if (promo.maxDiscount && discount > parseFloat(promo.maxDiscount)) {
        discount = parseFloat(promo.maxDiscount);
      }
    } else {
      discount = parseFloat(promo.discountValue);
    }

    res.json({
      success: true,
      data: {
        promoId: promo.id,
        code: promo.code,
        discountType: promo.discountType,
        discountValue: promo.discountValue,
        calculatedDiscount: discount,
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// Get all shop promo codes (shop admin)
router.get('/manage/:shopId', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const shopId = parseInt(req.params.shopId);
    if (req.user.role === 'shop_admin' && req.user.shopId !== shopId) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const promos = await PromoCode.findAll({
      where: { shopId },
      order: [['createdAt', 'DESC']],
    });

    res.json({ success: true, data: promos });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
