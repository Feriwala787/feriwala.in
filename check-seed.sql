SELECT id, code, name, "isActive" FROM shops WHERE code = 'FWTESTSHOP';
SELECT id, slug, name, "shopId", "categoryId", "isActive" FROM products WHERE slug = 'test-product';
SELECT id, "productId", "shopId", quantity, "reservedQuantity" FROM inventory WHERE "shopId" = (SELECT id FROM shops WHERE code = 'FWTESTSHOP');
