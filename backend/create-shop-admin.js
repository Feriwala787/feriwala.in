require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./src/models/mongo/User');

async function main() {
  await mongoose.connect(process.env.MONGODB_URI);

  const shopAdmin = {
    name: 'Test Shop Admin',
    email: 'shopadmin@feriwala.test',
    phone: '9300000001',
    loginId: 'shopadmin',
    password: 'Feriwala@123',
    role: 'shop_admin',
    shopId: 1, // Feriwala Test Shop
  };

  let user = await User.findOne({ $or: [{ email: shopAdmin.email }, { loginId: shopAdmin.loginId }] });

  if (!user) {
    user = new User({
      name: shopAdmin.name,
      email: shopAdmin.email,
      phone: shopAdmin.phone,
      loginId: shopAdmin.loginId,
      passwordHash: shopAdmin.password,
      role: shopAdmin.role,
      shopId: shopAdmin.shopId,
      isActive: true,
      isVerified: true,
    });
  } else {
    user.role = shopAdmin.role;
    user.shopId = shopAdmin.shopId;
    user.passwordHash = shopAdmin.password;
    user.isActive = true;
  }

  await user.save();
  console.log('SHOP_ADMIN_READY');
  console.log(`email=${shopAdmin.email}`);
  console.log(`loginId=${shopAdmin.loginId}`);
  console.log(`phone=${shopAdmin.phone}`);
  console.log(`shopId=${shopAdmin.shopId}`);
  console.log('role=shop_admin');

  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error(err.message);
  await mongoose.disconnect();
  process.exit(1);
});
