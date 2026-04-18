const mongoose = require('mongoose');

async function connectMongoDB() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI not set in environment');

  await mongoose.connect(uri, {
    maxPoolSize: 10,
    serverSelectionTimeoutMS: parseInt(process.env.MONGO_SERVER_SELECTION_TIMEOUT_MS || '5000', 10),
    connectTimeoutMS: parseInt(process.env.MONGO_CONNECT_TIMEOUT_MS || '5000', 10),
    socketTimeoutMS: parseInt(process.env.MONGO_SOCKET_TIMEOUT_MS || '20000', 10),
  });
}

function isMongoReady() {
  return mongoose.connection.readyState === 1;
}

module.exports = { connectMongoDB, mongoose, isMongoReady };
