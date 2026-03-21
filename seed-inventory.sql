WITH s AS (
  SELECT id AS shop_id FROM shops WHERE code='FWTESTSHOP' LIMIT 1
), p AS (
  SELECT id AS product_id FROM products WHERE slug='test-product' LIMIT 1
)
UPDATE inventory i
SET quantity = GREATEST(i.quantity, 50), "updatedAt" = NOW()
FROM s, p
WHERE i."productId" = p.product_id AND i."shopId" = s.shop_id;

WITH s AS (
  SELECT id AS shop_id FROM shops WHERE code='FWTESTSHOP' LIMIT 1
), p AS (
  SELECT id AS product_id FROM products WHERE slug='test-product' LIMIT 1
)
INSERT INTO inventory ("productId", "shopId", quantity, "reservedQuantity", "lowStockThreshold", "createdAt", "updatedAt")
SELECT p.product_id, s.shop_id, 50, 0, 5, NOW(), NOW()
FROM s, p
WHERE NOT EXISTS (
  SELECT 1 FROM inventory i WHERE i."productId" = p.product_id AND i."shopId" = s.shop_id
);

SELECT id, "productId", "shopId", quantity, "reservedQuantity" FROM inventory WHERE "shopId"=(SELECT id FROM shops WHERE code='FWTESTSHOP');
