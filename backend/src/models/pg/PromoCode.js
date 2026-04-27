const { DataTypes } = require('sequelize');
const { sequelize } = require('../../database/postgres');

const PromoCode = sequelize.define('PromoCode', {
  id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  shopId: { type: DataTypes.INTEGER, allowNull: false },
  code: { type: DataTypes.STRING(30), allowNull: false },
  description: { type: DataTypes.TEXT },
  discountType: { type: DataTypes.ENUM('percentage', 'flat'), allowNull: false },
  discountValue: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  minOrderAmount: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0 },
  maxDiscount: { type: DataTypes.DECIMAL(10, 2) },
  usageLimit: { type: DataTypes.INTEGER, defaultValue: null },
  usedCount: { type: DataTypes.INTEGER, defaultValue: 0 },
  perUserLimit: { type: DataTypes.INTEGER, defaultValue: 1 },
  firstOrderOnly: { type: DataTypes.BOOLEAN, defaultValue: false },
  validFrom: { type: DataTypes.DATE, allowNull: false },
  validTo: { type: DataTypes.DATE, allowNull: false },
  isActive: { type: DataTypes.BOOLEAN, defaultValue: true },
  applicableCategories: { type: DataTypes.JSONB, defaultValue: [] },
}, {
  tableName: 'promo_codes',
  timestamps: true,
  indexes: [
    { unique: true, fields: ['shopId', 'code'] },
    { fields: ['isActive', 'validFrom', 'validTo'] },
  ],
});

module.exports = PromoCode;
