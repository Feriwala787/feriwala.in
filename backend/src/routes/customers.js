const router = require('express').Router();
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
const Shop = require('../models/pg/Shop');
const Product = require('../models/pg/Product');
const Category = require('../models/pg/Category');
const Inventory = require('../models/pg/Inventory');
const { Op, Sequelize } = require('sequelize');
const { sequelize } = require('../database/postgres');

// Get nearby shops for customer — uses SQL Haversine to filter at DB level
router.get('/nearby-shops', authenticate, async (req, res) => {
  try {
    const { lat, lng, radius = 10 } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ success: false, message: 'Location required' });
    }

    const latF = parseFloat(lat);
    const lngF = parseFloat(lng);
    const radiusF = parseFloat(radius);

    if (isNaN(latF) || isNaN(lngF) || isNaN(radiusF)) {
      return res.status(400).json({ success: false, message: 'Invalid location parameters' });
    }

    // Haversine formula in SQL — returns distance in km
    const distanceExpr = Sequelize.literal(`
      6371 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(${latF} - CAST(latitude AS FLOAT)) / 2), 2) +
        COS(RADIANS(${latF})) * COS(RADIANS(CAST(latitude AS FLOAT))) *
        POWER(SIN(RADIANS(${lngF} - CAST(longitude AS FLOAT)) / 2), 2)
      ))
    `);

    const shops = await Shop.findAll({
      where: {
        isActive: true,
        latitude: { [Op.ne]: null },
        longitude: { [Op.ne]: null },
      },
      attributes: {
        include: [[distanceExpr, 'distance']],
      },
      having: Sequelize.literal(`
        6371 * 2 * ASIN(SQRT(
          POWER(SIN(RADIANS(${latF} - CAST(latitude AS FLOAT)) / 2), 2) +
          COS(RADIANS(${latF})) * COS(RADIANS(CAST(latitude AS FLOAT))) *
          POWER(SIN(RADIANS(${lngF} - CAST(longitude AS FLOAT)) / 2), 2)
        )) <= ${radiusF}
      `),
      order: Sequelize.literal('distance ASC'),
      group: ['Shop.id'],
    });

    res.json({ success: true, data: shops });
  } catch (error) {
    routeError(res, error);
  }
});

// Get home feed (featured products from nearby shops)
router.get('/home-feed', async (req, res) => {
  try {
    const { shopId, page = 1, limit = 20 } = req.query;
    const where = { isActive: true };
    if (shopId) where.shopId = parseInt(shopId);

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const [featured, newArrivals, categories] = await Promise.all([
      Product.findAll({
        where: { ...where, isFeatured: true },
        include: [
          { model: Shop, as: 'shop', attributes: ['id', 'name'] },
          { model: Inventory, as: 'inventory', attributes: ['quantity'] },
        ],
        limit: 10,
        order: [['createdAt', 'DESC']],
      }),
      Product.findAll({
        where,
        include: [
          { model: Shop, as: 'shop', attributes: ['id', 'name'] },
          { model: Inventory, as: 'inventory', attributes: ['quantity'] },
        ],
        limit: 20,
        order: [['createdAt', 'DESC']],
      }),
      Category.findAll({
        where: { isActive: true, parentId: null },
        order: [['sortOrder', 'ASC']],
        limit: 12,
      }),
    ]);

    res.json({
      success: true,
      data: { featured, newArrivals, categories },
    });
  } catch (error) {
    routeError(res, error);
  }
});

// Search
router.get('/search', async (req, res) => {
  try {
    const { q, shopId, page = 1, limit = 20 } = req.query;
    if (!q) return res.status(400).json({ success: false, message: 'Search query required' });

    const where = {
      isActive: true,
      [Op.or]: [
        { name: { [Op.iLike]: `%${q}%` } },
        { brand: { [Op.iLike]: `%${q}%` } },
        { description: { [Op.iLike]: `%${q}%` } },
      ],
    };
    if (shopId) where.shopId = parseInt(shopId);

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const results = await Product.findAndCountAll({
      where,
      include: [
        { model: Shop, as: 'shop', attributes: ['id', 'name'] },
        { model: Category, as: 'category', attributes: ['id', 'name'] },
        { model: Inventory, as: 'inventory', attributes: ['quantity'] },
      ],
      limit: parseInt(limit),
      offset,
      order: [['avgRating', 'DESC']],
    });

    res.json({
      success: true,
      data: results.rows,
      pagination: {
        total: results.count,
        page: parseInt(page),
        pages: Math.ceil(results.count / parseInt(limit)),
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
