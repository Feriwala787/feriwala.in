const DeliveryTask = require('../models/pg/DeliveryTask');
const Order = require('../models/pg/Order');
const Shop = require('../models/pg/Shop');
const DeliveryAgentProfile = require('../models/mongo/DeliveryAgentProfile');
const { calculateDistance, generateOtp } = require('../utils/helpers');

async function createOrAssignDeliveryTask({ orderId, io = null }) {
  const order = await Order.findByPk(orderId, {
    include: [{ model: Shop, as: 'shop' }],
  });
  if (!order || !order.shop) {
    throw new Error('Order/shop not found for delivery task');
  }

  const existing = await DeliveryTask.findOne({
    where: { orderId: order.id, taskType: 'delivery' },
    order: [['createdAt', 'DESC']],
  });

  if (existing && !['cancelled', 'failed', 'completed'].includes(existing.status)) {
    return existing;
  }

  const shopLat = Number(order.shop.latitude || 0);
  const shopLng = Number(order.shop.longitude || 0);

  const availableAgents = await DeliveryAgentProfile.find({
    isOnline: true,
    isAvailable: true,
    assignedShopId: { $in: [order.shopId, null] },
  }).populate({ path: 'userId', model: 'User' });

  const agentsWithDistance = availableAgents
    .map((agent) => ({
      agent,
      distance: agent.currentLocation?.latitude
        ? calculateDistance(shopLat, shopLng, agent.currentLocation.latitude, agent.currentLocation.longitude)
        : Number.POSITIVE_INFINITY,
    }))
    .sort((a, b) => a.distance - b.distance);

  const selectedAgent = agentsWithDistance.length > 0 ? agentsWithDistance[0] : null;

  const pickupLocation = {
    address: `${order.shop.addressLine1}, ${order.shop.city}`,
    latitude: shopLat,
    longitude: shopLng,
  };

  const dropLocation = order.deliveryAddress || {};

  const task = await DeliveryTask.create({
    orderId: order.id,
    shopId: order.shopId,
    agentId: selectedAgent?.agent.userId?._id?.toString() || null,
    taskType: 'delivery',
    status: selectedAgent ? 'assigned' : 'pending',
    pickupLocation,
    dropLocation,
    pickupOtp: generateOtp(),
    deliveryOtp: generateOtp(),
    assignedAt: selectedAgent ? new Date() : null,
    distanceKm: selectedAgent?.distance,
    estimatedMinutes: selectedAgent ? Math.ceil((selectedAgent.distance / 20) * 60) : null,
  });

  if (selectedAgent) {
    await DeliveryAgentProfile.findByIdAndUpdate(selectedAgent.agent._id, { isAvailable: false });
  }

  if (io) {
    io.to(`shop_${order.shopId}`).emit('delivery_task_created', {
      orderId: order.id,
      taskId: task.id,
      status: task.status,
      agentId: task.agentId,
    });

    if (task.agentId) {
      io.to(`agent_${task.agentId}`).emit('new_task', {
        taskId: task.id,
        taskType: task.taskType,
        orderId: task.orderId,
      });
    }

    io.to(`customer_${order.customerId}`).emit('delivery_task_status', {
      orderId: order.id,
      taskId: task.id,
      status: task.status,
    });
  }

  return task;
}

module.exports = { createOrAssignDeliveryTask };
