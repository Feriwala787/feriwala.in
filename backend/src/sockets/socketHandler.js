const jwt = require('jsonwebtoken');

module.exports = function socketHandler(io) {
  // Authenticate every socket connection before allowing room joins
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Authentication required'));
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.userId;
      next();
    } catch {
      next(new Error('Invalid or expired token'));
    }
  });

  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id} (user: ${socket.userId})`);

    socket.on('join_shop', (shopId) => {
      socket.join(`shop_${shopId}`);
    });

    socket.on('join_customer', (customerId) => {
      // Only allow joining your own customer room
      if (customerId !== socket.userId) return;
      socket.join(`customer_${customerId}`);
    });

    socket.on('join_agent', (agentId) => {
      // Only allow joining your own agent room
      if (agentId !== socket.userId) return;
      socket.join(`agent_${agentId}`);
    });

    // Delivery agent location updates — only the agent can broadcast their own location
    socket.on('agent_location', (data) => {
      const { agentId, latitude, longitude, taskId, shopId } = data;
      if (agentId !== socket.userId) return;
      if (shopId) {
        io.to(`shop_${shopId}`).emit('agent_location_update', { agentId, latitude, longitude, taskId });
      }
      if (data.customerId) {
        io.to(`customer_${data.customerId}`).emit('agent_location_update', { agentId, latitude, longitude, taskId });
      }
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });
  });
};
