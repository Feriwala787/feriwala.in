// Run: node seed-categories.js
require('dotenv').config();
const { sequelize } = require('./src/database/postgres');
const Category = require('./src/models/pg/Category');

const CATEGORIES = [
  { id: 1, name: 'Clothing', slug: 'clothing', description: 'All apparel — shirts, t-shirts, jeans, dresses, kurtas, etc.', sortOrder: 1 },
  { id: 2, name: 'Footwear', slug: 'footwear', description: 'Shoes, sandals, sneakers, boots, slippers, etc.', sortOrder: 2 },
];

const SUBCATEGORIES = [
  // Clothing
  { name: "Men's Clothing", slug: 'mens-clothing', parentId: 1, sortOrder: 1 },
  { name: "Women's Clothing", slug: 'womens-clothing', parentId: 1, sortOrder: 2 },
  { name: "Kids' Clothing", slug: 'kids-clothing', parentId: 1, sortOrder: 3 },
  // Footwear
  { name: "Men's Footwear", slug: 'mens-footwear', parentId: 2, sortOrder: 1 },
  { name: "Women's Footwear", slug: 'womens-footwear', parentId: 2, sortOrder: 2 },
  { name: "Kids' Footwear", slug: 'kids-footwear', parentId: 2, sortOrder: 3 },
];

(async () => {
  await sequelize.authenticate();
  for (const cat of CATEGORIES) {
    await Category.upsert(cat);
    console.log('Upserted:', cat.name);
  }
  for (const sub of SUBCATEGORIES) {
    const existing = await Category.findOne({ where: { slug: sub.slug } });
    if (!existing) {
      await Category.create(sub);
      console.log('Created subcategory:', sub.name);
    }
  }
  console.log('Done');
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
