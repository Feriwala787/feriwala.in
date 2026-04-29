const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate, authorize } = require('../middleware/auth');
const { routeError } = require('../utils/routeError');
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
const MAX_ACTIVE_TASKS_PER_AGENT = 4;
const STALLED_TASK_MINUTES = 20;
const LONG_TRANSIT_MINUTES = 45;

async function getAgentLoadMap(agentIds = []) {
  if (agentIds.length === 0) return {};
  const rows = await DeliveryTask.findAll({
    attributes: ['agentId', 'status', 'createdAt', 'shopId'],
    where: {
      agentId: { [Op.in]: agentIds },
      status: { [Op.notIn]: ['completed', 'cancelled', 'failed'] },
    },
  });

  const map = {};
  for (const row of rows) {
    const id = row.agentId;
    if (!map[id]) map[id] = { activeTaskCount: 0, hasRecentSameShopTask: false };
    map[id].activeTaskCount += 1;
  }
  return map;
}

function getSlaStatus(task) {
  const now = Date.now();
  const createdAt = new Date(task.createdAt).getTime();
  const mins = Math.floor((now - createdAt) / 60000);
  if (['assigned', 'accepted', 'picking'].includes(task.status) && mins >= STALLED_TASK_MINUTES) {
    return { level: 'warning', reason: 'pickup_delayed', ageMinutes: mins };
  }
  if (task.status === 'in_transit' && mins >= LONG_TRANSIT_MINUTES) {
    return { level: 'critical', reason: 'in_transit_delayed', ageMinutes: mins };
  }
  return { level: 'normal', reason: 'on_time', ageMinutes: mins };
}

async function getNearbyAvailableAgents({ shopId, shopLat, shopLng }) {
  const availableAgents = await DeliveryAgentProfile.find({
    isOnline: true,
    isAvailable: true,
    assignedShopId: { $in: [shopId, null] },
  }).populate({ path: 'userId', model: 'User' });

  const agentIds = availableAgents.map((a) => a.userId?._id?.toString()).filter(Boolean);
  const loadMap = await getAgentLoadMap(agentIds);

  return availableAgents.map((agent) => {
    const lat = agent.currentLocation?.latitude;
    const lng = agent.currentLocation?.longitude;
    const distance = (lat && lng)
      ? calculateDistance(shopLat, shopLng, lat, lng)
      : Infinity;
    const id = agent.userId?._id?.toString();
    const activeTaskCount = loadMap[id]?.activeTaskCount ?? 0;
    const routeBonus = activeTaskCount > 0 ? 0.5 : 0;
    const score = Number.isFinite(distance) ? Math.max(0, distance - routeBonus) : Infinity;
    return { agent, distance, activeTaskCount, canTakeMoreTasks: activeTaskCount < MAX_ACTIVE_TASKS_PER_AGENT, score };
  }).sort((a, b) => a.distance - b.distance);
}

// Nearby available agents for a shop (shop + customer visibility)
router.get('/agents/nearby/:shopId', authenticate, authorize('shop_admin', 'admin', 'customer'), async (req, res) => {
  try {
    const shopId = parseInt(req.params.shopId);
    if (!shopId) return res.status(400).json({ success: false, message: 'Invalid shopId' });

    const shop = await Shop.findByPk(shopId);
    if (!shop) return res.status(404).json({ success: false, message: 'Shop not found' });
    if (req.user.role === 'shop_admin' && req.user.shopId !== shopId) {
      return res.status(403).json({ success: false, message: 'Not your shop' });
    }

    const shopLat = parseFloat(shop.latitude);
    const shopLng = parseFloat(shop.longitude);
    if (Number.isNaN(shopLat) || Number.isNaN(shopLng)) {
      return res.status(400).json({ success: false, message: 'Shop location missing' });
    }

    const agents = await getNearbyAvailableAgents({ shopId, shopLat, shopLng });
    const data = agents.map(({ agent, distance, activeTaskCount, canTakeMoreTasks }) => ({
      agentId: agent.userId?._id?.toString(),
      name: agent.userId?.name || 'Delivery Agent',
      phone: agent.userId?.phone || null,
      vehicleType: agent.vehicleType,
      rating: agent.rating,
      distanceKm: Number.isFinite(distance) ? Number(distance.toFixed(2)) : null,
      activeTaskCount,
      canTakeMoreTasks,
      currentLocation: agent.currentLocation || null,
    }));

    res.json({ success: true, data });
  } catch (error) {
    routeError(res, error);
  }
});

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

    const agentsWithDistance = await getNearbyAvailableAgents({ shopId: order.shopId, shopLat, shopLng });

    const candidateAgents = agentsWithDistance
      .filter((a) => a.canTakeMoreTasks)
      .sort((a, b) => a.score - b.score);
    const selectedAgent = candidateAgents.length > 0 ? candidateAgents[0] : null;

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
    routeError(res, error);
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
    routeError(res, error);
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
    routeError(res, error);
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
    if (status === 'completed' && task.taskType === 'delivery') {
      const orderForOtp = await Order.findByPk(task.orderId, { attributes: ['paymentMethod'] });
      const requiresOtp = orderForOtp && orderForOtp.paymentMethod !== 'cod';
      if (requiresOtp && otp !== task.deliveryOtp) {
        return res.status(400).json({ success: false, message: 'Invalid delivery OTP' });
      }
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
    routeError(res, error);
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
    routeError(res, error);
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
    routeError(res, error);
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
    routeError(res, error);
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
    routeError(res, error);
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
    routeError(res, error);
  }
});

// Order delivery status with assigned agent details (customer + shop)
router.get('/order/:orderId/status', authenticate, authorize('customer', 'shop_admin', 'admin'), async (req, res) => {
  try {
    const orderId = parseInt(req.params.orderId);
    const order = await Order.findByPk(orderId);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found' });

    if (req.user.role === 'customer' && order.customerId !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
    if (req.user.role === 'shop_admin' && req.user.shopId !== order.shopId) {
      return res.status(403).json({ success: false, message: 'Not your order' });
    }

    const task = await DeliveryTask.findOne({
      where: {
        orderId,
        status: { [Op.notIn]: ['cancelled', 'failed'] },
      },
      order: [['createdAt', 'DESC']],
    });
    if (!task) return res.json({ success: true, data: null });

    let agent = null;
    if (task.agentId) {
      const profile = await DeliveryAgentProfile.findOne({ userId: task.agentId }).populate({ path: 'userId', model: 'User' });
      if (profile) {
        agent = {
          agentId: profile.userId?._id?.toString(),
          name: profile.userId?.name || 'Delivery Agent',
          phone: profile.userId?.phone || null,
          rating: profile.rating,
          vehicleType: profile.vehicleType,
          locationUpdatedAt: profile.currentLocation?.updatedAt || null,
          currentLocation: profile.currentLocation || null,
        };
      }
    }

    res.json({
      success: true,
      data: {
        taskId: task.id,
        taskType: task.taskType,
        status: task.status,
        assignedAt: task.assignedAt,
        estimatedMinutes: task.estimatedMinutes,
        distanceKm: task.distanceKm,
        sla: getSlaStatus(task),
        agent,
      },
    });
  } catch (error) {
    routeError(res, error);
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
    routeError(res, error);
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
    routeError(res, error);
  }
});

// Shop creates day-end return pickup plan in batch
router.post('/returns/day-end-plan', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const { shopId, returnRequestIds = [], pickupDate, preferredAgentId } = req.body;
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
    let assignedCount = 0;
    let selectedAgent = null;

    if (preferredAgentId) {
      selectedAgent = await DeliveryAgentProfile.findOne({
        userId: preferredAgentId,
        isOnline: true,
        assignedShopId: { $in: [parsedShopId, null] },
      }).populate({ path: 'userId', model: 'User' });
      if (!selectedAgent) {
        return res.status(400).json({ success: false, message: 'Preferred agent is not available' });
      }
      const load = await getAgentLoadMap([preferredAgentId.toString()]);
      const activeCount = load[preferredAgentId.toString()]?.activeTaskCount ?? 0;
      if (activeCount >= MAX_ACTIVE_TASKS_PER_AGENT) {
        return res.status(400).json({ success: false, message: 'Preferred agent reached active task capacity' });
      }
    }

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
        let taskAgentId = null;
        let taskStatus = 'pending';
        let taskDistanceKm = null;
        let taskEstimatedMinutes = null;

        if (selectedAgent) {
          taskAgentId = selectedAgent.userId?._id?.toString() || null;
          taskStatus = taskAgentId ? 'assigned' : 'pending';
          const aLat = selectedAgent.currentLocation?.latitude;
          const aLng = selectedAgent.currentLocation?.longitude;
          const sLat = parseFloat(order.shop.latitude);
          const sLng = parseFloat(order.shop.longitude);
          if (aLat != null && aLng != null && !Number.isNaN(sLat) && !Number.isNaN(sLng)) {
            const d = calculateDistance(sLat, sLng, aLat, aLng);
            taskDistanceKm = d;
            taskEstimatedMinutes = Math.ceil((d / 20) * 60);
          }
        }

        const task = await DeliveryTask.create({
          orderId: request.orderId,
          shopId: request.shopId,
          taskType: 'return_pickup',
          agentId: taskAgentId,
          status: taskStatus,
          pickupLocation: {
            address: `${order.shop.addressLine1}, ${order.shop.city}`,
            latitude: parseFloat(order.shop.latitude),
            longitude: parseFloat(order.shop.longitude),
          },
          dropLocation: order.deliveryAddress || {},
          pickupOtp: generateOtp(),
          deliveryOtp: generateOtp(),
          notes: `Day-end return pickup batch: ${batchDate.toISOString()}`,
          assignedAt: taskAgentId ? new Date() : null,
          distanceKm: taskDistanceKm,
          estimatedMinutes: taskEstimatedMinutes,
        });
        createdTasks.push(task.id);

        if (taskAgentId) {
          assignedCount += 1;
          io.to(`agent_${taskAgentId}`).emit('new_task', {
            taskId: task.id,
            taskType: task.taskType,
            orderId: task.orderId,
          });
        }
      }

      await request.update({ status: 'pickup_assigned', pickupBatchDate: batchDate });
    }

    io.to(`shop_${parsedShopId}`).emit('return_batch_planned', {
      shopId: parsedShopId,
      pickupBatchDate: batchDate,
      count: requests.length,
      assignedCount,
    });

    if (selectedAgent) {
      await DeliveryAgentProfile.findByIdAndUpdate(selectedAgent._id, { isAvailable: false });
    }

    res.json({
      success: true,
      message: 'Day-end return pickup plan created',
      data: {
        shopId: parsedShopId,
        pickupBatchDate: batchDate,
        returnRequestCount: requests.length,
        createdTaskIds: createdTasks,
        assignedCount,
        preferredAgentId: selectedAgent?.userId?._id?.toString() || null,
      },
    });
  } catch (error) {
    routeError(res, error);
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
    routeError(res, error);
  }
});

// Manual task reassignment (shop/admin)
router.put('/tasks/:id/reassign', authenticate, authorize('shop_admin', 'admin'), async (req, res) => {
  try {
    const task = await DeliveryTask.findByPk(req.params.id, { include: [{ model: Shop, as: 'shop' }] });
    if (!task) return res.status(404).json({ success: false, message: 'Task not found' });
    if (req.user.role === 'shop_admin' && req.user.shopId !== task.shopId) {
      return res.status(403).json({ success: false, message: 'Not your task' });
    }
    if (['completed', 'cancelled', 'failed'].includes(task.status)) {
      return res.status(400).json({ success: false, message: 'Cannot reassign closed tasks' });
    }

    const { newAgentId } = req.body;
    const shopLat = parseFloat(task.shop?.latitude);
    const shopLng = parseFloat(task.shop?.longitude);
    let targetAgentProfile = null;

    if (newAgentId) {
      targetAgentProfile = await DeliveryAgentProfile.findOne({
        userId: newAgentId,
        isOnline: true,
        assignedShopId: { $in: [task.shopId, null] },
      }).populate({ path: 'userId', model: 'User' });
    } else {
      const candidates = await getNearbyAvailableAgents({ shopId: task.shopId, shopLat, shopLng });
      targetAgentProfile = candidates.find((c) => c.canTakeMoreTasks)?.agent || null;
    }

    if (!targetAgentProfile || !targetAgentProfile.userId?._id) {
      return res.status(400).json({ success: false, message: 'No eligible agent available for reassignment' });
    }

    const newAgentIdString = targetAgentProfile.userId._id.toString();
    if (task.agentId && task.agentId !== newAgentIdString) {
      await DeliveryAgentProfile.findOneAndUpdate({ userId: task.agentId }, { isAvailable: true });
    }

    const aLat = targetAgentProfile.currentLocation?.latitude;
    const aLng = targetAgentProfile.currentLocation?.longitude;
    const distanceKm = (aLat != null && aLng != null && !Number.isNaN(shopLat) && !Number.isNaN(shopLng))
      ? calculateDistance(shopLat, shopLng, aLat, aLng)
      : null;

    await task.update({
      agentId: newAgentIdString,
      status: 'assigned',
      assignedAt: new Date(),
      acceptedAt: null,
      distanceKm,
      estimatedMinutes: distanceKm ? Math.ceil((distanceKm / 20) * 60) : null,
    });

    await DeliveryAgentProfile.findByIdAndUpdate(targetAgentProfile._id, { isAvailable: false });

    const io = req.app.get('io');
    io.to(`agent_${newAgentIdString}`).emit('new_task', {
      taskId: task.id,
      taskType: task.taskType,
      orderId: task.orderId,
      reassigned: true,
    });
    io.to(`shop_${task.shopId}`).emit('task_reassigned', { taskId: task.id, agentId: newAgentIdString });

    res.json({ success: true, data: task });
  } catch (error) {
    routeError(res, error);
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

    const data = tasks.rows.map((task) => ({
      ...task.toJSON(),
      sla: getSlaStatus(task),
    }));

    res.json({
      success: true,
      data,
      pagination: {
        total: tasks.count,
        page: parseInt(page),
        pages: Math.ceil(tasks.count / parseInt(limit)),
      },
    });
  } catch (error) {
    routeError(res, error);
  }
});

module.exports = router;
