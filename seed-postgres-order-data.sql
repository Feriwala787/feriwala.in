INSERT INTO categories (name, slug, description, "isActive", "createdAt", "updatedAt")
VALUES ('General', 'general', 'General category', true, NOW(), NOW())
ON CONFLICT (slug) DO UPDATE SET "updatedAt" = NOW();

INSERT INTO shops (
  name, code, description, phone, email,
  "addressLine1", city, state, pincode,
  latitude, longitude, "isActive",
  "deliveryRadiusKm", "minOrderAmount", "deliveryFee",
  rating, "totalRatings", "createdAt", "updatedAt"
)
VALUES (
  'Feriwala Test Shop', 'FWTESTSHOP', 'Seeded test shop', '9999999999', 'shop@feriwala.test',
  'Test Address Line 1', 'Delhi', 'Delhi', '110001',
  28.6139, 77.2090, true,
  5, 0, 20,
  5.00, 0, NOW(), NOW()
)
ON CONFLICT (code) DO UPDATE SET "isActive" = true, "updatedAt" = NOW();

WITH c AS (
  SELECT id AS category_id FROM categories WHERE slug = 'general' LIMIT 1
), s AS (
  SELECT id AS shop_id FROM shops WHERE code = 'FWTESTSHOP' LIMIT 1
)
INSERT INTO products (
  "shopId", "categoryId", name, slug, description, brand, sku,
  mrp, "sellingPrice", discount, size, color, material, gender,
  images, tags, attributes, "isActive", "isFeatured", "avgRating", "totalReviews",
  "createdAt", "updatedAt"
)
SELECT
  s.shop_id, c.category_id, 'Test Product', 'test-product', 'Seeded test product', 'Feriwala', 'FW-TEST-001',
  199.00, 149.00, 0, 'M', 'Blue', 'Cotton', 'unisex',
  '[]'::jsonb, '[]'::jsonb, '{}'::jsonb, true, false, 0, 0,
  NOW(), NOW()
FROM s, c
ON CONFLICT (slug) DO UPDATE SET "updatedAt" = NOW();

WITH s AS (
  SELECT id AS shop_id FROM shops WHERE code = 'FWTESTSHOP' LIMIT 1
), p AS (
  SELECT id AS product_id FROM products WHERE slug = 'test-product' LIMIT 1
)
INSERT INTO inventory (
  "productId", "shopId", quantity, "reservedQuantity", "lowStockThreshold", "createdAt", "updatedAt"
)
SELECT p.product_id, s.shop_id, 50, 0, 5, NOW(), NOW()
FROM s, p
ON CONFLICT ("productId", "shopId") DO UPDATE
SET quantity = GREATEST(inventory.quantity, 50), "updatedAt" = NOW();

SELECT id, code, name, "isActive" FROM shops WHERE code = 'FWTESTSHOP';
SELECT id, slug, name, "shopId", "categoryId", "isActive" FROM products WHERE slug = 'test-product';
SELECT id, "productId", "shopId", quantity, "reservedQuantity" FROM inventory WHERE "shopId" = (SELECT id FROM shops WHERE code = 'FWTESTSHOP');
