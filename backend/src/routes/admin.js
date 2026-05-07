const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const Shop = require('../models/pg/Shop');
const Category = require('../models/pg/Category');
const User = require('../models/mongo/User');
const Order = require('../models/pg/Order');
const OrderItem = require('../models/pg/OrderItem');
const Product = require('../models/pg/Product');
const DeliveryTask = require('../models/pg/DeliveryTask');
const DeliveryAgentProfile = require('../models/mongo/DeliveryAgentProfile');
const { Op, fn, col, literal } = require('sequelize');
const { APPAREL_CATEGORY_PRESET } = require('../constants/apparelCategories');
const { sendWelcomeEmail } = require('../services/emailService');
const crypto = require('crypto');

// All admin routes require admin role
router.use(authenticate, authorize('admin'));

// ─── DASHBOARD ────────────────────────────────────────────────────────────────

router.get('/dashboard', async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const thisMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    const lastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1);
    const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);

    const [
      totalShops, activeShops, totalUsers, totalOrders, todayOrders,
      totalProducts, allOrders, thisMonthOrders, lastMonthOrders,
    ] = await Promise.all([
      Shop.count(),
      Shop.count({ where: { isActive: true } }),
      User.countDocuments(),
      Order.count(),
      Order.count({ where: { createdAt: { [Op.gte]: today } } }),
      Product.count({ where: { isActive: true } }),
      Order.findAll({ attributes: ['total', 'status', 'createdAt', 'shopId'], raw: true }),
      Order.findAll({ where: { createdAt: { [Op.gte]: thisMonth } }, attributes: ['total', 'status'], raw: true }),
      Order.findAll({ where: { createdAt: { [Op.between]: [lastMonth, lastMonthEnd] } }, attributes: ['total', 'status'], raw: true }),
    ]);

    const totalRevenue = allOrders.filter(o => o.status === 'delivered').reduce((s, o) => s + Number(o.total || 0), 0);
    const thisMonthRevenue = thisMonthOrders.filter(o => o.status === 'delivered').reduce((s, o) => s + Number(o.total || 0), 0);
    const lastMonthRevenue = lastMonthOrders.filter(o => o.status === 'delivered').reduce((s, o) => s + Number(o.total || 0), 0);
    const revenueGrowth = lastMonthRevenue > 0 ? (((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100).toFixed(1) : null;

    const cancelledOrders = allOrders.filter(o => o.status === 'cancelled').length;
    const cancellationRate = allOrders.length ? ((cancelledOrders / allOrders.length) * 100).toFixed(1) : '0.0';
    const avgOrderValue = allOrders.length ? (totalRevenue / allOrders.filter(o => o.status === 'delivered').length || 0) : 0;

    // Last 7 days orders
    const recentOrders = Array.from({ length: 7 }).map((_, i) => {
      const day = new Date();
      day.setDate(day.getDate() - (6 - i));
      const label = day.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      const dayStr = day.toDateString();
      const dayOrders = allOrders.filter(o => new Date(o.createdAt).toDateString() === dayStr);
      return {
        date: label,
        orders: dayOrders.length,
        revenue: dayOrders.filter(o => o.status === 'delivered').reduce((s, o) => s + Number(o.total || 0), 0),
      };
    });

    // Status breakdown
    const statusBreakdown = Object.entries(
      allOrders.reduce((acc, o) => { acc[o.status] = (acc[o.status] || 0) + 1; return acc; }, {})
    ).map(([status, count]) => ({ status, count }));

    // Top shops by revenue
    const shopRevMap = allOrders.filter(o => o.status === 'delivered').reduce((acc, o) => {
      acc[o.shopId] = (acc[o.shopId] || 0) + Number(o.total || 0);
      return acc;
    }, {});
    const topShopIds = Object.entries(shopRevMap).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([id]) => parseInt(id));
    const topShopsData = await Shop.findAll({ where: { id: topShopIds }, attributes: ['id', 'name'] });
    const topShops = topShopIds.map(id => {
      const shop = topShopsData.find(s => s.id === id);
      const shopOrders = allOrders.filter(o => o.shopId === id);
      return { shopId: id, name: shop?.name || `Shop ${id}`, revenue: shopRevMap[id] || 0, orders: shopOrders.length };
    });

    // User breakdown
    const [customers, shopAdmins, deliveryAgents] = await Promise.all([
      User.countDocuments({ role: 'customer' }),
      User.countDocuments({ role: 'shop_admin' }),
      User.countDocuments({ role: 'delivery_agent' }),
    ]);

    res.json({
      success: true,
      data: {
        totalRevenue, thisMonthRevenue, lastMonthRevenue, revenueGrowth,
        totalOrders, todayOrders, cancellationRate, avgOrderValue,
        totalShops, activeShops, totalProducts,
        totalUsers, customers, shopAdmins, deliveryAgents,
        recentOrders, statusBreakdown, topShops,
        repeatCustomers: 0,
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// ─── FINANCE / REVENUE ────────────────────────────────────────────────────────

router.get('/finance', async (req, res) => {
  try {
    const { period = '30d', shopId } = req.query;
    const days = period === '7d' ? 7 : period === '90d' ? 90 : period === '1y' ? 365 : 30;
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

    const where = { createdAt: { [Op.gte]: since } };
    if (shopId) where.shopId = parseInt(shopId);

    const orders = await Order.findAll({
      where,
      attributes: ['id', 'total', 'subtotal', 'discount', 'deliveryFee', 'status', 'shopId', 'createdAt'],
      raw: true,
    });

    const delivered = orders.filter(o => o.status === 'delivered');
    const cancelled = orders.filter(o => o.status === 'cancelled');

    const grossRevenue = delivered.reduce((s, o) => s + Number(o.total || 0), 0);
    const totalDiscount = delivered.reduce((s, o) => s + Number(o.discount || 0), 0);
    const deliveryRevenue = delivered.reduce((s, o) => s + Number(o.deliveryFee || 0), 0);
    const netRevenue = grossRevenue - deliveryRevenue;

    // Daily breakdown
    const dailyMap = {};
    for (let i = 0; i < days; i++) {
      const d = new Date(Date.now() - (days - 1 - i) * 24 * 60 * 60 * 1000);
      const key = d.toISOString().split('T')[0];
      dailyMap[key] = { date: key, revenue: 0, orders: 0, cancelled: 0 };
    }
    delivered.forEach(o => {
      const key = new Date(o.createdAt).toISOString().split('T')[0];
      if (dailyMap[key]) { dailyMap[key].revenue += Number(o.total || 0); dailyMap[key].orders++; }
    });
    cancelled.forEach(o => {
      const key = new Date(o.createdAt).toISOString().split('T')[0];
      if (dailyMap[key]) dailyMap[key].cancelled++;
    });

    res.json({
      success: true,
      data: {
        grossRevenue, netRevenue, totalDiscount, deliveryRevenue,
        totalOrders: orders.length, deliveredOrders: delivered.length,
        cancelledOrders: cancelled.length,
        cancellationRate: orders.length ? ((cancelled.length / orders.length) * 100).toFixed(1) : '0.0',
        avgOrderValue: delivered.length ? (grossRevenue / delivered.length).toFixed(2) : '0',
        daily: Object.values(dailyMap),
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// ─── SHOPS ────────────────────────────────────────────────────────────────────

router.get('/shops', async (req, res) => {
  try {
    const shops = await Shop.findAll({ order: [['createdAt', 'DESC']] });
    // Attach order counts
    const shopIds = shops.map(s => s.id);
    const orderCounts = await Order.findAll({
      where: { shopId: shopIds },
      attributes: ['shopId', [fn('COUNT', col('id')), 'count'], [fn('SUM', col('total')), 'revenue']],
      group: ['shopId'],
      raw: true,
    });
    const countMap = orderCounts.reduce((acc, r) => { acc[r.shopId] = r; return acc; }, {});
    const data = shops.map(s => ({
      ...s.toJSON(),
      orderCount: parseInt(countMap[s.id]?.count || 0),
      revenue: parseFloat(countMap[s.id]?.revenue || 0),
    }));
    res.json({ success: true, data });
  } catch (error) {
    routeError(res, error);
  }
});

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
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const existing = await Shop.findOne({ where: { code: req.body.code.toUpperCase() } });
    if (existing) return res.status(409).json({ success: false, message: 'Shop code already exists' });

    const shop = await Shop.create({ ...req.body, code: req.body.code.toUpperCase() });
    res.status(201).json({ success: true, data: shop });
  } catch (error) {
    routeError(res, error);
  }
});

router.put('/shops/:id', async (req, res) => {
  try {
    const shop = await Shop.findByPk(req.params.id);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });
    await shop.update(req.body);
    res.json({ success: true, data: shop });
  } catch (error) {
    routeError(res, error);
  }
});

router.put('/shops/:shopId/assign-user', [body('userId').trim().notEmpty()], async (req, res) => {
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
    routeError(res, error);
  }
});

// ─── USER MANAGEMENT ─────────────────────────────────────────────────────────

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
    res.json({ success: true, data: users, pagination: { total, page: parseInt(page), pages: Math.ceil(total / parseInt(limit)) } });
  } catch (error) {
    routeError(res, error);
  }
});

// Create shop admin
router.post('/users/shop-admin', [
  body('name').trim().notEmpty(),
  body('email').isEmail().normalizeEmail(),
  body('phone').trim().notEmpty(),
  body('shopId').isInt(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { name, email, phone, shopId } = req.body;
    const shop = await Shop.findByPk(shopId);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });

    const existing = await User.findOne({ $or: [{ email }, { phone }] });
    if (existing) return res.status(409).json({ success: false, message: 'Email or phone already registered' });

    const tempPassword = crypto.randomBytes(6).toString('hex');
    const user = await User.create({ name, email, phone, passwordHash: tempPassword, role: 'shop_admin', shopId, isVerified: true });

    try { await sendWelcomeEmail({ to: email, name, role: 'Shop Admin', password: tempPassword }); } catch (_) {}

    res.status(201).json({ success: true, data: user, message: 'Shop admin created. Welcome email sent.' });
  } catch (error) {
    routeError(res, error);
  }
});

// Create delivery agent
router.post('/users/delivery-agent', [
  body('name').trim().notEmpty(),
  body('email').isEmail().normalizeEmail(),
  body('phone').trim().notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

    const { name, email, phone, shopId } = req.body;
    const existing = await User.findOne({ $or: [{ email }, { phone }] });
    if (existing) return res.status(409).json({ success: false, message: 'Email or phone already registered' });

    const tempPassword = crypto.randomBytes(6).toString('hex');
    const user = await User.create({ name, email, phone, passwordHash: tempPassword, role: 'delivery_agent', shopId: shopId || null, isVerified: true });
    await DeliveryAgentProfile.create({ userId: user._id });

    try { await sendWelcomeEmail({ to: email, name, role: 'Delivery Agent', password: tempPassword }); } catch (_) {}

    res.status(201).json({ success: true, data: user, message: 'Delivery agent created. Welcome email sent.' });
  } catch (error) {
    routeError(res, error);
  }
});

router.put('/users/:id/status', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    user.isActive = req.body.isActive !== undefined ? req.body.isActive : !user.isActive;
    await user.save();
    res.json({ success: true, data: user });
  } catch (error) {
    routeError(res, error);
  }
});

router.put('/users/:id/role', [body('role').isIn(['customer', 'shop_admin', 'delivery_agent', 'admin'])], async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    user.role = req.body.role;
    if (req.body.shopId) user.shopId = req.body.shopId;
    await user.save();
    res.json({ success: true, data: user });
  } catch (error) {
    routeError(res, error);
  }
});

router.delete('/users/:id', async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    if (user.role === 'admin') return res.status(403).json({ success: false, message: 'Cannot delete admin' });
    await User.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'User deleted' });
  } catch (error) {
    routeError(res, error);
  }
});

// ─── ORDERS ───────────────────────────────────────────────────────────────────

router.get('/orders', async (req, res) => {
  try {
    const { status, shopId, page = 1, limit = 20, search } = req.query;
    const where = {};
    if (status) where.status = status;
    if (shopId) where.shopId = parseInt(shopId);
    if (search) where.orderNumber = { [Op.iLike]: `%${search}%` };

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const orders = await Order.findAndCountAll({
      where,
      include: [
        { model: OrderItem, as: 'items' },
        { model: Shop, as: 'shop', attributes: ['id', 'name', 'code'] },
      ],
      limit: parseInt(limit),
      offset,
      order: [['createdAt', 'DESC']],
    });

    res.json({
      success: true,
      data: orders.rows,
      pagination: { total: orders.count, page: parseInt(page), pages: Math.ceil(orders.count / parseInt(limit)) },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// ─── CATEGORIES ───────────────────────────────────────────────────────────────

router.post('/categories', [body('name').trim().notEmpty(), body('slug').trim().notEmpty()], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });
    const category = await Category.create(req.body);
    res.status(201).json({ success: true, data: category });
  } catch (error) {
    routeError(res, error);
  }
});

router.put('/categories/:id', async (req, res) => {
  try {
    const category = await Category.findByPk(req.params.id);
    if (!category) return res.status(404).json({ success: false, message: 'Category not found' });
    await category.update(req.body);
    res.json({ success: true, data: category });
  } catch (error) {
    routeError(res, error);
  }
});

router.post('/categories/seed-apparel', async (req, res) => {
  try {
    const created = [], updated = [];
    for (const [index, parent] of APPAREL_CATEGORY_PRESET.entries()) {
      const [parentCategory, wasCreated] = await Category.findOrCreate({
        where: { slug: parent.slug },
        defaults: { name: parent.name, slug: parent.slug, description: parent.description, sortOrder: parent.sortOrder ?? (index + 1) * 10, parentId: null, isActive: true },
      });
      if (wasCreated) created.push(parent.slug);
      else { await parentCategory.update({ name: parent.name, description: parent.description, isActive: true }); updated.push(parent.slug); }
      for (const [subIndex, child] of (parent.subcategories || []).entries()) {
        const [, childCreated] = await Category.findOrCreate({
          where: { slug: child.slug },
          defaults: { name: child.name, slug: child.slug, parentId: parentCategory.id, sortOrder: (parent.sortOrder ?? (index + 1) * 10) + subIndex + 1, isActive: true },
        });
        if (childCreated) created.push(child.slug); else updated.push(child.slug);
      }
    }
    res.json({ success: true, message: 'Apparel categories synced', data: { created, updated } });
  } catch (error) {
    routeError(res, error);
  }
});

// ─── SEED ADMIN ───────────────────────────────────────────────────────────────

router.post('/seed', async (req, res) => {
  try {
    const email = 'masa00483429@gmail.com';
    const existing = await User.findOne({ email });
    if (existing) {
      if (existing.role !== 'admin') { existing.role = 'admin'; await existing.save(); }
      return res.json({ success: true, message: 'Admin already exists', data: { email } });
    }
    const admin = await User.create({
      name: 'Feriwala Admin',
      loginId: 'feriwala_admin',
      email,
      phone: '9999999999',
      passwordHash: 'Ssb9119@$%',
      role: 'admin',
      isVerified: true,
      isActive: true,
    });
    res.status(201).json({ success: true, message: 'Admin seeded', data: { email: admin.email } });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
