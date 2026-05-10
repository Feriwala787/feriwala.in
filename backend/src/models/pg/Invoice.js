const { DataTypes } = require('sequelize');
const { sequelize } = require('../../database/postgres');

const Invoice = sequelize.define('Invoice', {
  id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  invoiceNumber: { type: DataTypes.STRING(50), allowNull: false, unique: true },
  orderId: { type: DataTypes.INTEGER, allowNull: false },
  shopId: { type: DataTypes.INTEGER, allowNull: false },
  customerId: { type: DataTypes.STRING(30), allowNull: false },
  subtotal: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  discount: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  tax: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  deliveryFee: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  total: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  paymentMethod: { type: DataTypes.STRING(20) },
  paymentStatus: { type: DataTypes.STRING(20), defaultValue: 'pending' },
  items: { type: DataTypes.JSONB, allowNull: false },
  customerDetails: { type: DataTypes.JSONB },
  shopDetails: { type: DataTypes.JSONB },
}, {
  tableName: 'invoices',
  timestamps: true,
  indexes: [
    { fields: ['orderId'] },
    { fields: ['shopId'] },
    { fields: ['customerId'] },
  ],
});

module.exports = Invoice;
