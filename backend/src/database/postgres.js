const { Sequelize } = require('sequelize');

const sequelize = new Sequelize(
  process.env.PG_DATABASE,
  process.env.PG_USER,
  process.env.PG_PASSWORD,
  {
    host: process.env.PG_HOST || 'localhost',
    port: process.env.PG_PORT || 5432,
    dialect: 'postgres',
    dialectOptions: {
      connectTimeout: parseInt(process.env.PG_CONNECT_TIMEOUT_MS || '5000', 10),
    },
    logging: process.env.NODE_ENV === 'development' ? console.log : false,
    pool: {
      max: 20,
      min: 5,
      acquire: parseInt(process.env.PG_POOL_ACQUIRE_TIMEOUT_MS || '10000', 10),
      idle: 10000,
    },
  }
);

async function connectPostgres() {
  await sequelize.authenticate();
}

async function syncModels() {
  // Import all models to register them
  require('../models/pg/Shop');
  require('../models/pg/Product');
  require('../models/pg/Category');
  require('../models/pg/Order');
  require('../models/pg/OrderItem');
  require('../models/pg/PromoCode');
  require('../models/pg/Invoice');
  require('../models/pg/DeliveryTask');
  require('../models/pg/ReturnRequest');
  require('../models/pg/Inventory');

  // Setup associations
  require('../models/pg/associations');

  await sequelize.sync({ alter: process.env.NODE_ENV === 'development' });
}

module.exports = { sequelize, connectPostgres, syncModels };
