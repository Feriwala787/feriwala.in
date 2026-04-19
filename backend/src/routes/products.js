const router = require('express').Router();
const { body, query, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');
const Product = require('../models/pg/Product');
const Category = require('../models/pg/Category');
const Inventory = require('../models/pg/Inventory');
const Shop = require('../models/pg/Shop');
const { Op, Sequelize } = require('sequelize');

// Get all products (public - customer browsing)
router.get('/', async (req, res) => {
  try {
    const {
      shopId, categoryId, search, gender, brand, size, color, material,
      productType, fit, pattern, sleeveType, neckType, occasion,
      minPrice, maxPrice, featured, page = 1, limit = 20,
      sortBy = 'createdAt', sortOrder = 'DESC',
    } = req.query;

    const where = { isActive: true };
    if (shopId) where.shopId = parseInt(shopId);
    if (categoryId) where.categoryId = parseInt(categoryId);
    if (gender) where.gender = gender;
    if (brand) where.brand = { [Op.iLike]: `%${brand}%` };
    if (size) where.size = { [Op.iLike]: `%${size}%` };
    if (color) where.color = { [Op.iLike]: `%${color}%` };
    if (material) where.material = { [Op.iLike]: `%${material}%` };
    if (featured === 'true') where.isFeatured = true;
    if (minPrice) where.sellingPrice = { ...where.sellingPrice, [Op.gte]: parseFloat(minPrice) };
    if (maxPrice) where.sellingPrice = { ...where.sellingPrice, [Op.lte]: parseFloat(maxPrice) };
    if (search) {
      where[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { brand: { [Op.iLike]: `%${search}%` } },
        { description: { [Op.iLike]: `%${search}%` } },
      ];
    }

    const attributeConditions = [];
    const jsonFilter = (field, value) => {
      if (!value) return;
      attributeConditions.push(
        Sequelize.where(
          Sequelize.cast(Sequelize.json(`attributes.${field}`), 'text'),
          { [Op.iLike]: `%${value}%` },
        ),
      );
    };

    jsonFilter('productType', productType);
    jsonFilter('fit', fit);
    jsonFilter('pattern', pattern);
    jsonFilter('sleeveType', sleeveType);
    jsonFilter('neckType', neckType);
    jsonFilter('occasion', occasion);

    if (attributeConditions.length > 0) {
      where[Op.and] = [...(where[Op.and] || []), ...attributeConditions];
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const allowedSorts = ['createdAt', 'sellingPrice', 'avgRating', 'name'];
    const orderField = allowedSorts.includes(sortBy) ? sortBy : 'createdAt';

    const products = await Product.findAndCountAll({
      where,
      include: [
        { model: Category, as: 'category', attributes: ['id', 'name', 'slug'] },
        { model: Shop, as: 'shop', attributes: ['id', 'name', 'code'] },
        { model: Inventory, as: 'inventory', attributes: ['quantity', 'reservedQuantity'] },
      ],
      limit: parseInt(limit),
      offset,
      order: [[orderField, sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC']],
    });

    res.json({
      success: true,
      data: products.rows,
      pagination: {
        total: products.count,
        page: parseInt(page),
        pages: Math.ceil(products.count / parseInt(limit)),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get product by ID
router.get('/:id', async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id, {
      include: [
        { model: Category, as: 'category' },
        { model: Shop, as: 'shop', attributes: ['id', 'name', 'code', 'city'] },
        { model: Inventory, as: 'inventory' },
      ],
    });
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });
    res.json({ success: true, data: product });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Create product (shop admin)
router.post('/', authenticate, authorize('shop_admin', 'admin'), [
  body('name').trim().notEmpty(),
  body('categoryId').isInt(),
  body('mrp').isFloat({ min: 0 }),
  body('sellingPrice').isFloat({ min: 0 }),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const shopId = req.user.shopId;
    if (!shopId) return res.status(400).json({ success: false, message: 'No shop assigned' });

    const slug = req.body.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    const discount = req.body.mrp > 0
      ? (((req.body.mrp - req.body.sellingPrice) / req.body.mrp) * 100).toFixed(2)
      : 0;

    const product = await Product.create({
      ...req.body,
      shopId,
      slug: `${slug}-${Date.now()}`,
      discount,
    });

    // Create inventory entry
    await Inventory.create({
      productId: product.id,
      shopId,
      quantity: req.body.quantity || 0,
    });

    res.status(201).json({ success: true, data: product });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update product (shop admin)
router.put('/:id', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    if (req.user.role === 'shop_admin' && req.user.shopId !== product.shopId) {
      return res.status(403).json({ success: false, message: 'Not your product' });
    }

    const allowedFields = [
      'name', 'description', 'brand', 'sku', 'mrp', 'sellingPrice',
      'size', 'color', 'material', 'gender', 'images', 'tags',
      'attributes', 'isActive', 'isFeatured', 'categoryId',
    ];

    const updates = {};
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    });

    if (updates.mrp && updates.sellingPrice) {
      updates.discount = ((updates.mrp - updates.sellingPrice) / updates.mrp * 100).toFixed(2);
    }

    await product.update(updates);
    res.json({ success: true, data: product });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update inventory (shop admin)
router.put('/:id/inventory', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

    if (req.user.role === 'shop_admin' && req.user.shopId !== product.shopId) {
      return res.status(403).json({ success: false, message: 'Not your product' });
    }

    const [inventory] = await Inventory.findOrCreate({
      where: { productId: product.id, shopId: product.shopId },
      defaults: { quantity: 0 },
    });

    const { quantity, lowStockThreshold } = req.body;
    if (quantity !== undefined) inventory.quantity = quantity;
    if (lowStockThreshold !== undefined) inventory.lowStockThreshold = lowStockThreshold;
    await inventory.save();

    res.json({ success: true, data: inventory });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Upload product images
router.post('/:id/images', authenticate, authorize('shop_admin', 'admin'),
  upload.array('images', 5), async (req, res) => {
    try {
      const product = await Product.findByPk(req.params.id);
      if (!product) return res.status(404).json({ success: false, message: 'Product not found' });

      const imageUrls = req.files.map(f => `/uploads/${f.filename}`);
      const currentImages = product.images || [];
      await product.update({ images: [...currentImages, ...imageUrls] });

      res.json({ success: true, data: product });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  });

// Get categories
router.get('/categories/all', async (req, res) => {
  try {
    const categories = await Category.findAll({
      where: { isActive: true },
      include: [{ model: Category, as: 'subcategories', where: { isActive: true }, required: false }],
      order: [['sortOrder', 'ASC']],
    });
    res.json({ success: true, data: categories });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
