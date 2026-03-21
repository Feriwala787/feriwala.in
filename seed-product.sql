WITH c AS (
  SELECT id AS category_id FROM categories WHERE slug='general' LIMIT 1
), s AS (
  SELECT id AS shop_id FROM shops WHERE code='FWTESTSHOP' LIMIT 1
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
ON CONFLICT DO NOTHING;

SELECT id, slug, name, "shopId", "categoryId", "isActive" FROM products WHERE slug='test-product';
