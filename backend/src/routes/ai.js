const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { authenticate, authorize } = require('../middleware/auth');
const Product = require('../models/pg/Product');
const Inventory = require('../models/pg/Inventory');
const Category = require('../models/pg/Category');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });
const genAI = new GoogleGenerativeAI(process.env.Google_gemini_api);
const MODEL = 'gemini-3.1-flash-lite-preview';

const AI_PROMPT = (userPrompt) => `You are a product listing assistant for Feriwala, a quick-commerce clothing platform in India.
Analyze ALL provided product images carefully.${userPrompt ? ` Seller note: "${userPrompt}".` : ''}

Look at every image — different colours, angles, labels — and extract all details.

Return ONLY a valid JSON object, no markdown, no explanation:
{
  "name": "concise product name",
  "brand": "brand from label/tag or empty string",
  "description": "2-3 sentence product description",
  "shortDescription": "Material: X | Fit: Y | Use: Z",
  "productType": "one of: T-Shirt, Shirt, Polo Shirt, Kurta, Kurti, Jeans, Trousers, Chinos, Shorts, Track Pants, Joggers, Dress, Skirt, Leggings, Saree, Salwar Suit, Jacket, Hoodie, Sweatshirt, Blazer, Coat, Innerwear, Sleepwear, Swimwear",
  "gender": "one of: men, women, unisex, kids",
  "colors": ["list all visible colours from all images"],
  "sizes": ["S", "M", "L", "XL"],
  "material": "fabric material",
  "fit": "one of: Regular Fit, Slim Fit, Relaxed Fit, Oversized, Skinny Fit, Straight Fit, Tapered Fit",
  "pattern": "one of: Solid, Striped, Checked, Printed, Floral, Geometric, Abstract, Camouflage, Tie-Dye, Embroidered",
  "occasion": "one of: Casual, Formal, Party, Sports, Festive, Beach, Lounge, Workwear, Wedding",
  "sleeveType": "one of: Half Sleeve, Full Sleeve, Sleeveless, 3/4 Sleeve, Cap Sleeve, Raglan or empty",
  "neckType": "one of: Round Neck, V Neck, Collar, Polo Collar, Mandarin, Hooded, Boat Neck, Square Neck or empty",
  "tags": ["tag1", "tag2", "tag3"],
  "highlights": ["key feature 1", "key feature 2"],
  "mrp": "suggested MRP in INR as number only",
  "sellingPrice": "suggested selling price in INR as number only",
  "confidence": "high or medium or low"
}`;

// Save uploaded image buffers to disk and return public URLs
function saveImages(files) {
  const uploadDir = path.join(__dirname, '../../uploads');
  if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

  return files.map((f) => {
    const ext = f.mimetype === 'image/png' ? 'png' : 'jpg';
    const filename = `ai_${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`;
    fs.writeFileSync(path.join(uploadDir, filename), f.buffer);
    return `${process.env.SERVER_URL || 'http://65.2.9.216'}/uploads/${filename}`;
  });
}

// POST /api/ai/analyze-product — analyze images, return AI data (no DB write)
router.post('/analyze-product', upload.array('images', 15), async (req, res) => {
  try {
    if (!process.env.Google_gemini_api) return res.status(503).json({ success: false, message: 'AI service not configured' });
    const files = req.files || [];
    if (files.length === 0) return res.status(400).json({ success: false, message: 'At least one image is required' });

    const model = genAI.getGenerativeModel({ model: MODEL });
    const imageParts = files.map((f) => ({ inlineData: { data: f.buffer.toString('base64'), mimeType: f.mimetype } }));

    const result = await model.generateContent([AI_PROMPT(req.body.prompt || ''), ...imageParts]);
    const text = result.response.text();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return res.status(422).json({ success: false, message: 'AI could not extract product details from images' });

    const data = JSON.parse(jsonMatch[0]);
    // Normalize: admin portal expects `color` and `size` arrays
    data.color = data.colors || data.color || [];
    data.size = data.sizes || data.size || [];
    data.variantColors = data.color;
    res.json({ success: true, data });
  } catch (err) {
    console.error('AI analyze-product error:', err.message);
    res.status(500).json({ success: false, message: 'AI analysis failed: ' + err.message });
  }
});

// POST /api/ai/create-product — analyze + create product with user-defined variants/stock
router.post('/create-product', authenticate, authorize('shop_admin', 'admin'), upload.array('images', 15), async (req, res) => {
  try {
    if (!process.env.Google_gemini_api) return res.status(503).json({ success: false, message: 'AI service not configured' });

    const files = req.files || [];
    if (files.length === 0) return res.status(400).json({ success: false, message: 'At least one image required' });

    const shopId = req.user.shopId;
    if (!shopId) return res.status(400).json({ success: false, message: 'No shop assigned' });

    // Parse user-provided variant data: [{color, size, stock}]
    let variants = [];
    try { variants = JSON.parse(req.body.variants || '[]'); } catch (_) {}

    // 1. Analyze with Gemini
    const model = genAI.getGenerativeModel({ model: MODEL });
    const imageParts = files.map((f) => ({ inlineData: { data: f.buffer.toString('base64'), mimeType: f.mimetype } }));
    const result = await model.generateContent([AI_PROMPT(req.body.prompt || ''), ...imageParts]);
    const text = result.response.text();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return res.status(422).json({ success: false, message: 'AI could not extract product details' });

    const ai = JSON.parse(jsonMatch[0]);

    // 2. Save images to disk
    const imageUrls = saveImages(files);

    // 3. Category
    let categoryId = parseInt(req.body.categoryId || '0');
    if (!categoryId) {
      const cat = await Category.findOne({ where: { isActive: true }, order: [['sortOrder', 'ASC']] });
      categoryId = cat?.id || 1;
    }

    // 4. Build color/size from variants or AI
    const variantColors = variants.length > 0
      ? [...new Set(variants.map((v) => v.color).filter(Boolean))]
      : (Array.isArray(ai.colors) ? ai.colors : [ai.colors || '']);

    const variantSizes = variants.length > 0
      ? [...new Set(variants.map((v) => v.size).filter(Boolean))]
      : (Array.isArray(ai.sizes) ? ai.sizes : [ai.sizes || '']);

    const totalStock = variants.length > 0
      ? variants.reduce((sum, v) => sum + (parseInt(v.stock) || 0), 0)
      : parseInt(req.body.quantity || '0');

    const mrp = parseFloat(req.body.mrp || ai.mrp) || 499;
    const sellingPrice = parseFloat(req.body.sellingPrice || ai.sellingPrice) || 399;
    const discount = mrp > 0 ? (((mrp - sellingPrice) / mrp) * 100).toFixed(2) : 0;
    const slug = (req.body.name || ai.name || 'product').toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + Date.now();

    // 5. Create product
    const product = await Product.create({
      name: req.body.name || ai.name || 'New Product',
      brand: req.body.brand || ai.brand || '',
      description: req.body.description || ai.description || '',
      shortDescription: ai.shortDescription || '',
      gender: ai.gender || 'unisex',
      color: variantColors.join(', '),
      size: variantSizes.join(', '),
      material: ai.material || '',
      tags: ai.tags || [],
      images: imageUrls,
      mrp,
      sellingPrice,
      discount,
      slug,
      shopId,
      categoryId,
      isActive: true,
      attributes: {
        productType: ai.productType,
        fit: ai.fit,
        pattern: ai.pattern,
        occasion: ai.occasion,
        sleeveType: ai.sleeveType,
        neckType: ai.neckType,
        highlights: ai.highlights,
        variants: variants.length > 0 ? variants : null,
      },
    });

    // 6. Create inventory
    await Inventory.create({ productId: product.id, shopId, quantity: totalStock });

    res.status(201).json({ success: true, data: { product, aiAnalysis: ai } });
  } catch (err) {
    console.error('AI create-product error:', err.message);
    res.status(500).json({ success: false, message: 'AI product creation failed: ' + err.message });
  }
});

module.exports = router;
// gemini-3.1-flash-lite-preview Wed May  6 14:52:46 UTC 2026
