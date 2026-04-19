const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const DeliveryTask = require('../models/pg/DeliveryTask');
const ReturnRequest = require('../models/pg/ReturnRequest');
const Order = require('../models/pg/Order');
const OrderItem = require('../models/pg/OrderItem');
const Shop = require('../models/pg/Shop');
const DeliveryAgentProfile = require('../models/mongo/DeliveryAgentProfile');
const User = require('../models/mongo/User');
const { generateOtp, calculateDistance, generateOrderNumber } = require('../utils/helpers');
const { Op } = require('sequelize');
const { createOrAssignDeliveryTask } = require('../services/deliveryTaskService');

// Create delivery task (shop assigns)
router.post('/tasks', authenticate, authorize('shop_admin', 'admin'), [
  body('orderId').isInt(),
  body('taskType').isIn(['delivery', 'pickup', 'return_pickup']),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { orderId, taskType } = req.body;
    if (taskType === 'delivery') {
      const task = await createOrAssignDeliveryTask({ orderId, io: req.app.get('io') });
      return res.status(201).json({ success: true, data: task });
    }

    const order = await Order.findByPk(orderId, {
      include: [{ model: Shop, as: 'shop' }],
    });

    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    // Find nearest available delivery agent
    const shopLat = parseFloat(order.shop.latitude);
    const shopLng = parseFloat(order.shop.longitude);

    const availableAgents = await DeliveryAgentProfile.find({
      isOnline: true,
      isAvailable: true,
      assignedShopId: { $in: [order.shopId, null] },
    }).populate({ path: 'userId', model: 'User' });

    // Sort by distance
    const agentsWithDistance = availableAgents.map(agent => ({
      agent,
      distance: agent.currentLocation?.latitude
        ? calculateDistance(shopLat, shopLng, agent.currentLocation.latitude, agent.currentLocation.longitude)
        : Infinity,
    })).sort((a, b) => a.distance - b.distance);

    const selectedAgent = agentsWithDistance.length > 0 ? agentsWithDistance[0] : null;

    const pickupLocation = {
      address: `${order.shop.addressLine1}, ${order.shop.city}`,
      latitude: shopLat,
      longitude: shopLng,
    };

    const dropLocation = taskType === 'return_pickup'
      ? pickupLocation
      : order.deliveryAddress;

    const task = await DeliveryTask.create({
      orderId,
      shopId: order.shopId,
      agentId: selectedAgent?.agent.userId._id.toString() || null,
      taskType,
      status: selectedAgent ? 'assigned' : 'pending',
      pickupLocation,
      dropLocation: taskType === 'return_pickup' ? order.deliveryAddress : dropLocation,
      pickupOtp: generateOtp(),
      deliveryOtp: generateOtp(),
      assignedAt: selectedAgent ? new Date() : null,
      distanceKm: selectedAgent?.distance,
      estimatedMinutes: selectedAgent ? Math.ceil((selectedAgent.distance / 20) * 60) : null,
    });

    if (selectedAgent) {
      await DeliveryAgentProfile.findByIdAndUpdate(selectedAgent.agent._id, { isAvailable: false });

      const io = req.app.get('io');
      io.to(`agent_${selectedAgent.agent.userId._id}`).emit('new_task', {
        taskId: task.id,
        taskType: task.taskType,
        orderId: task.orderId,
      });
    }

    res.status(201).json({ success: true, data: task });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get delivery agent's tasks
router.get('/my-tasks', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const where = { agentId: req.user._id.toString() };
    if (status) where.status = status;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const tasks = await DeliveryTask.findAndCountAll({
      where,
      include: [
        { model: Order, as: 'order' },
        { model: Shop, as: 'shop', attributes: ['id', 'name', 'phone'] },
      ],
      limit: parseInt(limit),
      offset,
      order: [['createdAt', 'DESC']],
    });

    res.json({
      success: true,
      data: tasks.rows,
      pagination: {
        total: tasks.count,
        page: parseInt(page),
        pages: Math.ceil(tasks.count / parseInt(limit)),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Accept task
router.put('/tasks/:id/accept', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const task = await DeliveryTask.findByPk(req.params.id);
    if (!task) return res.status(404).json({ success: false, message: 'Task not found' });
    if (task.agentId !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not assigned to you' });
    }

    await task.update({ status: 'accepted', acceptedAt: new Date() });

    const io = req.app.get('io');
    io.to(`shop_${task.shopId}`).emit('task_accepted', { taskId: task.id });

    res.json({ success: true, data: task });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update task status (delivery agent)
router.put('/tasks/:id/status', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const task = await DeliveryTask.findByPk(req.params.id);
    if (!task) return res.status(404).json({ success: false, message: 'Task not found' });
    if (task.agentId !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Not assigned to you' });
    }

    const { status, otp } = req.body;

    // Verify OTP for pickup and delivery
    if (status === 'picked_up' && otp !== task.pickupOtp) {
      return res.status(400).json({ success: false, message: 'Invalid pickup OTP' });
    }
    if (status === 'completed' && task.taskType === 'delivery' && otp !== task.deliveryOtp) {
      return res.status(400).json({ success: false, message: 'Invalid delivery OTP' });
    }

    const updates = { status };
    if (status === 'picked_up') updates.pickedUpAt = new Date();
    if (status === 'completed') {
      updates.completedAt = new Date();

      // Mark agent available again
      await DeliveryAgentProfile.findOneAndUpdate(
        { userId: req.user._id },
        { isAvailable: true }
      );

      // Update order status
      if (task.taskType === 'delivery') {
        await Order.update({ status: 'delivered', deliveredAt: new Date() }, { where: { id: task.orderId } });
      }

      // Update agent stats
      const profileUpdate = task.taskType === 'delivery'
        ? { $inc: { completedDeliveries: 1 } }
        : { $inc: { completedReturns: 1 } };
      await DeliveryAgentProfile.findOneAndUpdate({ userId: req.user._id }, profileUpdate);
    }

    await task.update(updates);

    if (task.taskType === 'delivery') {
      if (status === 'picked_up') {
        await Order.update({ status: 'picked_up' }, { where: { id: task.orderId } });
      }
      if (status === 'in_transit' || status === 'arrived') {
        await Order.update({ status: 'out_for_delivery' }, { where: { id: task.orderId } });
      }
    }

    const io = req.app.get('io');
    io.to(`shop_${task.shopId}`).emit('task_status', { taskId: task.id, status });
    const order = await Order.findByPk(task.orderId);
    if (order) {
      io.to(`customer_${order.customerId}`).emit('delivery_status', {
        taskId: task.id,
        status,
        orderId: task.orderId,
      });
    }

    res.json({ success: true, data: task });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update delivery agent location
router.put('/location', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    await DeliveryAgentProfile.findOneAndUpdate(
      { userId: req.user._id },
      { currentLocation: { latitude, longitude, updatedAt: new Date() } }
    );
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Toggle online status
router.put('/online-status', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const { isOnline } = req.body;
    const profile = await DeliveryAgentProfile.findOneAndUpdate(
      { userId: req.user._id },
      { isOnline, isAvailable: isOnline },
      { new: true }
    );
    res.json({ success: true, data: profile });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Backward compatible alias used by existing delivery app
router.put('/online', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const current = await DeliveryAgentProfile.findOne({ userId: req.user._id });
    if (!current) return res.status(404).json({ success: false, message: 'Delivery profile not found' });
    const nextState = !Boolean(current.isOnline);
    const profile = await DeliveryAgentProfile.findOneAndUpdate(
      { userId: req.user._id },
      { isOnline: nextState, isAvailable: nextState },
      { new: true }
    );
    res.json({ success: true, data: profile });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Create return request (customer)
router.post('/returns', authenticate, authorize('customer'), [
  body('orderId').isInt(),
  body('orderItemId').isInt(),
  body('returnType').optional().isIn(['return', 'replace']),
  body('reason').trim().notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { orderId, orderItemId, reason, returnType = 'return', bankDetails = {}, replacementPreference = {} } = req.body;
    const order = await Order.findByPk(orderId);

    if (!order || order.customerId !== req.user._id.toString()) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    if (order.status !== 'delivered') {
      return res.status(400).json({ success: false, message: 'Can only return delivered orders' });
    }

    const returnReq = await ReturnRequest.create({
      orderId,
      orderItemId,
      shopId: order.shopId,
      customerId: req.user._id.toString(),
      returnType,
      reason,
      bankDetails,
      replacementPreference,
    });

    const io = req.app.get('io');
    io.to(`shop_${order.shopId}`).emit('return_request', {
      returnId: returnReq.id,
      orderId,
    });

    res.status(201).json({ success: true, data: returnReq });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Customer return history
router.get('/returns/my', authenticate, authorize('customer'), async (req, res) => {
  try {
    const requests = await ReturnRequest.findAll({
      where: { customerId: req.user._id.toString() },
      include: [{ model: Order, as: 'order' }],
      order: [['createdAt', 'DESC']],
    });
    res.json({ success: true, data: requests });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Shop return requests list
router.get('/returns/shop/:shopId', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const shopId = parseInt(req.params.shopId);
    if (req.user.role === 'shop_admin' && req.user.shopId !== shopId) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const { status } = req.query;
    const where = { shopId };
    if (status) where.status = status;

    const requests = await ReturnRequest.findAll({
      where,
      include: [{ model: Order, as: 'order' }],
      order: [['createdAt', 'DESC']],
    });

    res.json({ success: true, data: requests });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Shop approves/rejects return and processes refund/replacement metadata
router.put('/returns/:id/process', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const returnReq = await ReturnRequest.findByPk(req.params.id);
    if (!returnReq) return res.status(404).json({ success: false, message: 'Return not found' });
    if (req.user.role === 'shop_admin' && req.user.shopId !== returnReq.shopId) {
      return res.status(403).json({ success: false, message: 'Not your return request' });
    }

    const {
      decision, // approve | reject
      refundAmount,
      refundStatus,
      refundReference,
      notes,
    } = req.body;

    const updates = {};
    if (decision === 'approve') {
      updates.status = 'approved';
      updates.approvedAt = new Date();
    } else if (decision === 'reject') {
      updates.status = 'rejected';
    }

    if (refundAmount !== undefined) updates.refundAmount = refundAmount;
    if (refundStatus) updates.refundStatus = refundStatus;
    if (refundReference) updates.refundReference = refundReference;
    if (notes) updates.verificationNotes = `${returnReq.verificationNotes || ''}\n${notes}`.trim();

    await returnReq.update(updates);

    if (decision === 'approve' && returnReq.returnType === 'replace' && !returnReq.replacementOrderId) {
      const sourceOrder = await Order.findByPk(returnReq.orderId);
      const sourceItem = await OrderItem.findByPk(returnReq.orderItemId);
      if (sourceOrder && sourceItem) {
        const replacementOrder = await Order.create({
          orderNumber: generateOrderNumber(),
          customerId: sourceOrder.customerId,
          shopId: sourceOrder.shopId,
          status: 'confirmed',
          subtotal: sourceItem.total,
          discount: sourceItem.total,
          deliveryFee: 0,
          tax: 0,
          total: 0,
          deliveryAddress: sourceOrder.deliveryAddress,
          paymentMethod: 'cod',
          paymentStatus: 'paid',
          notes: `Replacement for return request #${returnReq.id}`,
        });

        await OrderItem.create({
          orderId: replacementOrder.id,
          productId: sourceItem.productId,
          productName: sourceItem.productName,
          quantity: sourceItem.quantity,
          price: sourceItem.price,
          size: sourceItem.size,
          color: sourceItem.color,
          total: sourceItem.total,
        });

        await returnReq.update({ replacementOrderId: replacementOrder.id });
      }
    }

    res.json({ success: true, data: returnReq });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Shop creates day-end return pickup plan in batch
router.post('/returns/day-end-plan', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const { shopId, returnRequestIds = [], pickupDate } = req.body;
    const parsedShopId = parseInt(shopId);
    if (!parsedShopId) return res.status(400).json({ success: false, message: 'shopId required' });
    if (req.user.role === 'shop_admin' && req.user.shopId !== parsedShopId) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const where = {
      shopId: parsedShopId,
      status: { [Op.in]: ['requested', 'approved'] },
    };
    if (Array.isArray(returnRequestIds) && returnRequestIds.length > 0) {
      where.id = { [Op.in]: returnRequestIds.map((id) => parseInt(id)).filter(Boolean) };
    }

    const requests = await ReturnRequest.findAll({ where });
    if (requests.length === 0) {
      return res.status(400).json({ success: false, message: 'No eligible return requests for planning' });
    }

    const batchDate = pickupDate ? new Date(pickupDate) : new Date();
    const io = req.app.get('io');
    const createdTasks = [];

    for (const request of requests) {
      const order = await Order.findByPk(request.orderId, { include: [{ model: Shop, as: 'shop' }] });
      if (!order || !order.shop) continue;

      const existingTask = await DeliveryTask.findOne({
        where: {
          orderId: request.orderId,
          taskType: 'return_pickup',
          status: { [Op.notIn]: ['completed', 'cancelled', 'failed'] },
        },
      });

      if (!existingTask) {
        const task = await DeliveryTask.create({
          orderId: request.orderId,
          shopId: request.shopId,
          taskType: 'return_pickup',
          status: 'pending',
          pickupLocation: {
            address: `${order.shop.addressLine1}, ${order.shop.city}`,
            latitude: parseFloat(order.shop.latitude),
            longitude: parseFloat(order.shop.longitude),
          },
          dropLocation: order.deliveryAddress || {},
          pickupOtp: generateOtp(),
          deliveryOtp: generateOtp(),
          notes: `Day-end return pickup batch: ${batchDate.toISOString()}`,
        });
        createdTasks.push(task.id);
      }

      await request.update({ status: 'pickup_assigned', pickupBatchDate: batchDate });
    }

    io.to(`shop_${parsedShopId}`).emit('return_batch_planned', {
      shopId: parsedShopId,
      pickupBatchDate: batchDate,
      count: requests.length,
    });

    res.json({
      success: true,
      message: 'Day-end return pickup plan created',
      data: {
        shopId: parsedShopId,
        pickupBatchDate: batchDate,
        returnRequestCount: requests.length,
        createdTaskIds: createdTasks,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Process return verification (delivery agent)
router.put('/returns/:id/verify', authenticate, authorize('delivery_agent'), async (req, res) => {
  try {
    const returnReq = await ReturnRequest.findByPk(req.params.id);
    if (!returnReq) return res.status(404).json({ success: false, message: 'Return not found' });

    const { verificationChecklist, verificationNotes, verificationImages } = req.body;

    await returnReq.update({
      verificationChecklist,
      verificationNotes,
      verificationImages: verificationImages || [],
      status: 'picked_up',
    });

    const io = req.app.get('io');
    io.to(`shop_${returnReq.shopId}`).emit('return_verified', {
      returnId: returnReq.id,
      checklist: verificationChecklist,
    });

    res.json({ success: true, data: returnReq });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Shop tasks (for shop app)
router.get('/shop-tasks/:shopId', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const shopId = parseInt(req.params.shopId);
    const { status, taskType, page = 1, limit = 20 } = req.query;
    const where = { shopId };
    if (status) where.status = status;
    if (taskType) where.taskType = taskType;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const tasks = await DeliveryTask.findAndCountAll({
      where,
      include: [{ model: Order, as: 'order' }],
      limit: parseInt(limit),
      offset,
      order: [['createdAt', 'DESC']],
    });

    res.json({
      success: true,
      data: tasks.rows,
      pagination: {
        total: tasks.count,
        page: parseInt(page),
        pages: Math.ceil(tasks.count / parseInt(limit)),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
