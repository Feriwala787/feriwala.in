const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const Shop = require('../models/pg/Shop');
const Category = require('../models/pg/Category');
const User = require('../models/mongo/User');
const Order = require('../models/pg/Order');
const Product = require('../models/pg/Product');
const { Op } = require('sequelize');
const { APPAREL_CATEGORY_PRESET } = require('../constants/apparelCategories');

// Middleware: admin only
router.use(authenticate, authorize('admin'));

// Register new shop
router.post('/shops', [
  body('name').trim().notEmpty(),
  body('code').trim().notEmpty().isLength({ max: 20 }),
  body('addressLine1').trim().notEmpty(),
  body('city').trim().notEmpty(),
  body('state').trim().notEmpty(),
  body('pincode').trim().notEmpty(),
  body('latitude').isFloat(),
  body('longitude').isFloat(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const existing = await Shop.findOne({ where: { code: req.body.code.toUpperCase() } });
    if (existing) {
      return res.status(409).json({ success: false, message: 'Shop code already exists' });
    }

    const shop = await Shop.create({
      ...req.body,
      code: req.body.code.toUpperCase(),
    });

    res.status(201).json({ success: true, data: shop });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get all shops
router.get('/shops', async (req, res) => {
  try {
    const shops = await Shop.findAll({ order: [['createdAt', 'DESC']] });
    res.json({ success: true, data: shops });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Assign user to shop
router.put('/shops/:shopId/assign-user', [
  body('userId').trim().notEmpty(),
], async (req, res) => {
  try {
    const shop = await Shop.findByPk(req.params.shopId);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });

    const user = await User.findById(req.body.userId);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    user.shopId = shop.id;
    user.role = 'shop_admin';
    await user.save();

    res.json({ success: true, message: 'User assigned to shop', data: { user, shop } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Create category
router.post('/categories', [
  body('name').trim().notEmpty(),
  body('slug').trim().notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const category = await Category.create(req.body);
    res.status(201).json({ success: true, data: category });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update category
router.put('/categories/:id', async (req, res) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) return res.status(404).json({ success: false, message: 'Category not found' });

    await category.update(req.body);
    res.json({ success: true, data: category });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Seed apparel-focused category taxonomy (idempotent)
router.post('/categories/seed-apparel', async (req, res) => {
  try {
    const created = [];
    const updated = [];

    for (const [index, parent] of APPAREL_CATEGORY_PRESET.entries()) {
      const [parentCategory, wasCreated] = await Category.findOrCreate({
        where: { slug: parent.slug },
        defaults: {
          name: parent.name,
          slug: parent.slug,
          description: parent.description,
          sortOrder: parent.sortOrder ?? (index + 1) * 10,
          parentId: null,
          isActive: true,
        },
      });

      if (wasCreated) created.push(parent.slug);
      else {
        await parentCategory.update({
          name: parent.name,
          description: parent.description,
          sortOrder: parent.sortOrder ?? parentCategory.sortOrder,
          isActive: true,
        });
        updated.push(parent.slug);
      }

      for (const [subIndex, child] of (parent.subcategories || []).entries()) {
        const [subCategory, childCreated] = await Category.findOrCreate({
          where: { slug: child.slug },
          defaults: {
            name: child.name,
            slug: child.slug,
            parentId: parentCategory.id,
            sortOrder: (parent.sortOrder ?? (index + 1) * 10) + subIndex + 1,
            isActive: true,
          },
        });

        if (childCreated) created.push(child.slug);
        else {
          await subCategory.update({
            name: child.name,
            parentId: parentCategory.id,
            isActive: true,
          });
          updated.push(child.slug);
        }
      }
    }

    res.json({
      success: true,
      message: 'Apparel category preset synchronized',
      data: { created, updated },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get all users
router.get('/users', async (req, res) => {
  try {
    const { role, search, page = 1, limit = 20 } = req.query;
    const filter = {};
    if (role) filter.role = role;
    if (search) {
      filter.$or = [
        { name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const [users, total] = await Promise.all([
      User.find(filter).skip(skip).limit(parseInt(limit)).sort({ createdAt: -1 }),
      User.countDocuments(filter),
    ]);

    res.json({
      success: true,
      data: users,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Toggle user active status
router.put('/users/:id/status', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    user.isActive = !user.isActive;
    await user.save();
    res.json({ success: true, data: user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Dashboard stats
router.get('/dashboard', async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [totalShops, totalUsers, totalOrders, todayOrders, totalProducts] = await Promise.all([
      Shop.count(),
      User.countDocuments(),
      Order.count(),
      Order.count({ where: { createdAt: { [Op.gte]: today } } }),
      Product.count({ where: { isActive: true } }),
    ]);

    res.json({
      success: true,
      data: { totalShops, totalUsers, totalOrders, todayOrders, totalProducts },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
