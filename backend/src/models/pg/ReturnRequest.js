const { DataTypes } = require('sequelize');
const { sequelize } = require('../../database/postgres');

const ReturnRequest = sequelize.define('ReturnRequest', {
  id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  orderId: { type: DataTypes.INTEGER, allowNull: false },
  orderItemId: { type: DataTypes.INTEGER, allowNull: false },
  shopId: { type: DataTypes.INTEGER, allowNull: false },
  customerId: { type: DataTypes.STRING(30), allowNull: false },
  returnType: { type: DataTypes.ENUM('return', 'replace'), defaultValue: 'return' },
  reason: { type: DataTypes.TEXT, allowNull: false },
  status: {
    type: DataTypes.ENUM('requested', 'approved', 'pickup_assigned', 'picked_up', 'inspecting', 'completed', 'rejected'),
    defaultValue: 'requested',
  },
  // Verification checklist filled by delivery agent
  verificationChecklist: {
    type: DataTypes.JSONB,
    defaultValue: {
      tagsIntact: false,
      noStains: false,
      noTears: false,
      originalPackaging: false,
      matchesOrder: false,
      notWorn: false,
    },
  },
  verificationNotes: { type: DataTypes.TEXT },
  verificationImages: { type: DataTypes.JSONB, defaultValue: [] },
  refundAmount: { type: DataTypes.DECIMAL(10, 2) },
  refundStatus: { type: DataTypes.ENUM('pending', 'processed', 'failed'), defaultValue: 'pending' },
  bankDetails: { type: DataTypes.JSONB, defaultValue: {} },
  replacementPreference: { type: DataTypes.JSONB, defaultValue: {} },
  refundReference: { type: DataTypes.STRING(120) },
  pickupBatchDate: { type: DataTypes.DATE },
  replacementOrderId: { type: DataTypes.INTEGER },
  approvedAt: { type: DataTypes.DATE },
  completedAt: { type: DataTypes.DATE },
}, {
  tableName: 'return_requests',
  timestamps: true,
  indexes: [
    { fields: ['orderId'] },
    { fields: ['shopId'] },
    { fields: ['customerId'] },
    { fields: ['status'] },
  ],
});

module.exports = ReturnRequest;
