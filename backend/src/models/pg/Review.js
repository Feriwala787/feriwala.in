const { DataTypes } = require('sequelize');
const { sequelize } = require('../../database/postgres');

const Review = sequelize.define('Review', {
  id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  productId: { type: DataTypes.INTEGER, allowNull: false },
  orderId: { type: DataTypes.INTEGER, allowNull: false },
  customerId: { type: DataTypes.STRING(30), allowNull: false }, // MongoDB User _id
  rating: { type: DataTypes.INTEGER, allowNull: false }, // 1–5
  comment: { type: DataTypes.TEXT },
}, {
  tableName: 'reviews',
  timestamps: true,
  indexes: [
    { fields: ['productId'] },
    { fields: ['customerId'] },
    // One review per customer per order item
    { unique: true, fields: ['productId', 'orderId', 'customerId'] },
  ],
});

module.exports = Review;
