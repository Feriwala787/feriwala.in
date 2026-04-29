const Shop = require('./Shop');
const Category = require('./Category');
const Product = require('./Product');
const Inventory = require('./Inventory');
const Order = require('./Order');
const OrderItem = require('./OrderItem');
const PromoCode = require('./PromoCode');
const Invoice = require('./Invoice');
const DeliveryTask = require('./DeliveryTask');
const ReturnRequest = require('./ReturnRequest');
const Review = require('./Review');

// Shop -> Products
Shop.hasMany(Product, { foreignKey: 'shopId', as: 'products' });
Product.belongsTo(Shop, { foreignKey: 'shopId', as: 'shop' });

// Category -> Products
Category.hasMany(Product, { foreignKey: 'categoryId', as: 'products' });
Product.belongsTo(Category, { foreignKey: 'categoryId', as: 'category' });

// Category self-reference (parent/child)
Category.hasMany(Category, { foreignKey: 'parentId', as: 'subcategories' });
Category.belongsTo(Category, { foreignKey: 'parentId', as: 'parent' });

// Product -> Inventory
Product.hasMany(Inventory, { foreignKey: 'productId', as: 'inventory' });
Inventory.belongsTo(Product, { foreignKey: 'productId', as: 'product' });
Shop.hasMany(Inventory, { foreignKey: 'shopId', as: 'inventory' });
Inventory.belongsTo(Shop, { foreignKey: 'shopId', as: 'shop' });

// Shop -> Orders
Shop.hasMany(Order, { foreignKey: 'shopId', as: 'orders' });
Order.belongsTo(Shop, { foreignKey: 'shopId', as: 'shop' });

// Order -> OrderItems
Order.hasMany(OrderItem, { foreignKey: 'orderId', as: 'items' });
OrderItem.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });
Product.hasMany(OrderItem, { foreignKey: 'productId', as: 'orderItems' });
OrderItem.belongsTo(Product, { foreignKey: 'productId', as: 'product' });

// Shop -> PromoCodes
Shop.hasMany(PromoCode, { foreignKey: 'shopId', as: 'promoCodes' });
PromoCode.belongsTo(Shop, { foreignKey: 'shopId', as: 'shop' });
Order.belongsTo(PromoCode, { foreignKey: 'promoCodeId', as: 'promoCode' });

// Order -> Invoice
Order.hasOne(Invoice, { foreignKey: 'orderId', as: 'invoice' });
Invoice.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });
Shop.hasMany(Invoice, { foreignKey: 'shopId', as: 'invoices' });

// Order -> DeliveryTask
Order.hasMany(DeliveryTask, { foreignKey: 'orderId', as: 'deliveryTasks' });
DeliveryTask.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });
Shop.hasMany(DeliveryTask, { foreignKey: 'shopId', as: 'deliveryTasks' });
DeliveryTask.belongsTo(Shop, { foreignKey: 'shopId', as: 'shop' });

// Order -> ReturnRequest
Order.hasMany(ReturnRequest, { foreignKey: 'orderId', as: 'returnRequests' });
ReturnRequest.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });
OrderItem.hasMany(ReturnRequest, { foreignKey: 'orderItemId', as: 'returnRequests' });
ReturnRequest.belongsTo(OrderItem, { foreignKey: 'orderItemId', as: 'orderItem' });

// Product -> Reviews
Product.hasMany(Review, { foreignKey: 'productId', as: 'reviews' });
Review.belongsTo(Product, { foreignKey: 'productId', as: 'product' });
Order.hasMany(Review, { foreignKey: 'orderId', as: 'reviews' });
Review.belongsTo(Order, { foreignKey: 'orderId', as: 'order' });

module.exports = {
  Shop, Category, Product, Inventory,
  Order, OrderItem, PromoCode, Invoice,
  DeliveryTask, ReturnRequest, Review,
};
