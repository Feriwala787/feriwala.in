WITH c AS (
  SELECT id AS category_id FROM categories WHERE slug='general' LIMIT 1
), s AS (
  SELECT id AS shop_id FROM shops WHERE code='FWTESTSHOP' LIMIT 1
)
SELECT * FROM s, c;
