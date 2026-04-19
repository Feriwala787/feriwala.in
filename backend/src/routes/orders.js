const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const Order = require('../models/pg/Order');
const OrderItem = require('../models/pg/OrderItem');
const Product = require('../models/pg/Product');
const Inventory = require('../models/pg/Inventory');
const Invoice = require('../models/pg/Invoice');
const PromoCode = require('../models/pg/PromoCode');
const Shop = require('../models/pg/Shop');
const DeliveryTask = require('../models/pg/DeliveryTask');
const { sequelize } = require('../database/postgres');
const { generateOrderNumber, generateInvoiceNumber, generateOtp } = require('../utils/helpers');
const { Op } = require('sequelize');
const { createOrAssignDeliveryTask } = require('../services/deliveryTaskService');

// Place order (customer)
router.post('/', authenticate, authorize('customer'), [
  body('shopId').isInt(),
  body('items').isArray({ min: 1 }),
  body('items.*.productId').isInt(),
  body('items.*.quantity').isInt({ min: 1 }),
  body('deliveryAddress').isObject(),
  body('paymentMethod').isIn(['cod', 'online', 'upi', 'card']),
], async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      await t.rollback();
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { shopId, items, deliveryAddress, paymentMethod, promoCode, notes } = req.body;

    const shop = await Shop.findByPk(shopId, { transaction: t });
    if (!shop || !shop.isActive) {
      await t.rollback();
      return res.status(400).json({ success: false, message: 'Shop not available' });
    }

    let subtotal = 0;
    const orderItems = [];

    for (const item of items) {
      const product = await Product.findByPk(item.productId, {
        include: [{ model: Inventory, as: 'inventory', where: { shopId } }],
        transaction: t,
      });

      if (!product || !product.isActive) {
        await t.rollback();
        return res.status(400).json({ success: false, message: `Product ${item.productId} not available` });
      }

      const inv = product.inventory[0];
      const availableQty = inv.quantity - inv.reservedQuantity;
      if (availableQty < item.quantity) {
        await t.rollback();
        return res.status(400).json({
          success: false,
          message: `Insufficient stock for ${product.name}. Available: ${availableQty}`,
        });
      }

      // Reserve inventory
      await inv.update(
        { reservedQuantity: inv.reservedQuantity + item.quantity },
        { transaction: t }
      );

      const itemTotal = product.sellingPrice * item.quantity;
      subtotal += itemTotal;

      orderItems.push({
        productId: product.id,
        productName: product.name,
        quantity: item.quantity,
        price: product.sellingPrice,
        size: item.size || product.size,
        color: item.color || product.color,
        total: itemTotal,
      });
    }

    // Apply promo code
    let discount = 0;
    let promoCodeId = null;
    if (promoCode) {
      const promo = await PromoCode.findOne({
        where: {
          shopId,
          code: promoCode.toUpperCase(),
          isActive: true,
          validFrom: { [Op.lte]: new Date() },
          validTo: { [Op.gte]: new Date() },
        },
        transaction: t,
      });

      if (promo && subtotal >= promo.minOrderAmount) {
        if (promo.usageLimit === null || promo.usedCount < promo.usageLimit) {
          if (promo.discountType === 'percentage') {
            discount = (subtotal * promo.discountValue) / 100;
            if (promo.maxDiscount && discount > promo.maxDiscount) {
              discount = parseFloat(promo.maxDiscount);
            }
          } else {
            discount = parseFloat(promo.discountValue);
          }
          promoCodeId = promo.id;
          await promo.update({ usedCount: promo.usedCount + 1 }, { transaction: t });
        }
      }
    }

    const deliveryFee = parseFloat(shop.deliveryFee) || 0;
    const tax = 0; // Configure tax as needed
    const total = subtotal - discount + deliveryFee + tax;

    if (shop.minOrderAmount > 0 && subtotal < shop.minOrderAmount) {
      await t.rollback();
      return res.status(400).json({
        success: false,
        message: `Minimum order amount is ₹${shop.minOrderAmount}`,
      });
    }

    const order = await Order.create({
      orderNumber: generateOrderNumber(),
      customerId: req.user._id.toString(),
      shopId,
      subtotal,
      discount,
      deliveryFee,
      tax,
      total,
      promoCodeId,
      deliveryAddress,
      paymentMethod,
      notes,
    }, { transaction: t });

    // Create order items
    for (const item of orderItems) {
      await OrderItem.create({ ...item, orderId: order.id }, { transaction: t });
    }

    // Create invoice
    await Invoice.create({
      invoiceNumber: generateInvoiceNumber(shop.code),
      orderId: order.id,
      shopId: shop.id,
      customerId: req.user._id.toString(),
      subtotal,
      discount,
      tax,
      deliveryFee,
      total,
      paymentMethod,
      items: orderItems,
      customerDetails: {
        name: req.user.name,
        phone: req.user.phone,
        email: req.user.email,
      },
      shopDetails: {
        name: shop.name,
        code: shop.code,
        address: `${shop.addressLine1}, ${shop.city}`,
      },
    }, { transaction: t });

    await t.commit();

    // Notify shop via socket
    const io = req.app.get('io');
    io.to(`shop_${shopId}`).emit('new_order', {
      orderId: order.id,
      orderNumber: order.orderNumber,
    });

    const fullOrder = await Order.findByPk(order.id, {
      include: [
        { model: OrderItem, as: 'items' },
        { model: Shop, as: 'shop', attributes: ['id', 'name', 'code'] },
      ],
    });

    res.status(201).json({ success: true, data: fullOrder });
  } catch (error) {
    await t.rollback();
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get customer orders
router.get('/my-orders', authenticate, authorize('customer'), async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const where = { customerId: req.user._id.toString() };
    if (status) where.status = status;

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
      pagination: {
        total: orders.count,
        page: parseInt(page),
        pages: Math.ceil(orders.count / parseInt(limit)),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get shop orders (shop admin)
router.get('/shop/:shopId', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const shopId = parseInt(req.params.shopId);
    if (req.user.role === 'shop_admin' && req.user.shopId !== shopId) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const { status, page = 1, limit = 20 } = req.query;
    const where = { shopId };
    if (status) where.status = status;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const orders = await Order.findAndCountAll({
      where,
      include: [{ model: OrderItem, as: 'items' }],
      limit: parseInt(limit),
      offset,
      order: [['createdAt', 'DESC']],
    });

    res.json({
      success: true,
      data: orders.rows,
      pagination: {
        total: orders.count,
        page: parseInt(page),
        pages: Math.ceil(orders.count / parseInt(limit)),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update order status (shop admin)
router.put('/:id/status', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    if (req.user.role === 'shop_admin' && req.user.shopId !== order.shopId) {
      return res.status(403).json({ success: false, message: 'Not your order' });
    }

    const { status } = req.body;
    const validTransitions = {
      pending: ['confirmed', 'cancelled'],
      confirmed: ['preparing', 'cancelled'],
      preparing: ['ready_for_pickup'],
      ready_for_pickup: ['picked_up'],
      picked_up: ['out_for_delivery'],
      out_for_delivery: ['delivered'],
      delivered: ['returned'],
    };

    if (!validTransitions[order.status]?.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Cannot transition from ${order.status} to ${status}`,
      });
    }

    const updates = { status };
    if (status === 'delivered') updates.deliveredAt = new Date();
    if (status === 'cancelled') {
      updates.cancelledAt = new Date();
      updates.cancelReason = req.body.reason;

      // Release reserved inventory
      const items = await OrderItem.findAll({ where: { orderId: order.id } });
      for (const item of items) {
        const inv = await Inventory.findOne({
          where: { productId: item.productId, shopId: order.shopId },
        });
        if (inv) {
          await inv.update({ reservedQuantity: Math.max(0, inv.reservedQuantity - item.quantity) });
        }
      }
    }

    if (status === 'confirmed') {
      // Deduct from stock, release reservation
      const items = await OrderItem.findAll({ where: { orderId: order.id } });
      for (const item of items) {
        const inv = await Inventory.findOne({
          where: { productId: item.productId, shopId: order.shopId },
        });
        if (inv) {
          await inv.update({
            quantity: inv.quantity - item.quantity,
            reservedQuantity: Math.max(0, inv.reservedQuantity - item.quantity),
          });
        }
      }
    }

    await order.update(updates);

    if (status === 'ready_for_pickup') {
      await createOrAssignDeliveryTask({ orderId: order.id, io: req.app.get('io') });
    }

    // Notify via socket
    const io = req.app.get('io');
    io.to(`customer_${order.customerId}`).emit('order_status', {
      orderId: order.id,
      status: order.status,
    });

    res.json({ success: true, data: order });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get order details
router.get('/:id', authenticate, async (req, res) => {
  try {
    const order = await Order.findByPk(req.params.id, {
      include: [
        { model: OrderItem, as: 'items', include: [{ model: Product, as: 'product' }] },
        { model: Shop, as: 'shop' },
        { model: Invoice, as: 'invoice' },
        { model: DeliveryTask, as: 'deliveryTasks' },
      ],
    });

    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    // Verify access
    const isCustomer = order.customerId === req.user._id.toString();
    const isShopAdmin = req.user.role === 'shop_admin' && req.user.shopId === order.shopId;
    const isAdmin = req.user.role === 'admin';

    if (!isCustomer && !isShopAdmin && !isAdmin) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }

    res.json({ success: true, data: order });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
