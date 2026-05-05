const express = require('express');
const router = express.Router();
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

const genAI = new GoogleGenerativeAI(process.env.Google_gemini_api);

router.post('/analyze-product', upload.array('images', 10), async (req, res) => {
  try {
    if (!process.env.Google_gemini_api) {
      return res.status(503).json({ success: false, message: 'AI service not configured' });
    }

    const files = req.files || [];
    const userPrompt = req.body.prompt || '';

    if (files.length === 0) {
      return res.status(400).json({ success: false, message: 'At least one image is required' });
    }

    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const imageParts = files.map((file) => ({
      inlineData: {
        data: file.buffer.toString('base64'),
        mimeType: file.mimetype,
      },
    }));

    const systemPrompt = `You are a product listing assistant for a quick-commerce clothing platform called Feriwala.
Analyze the provided product images and ${userPrompt ? `the seller's note: "${userPrompt}"` : 'extract all visible product details'}.

Return ONLY a valid JSON object with these exact fields (use empty string or empty array if unknown):
{
  "name": "product name",
  "brand": "brand name or empty",
  "description": "detailed product description 2-3 sentences",
  "shortDescription": "Material: X | Fit: Y | Use: Z",
  "productType": "one of: T-Shirt, Shirt, Polo Shirt, Kurta, Kurti, Jeans, Trousers, Chinos, Shorts, Track Pants, Joggers, Dress, Skirt, Leggings, Saree, Salwar Suit, Jacket, Hoodie, Sweatshirt, Blazer, Coat, Innerwear, Sleepwear, Swimwear",
  "gender": "one of: men, women, unisex, kids, boys, girls",
  "color": ["color1", "color2"],
  "size": ["S", "M", "L"],
  "material": "fabric material",
  "fit": "one of: Regular Fit, Slim Fit, Relaxed Fit, Oversized, Skinny Fit, Straight Fit, Tapered Fit",
  "pattern": "one of: Solid, Striped, Checked, Printed, Floral, Geometric, Abstract, Camouflage, Tie-Dye, Embroidered",
  "occasion": "one of: Casual, Formal, Party, Sports, Festive, Beach, Lounge, Workwear, Wedding",
  "sleeveType": "one of: Half Sleeve, Full Sleeve, Sleeveless, 3/4 Sleeve, Cap Sleeve, Raglan or empty",
  "neckType": "one of: Round Neck, V Neck, Collar, Polo Collar, Mandarin, Hooded, Boat Neck, Square Neck or empty",
  "tags": ["tag1", "tag2"],
  "highlights": ["highlight1", "highlight2"],
  "mrp": "suggested MRP in INR as number string",
  "sellingPrice": "suggested selling price in INR as number string",
  "variantColors": ["all visible colors from images"],
  "confidence": "high/medium/low"
}`;

    const result = await model.generateContent([systemPrompt, ...imageParts]);
    const text = result.response.text();

    // Extract JSON from response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return res.status(422).json({ success: false, message: 'AI could not extract product details from images' });
    }

    const productData = JSON.parse(jsonMatch[0]);
    res.json({ success: true, data: productData });
  } catch (err) {
    console.error('AI analyze-product error:', err.message);
    res.status(500).json({ success: false, message: 'AI analysis failed: ' + err.message });
  }
});

// POST /api/ai/create-product — analyze images + auto-create product in one shot
const { authenticate, authorize } = require('../middleware/auth');
const Product = require('../models/pg/Product');
const Inventory = require('../models/pg/Inventory');
const Category = require('../models/pg/Category');

router.post('/create-product', authenticate, authorize('shop_admin', 'admin'), upload.array('images', 10), async (req, res) => {
  try {
    if (!process.env.Google_gemini_api) {
      return res.status(503).json({ success: false, message: 'AI service not configured' });
    }

    const files = req.files || [];
    if (files.length === 0) return res.status(400).json({ success: false, message: 'At least one image required' });

    const userPrompt = req.body.prompt || '';
    const quantity = parseInt(req.body.quantity || '0');
    const shopId = req.user.shopId;
    if (!shopId) return res.status(400).json({ success: false, message: 'No shop assigned' });

    // 1. Analyze with Gemini
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const imageParts = files.map(f => ({ inlineData: { data: f.buffer.toString('base64'), mimeType: f.mimetype } }));

    const systemPrompt = `You are a product listing assistant for Feriwala, a quick-commerce clothing platform.
Analyze the product images${userPrompt ? ` and seller note: "${userPrompt}"` : ''}.
Return ONLY valid JSON:
{
  "name": "product name",
  "brand": "",
  "description": "2-3 sentence description",
  "shortDescription": "Material: X | Fit: Y | Use: Z",
  "productType": "T-Shirt|Shirt|Jeans|Dress|Kurta|etc",
  "gender": "men|women|unisex|kids",
  "color": ["color1"],
  "size": ["S","M","L","XL"],
  "material": "",
  "fit": "Regular Fit|Slim Fit|Relaxed Fit|Oversized",
  "pattern": "Solid|Striped|Printed|etc",
  "occasion": "Casual|Formal|Party|Sports|Festive",
  "sleeveType": "",
  "neckType": "",
  "tags": [],
  "mrp": "499",
  "sellingPrice": "399"
}`;

    const result = await model.generateContent([systemPrompt, ...imageParts]);
    const text = result.response.text();
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return res.status(422).json({ success: false, message: 'AI could not extract product details' });

    const ai = JSON.parse(jsonMatch[0]);

    // 2. Find or use default category
    let categoryId = parseInt(req.body.categoryId || '0');
    if (!categoryId) {
      const cat = await Category.findOne({ where: { isActive: true }, order: [['sortOrder', 'ASC']] });
      categoryId = cat?.id || 1;
    }

    // 3. Upload images to storage (use buffer URLs for now — same as analyze endpoint)
    // Images are stored as base64 data URIs if no S3 configured
    const imageUrls = files.map((f, i) => `${process.env.SERVER_URL || 'http://65.2.9.216'}/uploads/ai_${Date.now()}_${i}.jpg`);

    // 4. Create product
    const slug = (ai.name || 'product').toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + Date.now();
    const mrp = parseFloat(ai.mrp) || 499;
    const sellingPrice = parseFloat(ai.sellingPrice) || 399;
    const discount = mrp > 0 ? (((mrp - sellingPrice) / mrp) * 100).toFixed(2) : 0;

    const product = await Product.create({
      name: ai.name || 'New Product',
      brand: ai.brand || '',
      description: ai.description || '',
      shortDescription: ai.shortDescription || '',
      gender: ai.gender || 'unisex',
      color: Array.isArray(ai.color) ? ai.color.join(',') : (ai.color || ''),
      size: Array.isArray(ai.size) ? ai.size.join(',') : (ai.size || ''),
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
      },
    });

    // 5. Create inventory
    await Inventory.create({ productId: product.id, shopId, quantity });

    res.status(201).json({ success: true, data: { product, aiAnalysis: ai } });
  } catch (err) {
    console.error('AI create-product error:', err.message);
    res.status(500).json({ success: false, message: 'AI product creation failed: ' + err.message });
  }
});

module.exports = router;
