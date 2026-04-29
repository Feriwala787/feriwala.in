import React, { useEffect, useMemo, useState } from 'react';
import api from '../services/api';
import toast from 'react-hot-toast';
import { useAuth } from '../context/AuthContext';

const initialForm = {
  name: '',
  shortDescription: '',
  description: '',
  brand: '',
  sku: '',
  gender: 'unisex',
  size: [],
  color: [],
  material: '',
  productType: '',
  fit: '',
  pattern: '',
  occasion: '',
  careInstructions: '',
  sleeveType: '',
  neckType: '',
  countryOfOrigin: '',
  manufacturerDetails: '',
  returnPolicy: '',
  deliveryTimeline: '',
  shippingWeight: '',
  packageDimensions: '',
  gstRate: '',
  sizeChartUrl: '',
  categoryId: '',
  subcategoryId: '',
  mrp: '',
  sellingPrice: '',
  quantity: '0',
  tags: [],
  highlights: [],
  isFeatured: false,
  specificationsText: '',
  videoUrl: '',
};

const PRODUCT_OPTIONS = {
  sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '28', '30', '32', '34', '36', '38', '40', '42', 'Free Size'],
  colors: ['Black', 'White', 'Navy', 'Blue', 'Sky Blue', 'Grey', 'Charcoal', 'Red', 'Maroon', 'Burgundy', 'Pink', 'Peach', 'Orange', 'Yellow', 'Green', 'Olive', 'Mint', 'Brown', 'Beige', 'Cream', 'Purple', 'Lavender', 'Multi-color'],
  materials: ['Cotton', '100% Cotton', 'Denim', 'Linen', 'Polyester', 'Nylon', 'Wool', 'Rayon', 'Viscose', 'Silk', 'Satin', 'Velvet', 'Spandex', 'Fleece', 'Leather', 'Synthetic'],
  productTypes: ['T-Shirt', 'Shirt', 'Polo Shirt', 'Kurta', 'Kurti', 'Jeans', 'Trousers', 'Chinos', 'Shorts', 'Track Pants', 'Joggers', 'Dress', 'Skirt', 'Leggings', 'Saree', 'Salwar Suit', 'Jacket', 'Hoodie', 'Sweatshirt', 'Blazer', 'Coat', 'Innerwear', 'Sleepwear', 'Swimwear'],
  fits: ['Regular Fit', 'Slim Fit', 'Relaxed Fit', 'Oversized', 'Skinny Fit', 'Straight Fit', 'Tapered Fit'],
  patterns: ['Solid', 'Striped', 'Checked', 'Printed', 'Floral', 'Geometric', 'Abstract', 'Camouflage', 'Tie-Dye', 'Embroidered'],
  occasions: ['Casual', 'Formal', 'Party', 'Sports', 'Festive', 'Beach', 'Lounge', 'Workwear', 'Wedding'],
  sleeveTypes: ['Half Sleeve', 'Full Sleeve', 'Sleeveless', '3/4 Sleeve', 'Cap Sleeve', 'Raglan'],
  neckTypes: ['Round Neck', 'V Neck', 'Collar', 'Polo Collar', 'Mandarin', 'Hooded', 'Boat Neck', 'Square Neck'],
  careInstructions: ['Machine wash', 'Hand wash', 'Dry clean only', 'Do not bleach', 'Cold wash only'],
  returnPolicies: ['No returns', '3 day return', '7 day return', '10 day return', 'Exchange only'],
  deliveryTimelines: ['Same day', '1-2 business days', '2-4 business days', '4-7 business days'],
  gstRates: ['0', '5', '12', '18', '28'],
  tags: ['new arrival', 'bestseller', 'trending', 'sale', 'limited edition', 'summer collection', 'winter collection', 'festive collection', 'casual wear', 'party wear', 'formal wear', 'sportswear', 'ethnic', 'mens', 'womens', 'kids collection', 'gym wear'],
  highlights: ['Free delivery', 'Cash on delivery', 'Premium quality', 'Easy returns', 'Breathable fabric', 'Stretchable', 'Lightweight', 'Wrinkle resistant', 'Travel friendly'],
};

const toArray = (value) => {
  if (Array.isArray(value)) return value.filter(Boolean);
  return String(value || '').split(',').map((item) => item.trim()).filter(Boolean);
};

const toggleChoice = (values, item) => (
  values.includes(item) ? values.filter((value) => value !== item) : [...values, item]
);

const parseSpecifications = (value) => {
  return String(value || '')
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .reduce((acc, line) => {
      const [key, ...rest] = line.split(':');
      if (!key || rest.length === 0) return acc;
      acc[key.trim()] = rest.join(':').trim();
      return acc;
    }, {});
};

const formatCurrency = (value) => `₹${Number(value || 0).toLocaleString()}`;

export default function ShopProducts() {
  const { user } = useAuth();
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState(initialForm);
  const [editingId, setEditingId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [images, setImages] = useState([]);
  const [video, setVideo] = useState(null);
  const [imageQualityIssues, setImageQualityIssues] = useState([]);
  const [variantStock, setVariantStock] = useState({});
  const [previewOpen, setPreviewOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [sortBy, setSortBy] = useState('updated_desc');

  useEffect(() => {
    fetchCategories();
  }, []);

  useEffect(() => {
    fetchProducts();
  }, [user?.shopId]);

  const selectedCategory = useMemo(
    () => categories.find((cat) => String(cat.id) === String(form.categoryId)),
    [categories, form.categoryId],
  );

  const subcategories = selectedCategory?.subcategories || [];
  const seoTitleSuggestion = [form.brand, form.productType || form.name, form.material, form.gender !== 'unisex' ? form.gender : '']
    .filter(Boolean)
    .join(' | ');
  const shortDescriptionTemplate = `Material: ${form.material || 'N/A'} | Fit: ${form.fit || 'N/A'} | Use: ${form.occasion || 'N/A'}`;

  const fetchCategories = async () => {
    try {
      const res = await api.get('/products/categories/all');
      setCategories(res.data.data || []);
    } catch (err) {
      toast.error('Failed to load categories');
    }
  };

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const params = { limit: 100 };
      if (user?.shopId) params.shopId = user.shopId;
      const res = await api.get('/products', { params });
      setProducts(res.data.data || []);
    } catch (err) {
      toast.error('Failed to load products');
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setForm(initialForm);
    setEditingId(null);
    setImages([]);
    setVideo(null);
    setImageQualityIssues([]);
    setVariantStock({});
  };

  const startEdit = (product) => {
    setEditingId(product.id);
    setForm({
      name: product.name || '',
      shortDescription: product.shortDescription || '',
      description: product.description || '',
      brand: product.brand || '',
      sku: product.sku || '',
      gender: product.gender || 'unisex',
      size: toArray(product.size),
      color: toArray(product.color),
      material: product.material || '',
      productType: product.attributes?.productType || '',
      fit: product.attributes?.fit || '',
      pattern: product.attributes?.pattern || '',
      occasion: product.attributes?.occasion || '',
      careInstructions: product.attributes?.careInstructions || '',
      sleeveType: product.attributes?.sleeveType || '',
      neckType: product.attributes?.neckType || '',
      countryOfOrigin: product.attributes?.countryOfOrigin || '',
      manufacturerDetails: product.attributes?.manufacturerDetails || '',
      returnPolicy: product.attributes?.returnPolicy || '',
      deliveryTimeline: product.attributes?.deliveryTimeline || '',
      shippingWeight: product.attributes?.shippingWeight || '',
      packageDimensions: product.attributes?.packageDimensions || '',
      gstRate: product.attributes?.gstRate || '',
      sizeChartUrl: product.attributes?.sizeChartUrl || '',
      categoryId: product.categoryId ? String(product.categoryId) : '',
      subcategoryId: product.subcategoryId ? String(product.subcategoryId) : '',
      mrp: product.mrp || '',
      sellingPrice: product.sellingPrice || '',
      quantity: product.inventory?.quantity ?? '0',
      tags: toArray(product.tags),
      highlights: toArray(product.highlights),
      isFeatured: Boolean(product.isFeatured),
      specificationsText: product.specifications
        ? Object.entries(product.specifications).map(([key, value]) => `${key}: ${value}`).join('\n')
        : '',
      videoUrl: product.videoUrl || '',
    });
    const productVariantStock = product.attributes?.variantStock || {};
    setVariantStock(productVariantStock && typeof productVariantStock === 'object' ? productVariantStock : {});
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleChange = (event) => {
    const { name, value, type, checked } = event.target;
    setForm((prev) => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
      ...(name === 'categoryId' ? { subcategoryId: '' } : {}),
    }));
  };

  const handleImageChange = async (event) => {
    const selected = Array.from(event.target.files || []);
    setImages(selected);
    const checks = await Promise.all(selected.map((file) => new Promise((resolve) => {
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.onload = () => {
        const ratio = img.width / img.height;
        const ratioOk = ratio >= 0.8 && ratio <= 1.91;
        resolve({
          name: file.name,
          width: img.width,
          height: img.height,
          minResolutionOk: img.width >= 800 && img.height >= 800,
          ratioOk,
        });
        URL.revokeObjectURL(url);
      };
      img.onerror = () => {
        resolve({ name: file.name, width: 0, height: 0, minResolutionOk: false, ratioOk: false });
        URL.revokeObjectURL(url);
      };
      img.src = url;
    })));
    const issues = checks.filter((item) => !item.minResolutionOk || !item.ratioOk);
    setImageQualityIssues(issues);
  };

  const setVariantQty = (size, color, qty) => {
    const key = `${size}__${color}`;
    setVariantStock((prev) => ({ ...prev, [key]: Math.max(0, Number(qty || 0)) }));
  };

  const totalVariantQty = useMemo(
    () => Object.values(variantStock).reduce((sum, qty) => sum + Number(qty || 0), 0),
    [variantStock],
  );

  const duplicateMatches = useMemo(() => {
    const name = form.name.trim().toLowerCase();
    const sku = form.sku.trim().toLowerCase();
    return products.filter((product) => {
      if (editingId && product.id === editingId) return false;
      const productName = String(product.name || '').toLowerCase();
      const productSku = String(product.sku || '').toLowerCase();
      return (name && productName.includes(name)) || (sku && productSku && productSku === sku);
    }).slice(0, 3);
  }, [products, form.name, form.sku, editingId]);

  const completeness = useMemo(() => {
    const checks = [
      { label: 'Product name', ok: Boolean(form.name.trim()) },
      { label: 'Short description template', ok: /Material:.*\| Fit:.*\| Use:/.test(form.shortDescription) },
      { label: 'Category', ok: Boolean(form.categoryId) },
      { label: 'MRP & Selling Price', ok: Boolean(form.mrp && form.sellingPrice) && Number(form.sellingPrice) <= Number(form.mrp) },
      { label: 'Sizes selected', ok: form.size.length > 0 },
      { label: 'Colors selected', ok: form.color.length > 0 },
      { label: 'At least one image', ok: editingId ? true : images.length > 0 },
      { label: 'Variant stock matrix', ok: totalVariantQty > 0 },
    ];
    const score = Math.round((checks.filter((item) => item.ok).length / checks.length) * 100);
    return { score, checks };
  }, [form, images.length, editingId, totalVariantQty]);

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (duplicateMatches.length > 0) {
      toast.error('Possible duplicate listing found. Please review existing products first.');
      return;
    }
    if (!form.categoryId) {
      toast.error('Please choose a category');
      return;
    }
    if (!/Material:.*\| Fit:.*\| Use:/.test(form.shortDescription)) {
      toast.error('Use the short description template: Material | Fit | Use');
      return;
    }
    if (Number(form.sellingPrice) > Number(form.mrp)) {
      toast.error('Selling price cannot be higher than MRP');
      return;
    }
    if (form.size.length === 0) {
      toast.error('Please select at least one size');
      return;
    }
    if (form.color.length === 0) {
      toast.error('Please select at least one color');
      return;
    }
    if (!editingId && images.length === 0) {
      toast.error('Please add at least one product image');
      return;
    }
    if (imageQualityIssues.length > 0) {
      toast.error('Some images do not meet recommended quality (min 800x800 and valid ratio).');
      return;
    }
    if (totalVariantQty <= 0) {
      toast.error('Please fill variant stock matrix (size × color) with at least one quantity.');
      return;
    }

    setSaving(true);

    try {
      const payload = {
        name: form.name,
        shortDescription: form.shortDescription,
        description: form.description,
        brand: form.brand,
        sku: form.sku || undefined,
        gender: form.gender || 'unisex',
        size: form.size.length ? form.size.join(', ') : undefined,
        color: form.color.length ? form.color.join(', ') : undefined,
        material: form.material || undefined,
        categoryId: Number(form.categoryId),
        subcategoryId: form.subcategoryId ? Number(form.subcategoryId) : undefined,
        mrp: Number(form.mrp),
        sellingPrice: Number(form.sellingPrice),
        quantity: totalVariantQty || Number(form.quantity || 0),
        tags: form.tags,
        highlights: form.highlights,
        isFeatured: form.isFeatured,
        attributes: {
          ...parseSpecifications(form.specificationsText),
          seoTitle: seoTitleSuggestion || undefined,
          variantStock,
          productType: form.productType || undefined,
          fit: form.fit || undefined,
          pattern: form.pattern || undefined,
          occasion: form.occasion || undefined,
          careInstructions: form.careInstructions || undefined,
          sleeveType: form.sleeveType || undefined,
          neckType: form.neckType || undefined,
          countryOfOrigin: form.countryOfOrigin || undefined,
          manufacturerDetails: form.manufacturerDetails || undefined,
          returnPolicy: form.returnPolicy || undefined,
          deliveryTimeline: form.deliveryTimeline || undefined,
          shippingWeight: form.shippingWeight || undefined,
          packageDimensions: form.packageDimensions || undefined,
          gstRate: form.gstRate || undefined,
          sizeChartUrl: form.sizeChartUrl || undefined,
        },
        videoUrl: form.videoUrl || undefined,
      };

      let productId = editingId;

      if (editingId) {
        await api.put(`/products/${editingId}`, payload);
        await api.put(`/products/${editingId}/inventory`, { quantity: totalVariantQty || Number(form.quantity || 0) });
      } else {
        const res = await api.post('/products', payload);
        productId = res.data.data.id;
      }

      if (productId && (images.length > 0 || video)) {
        const mediaData = new FormData();
        images.forEach((file) => mediaData.append('images', file));
        if (video) mediaData.append('video', video);
        await api.post(`/products/${productId}/media`, mediaData, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }

      toast.success(editingId ? 'Product updated' : 'Product created');
      resetForm();
      fetchProducts();
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to save product');
    } finally {
      setSaving(false);
    }
  };

  const toggleStatus = async (product) => {
    try {
      await api.put(`/products/${product.id}`, { isActive: !product.isActive });
      toast.success(product.isActive ? 'Product hidden' : 'Product activated');
      fetchProducts();
    } catch (err) {
      toast.error('Failed to update status');
    }
  };

  const productCount = products.length;
  const activeCount = products.filter((product) => product.isActive).length;
  const lowStockCount = products.filter((product) => Number(product.inventory?.quantity ?? 0) <= 5).length;
  const discountPercent = form.mrp && form.sellingPrice
    ? Math.max(0, Math.round(((Number(form.mrp) - Number(form.sellingPrice)) / Number(form.mrp || 1)) * 100))
    : 0;
  const variantRows = form.size.flatMap((size) => form.color.map((color) => ({ size, color, key: `${size}__${color}` })));

  const renderSingleSelect = (label, name, options) => (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
      <select name={name} value={form[name]} onChange={handleChange} className="w-full px-3 py-2 border rounded-lg">
        <option value="">Select</option>
        {options.map((option) => (
          <option key={option} value={option}>{option}</option>
        ))}
      </select>
    </div>
  );

  const renderMultiChoice = (label, name, options) => (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-2">{label}</label>
      <div className="flex flex-wrap gap-2">
        {options.map((option) => {
          const selected = form[name].includes(option);
          return (
            <button
              key={option}
              type="button"
              onClick={() => setForm((prev) => ({ ...prev, [name]: toggleChoice(prev[name], option) }))}
              className={`px-3 py-1.5 rounded-full text-sm border ${selected ? 'bg-primary-600 border-primary-600 text-white' : 'bg-white border-gray-300 text-gray-700'}`}
            >
              {option}
            </button>
          );
        })}
      </div>
    </div>
  );

  const filteredProducts = useMemo(() => {
    let list = [...products];

    if (searchTerm.trim()) {
      const query = searchTerm.trim().toLowerCase();
      list = list.filter((product) =>
        [product.name, product.shortDescription, product.description, product.brand]
          .filter(Boolean)
          .some((field) => String(field).toLowerCase().includes(query)),
      );
    }

    if (statusFilter === 'active') list = list.filter((product) => product.isActive);
    if (statusFilter === 'hidden') list = list.filter((product) => !product.isActive);
    if (statusFilter === 'low_stock') list = list.filter((product) => Number(product.inventory?.quantity ?? 0) <= 5);

    if (categoryFilter !== 'all') {
      list = list.filter((product) => String(product.categoryId) === categoryFilter);
    }

    if (sortBy === 'price_asc') list.sort((a, b) => Number(a.sellingPrice || 0) - Number(b.sellingPrice || 0));
    if (sortBy === 'price_desc') list.sort((a, b) => Number(b.sellingPrice || 0) - Number(a.sellingPrice || 0));
    if (sortBy === 'stock_asc') list.sort((a, b) => Number(a.inventory?.quantity ?? 0) - Number(b.inventory?.quantity ?? 0));
    if (sortBy === 'stock_desc') list.sort((a, b) => Number(b.inventory?.quantity ?? 0) - Number(a.inventory?.quantity ?? 0));
    if (sortBy === 'name_asc') list.sort((a, b) => String(a.name || '').localeCompare(String(b.name || '')));
    if (sortBy === 'updated_desc') list.sort((a, b) => new Date(b.updatedAt || b.createdAt || 0) - new Date(a.updatedAt || a.createdAt || 0));

    return list;
  }, [products, searchTerm, statusFilter, categoryFilter, sortBy]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-800">Product Listing Portal</h2>
        <p className="text-sm text-gray-500 mt-1">
          Shop admins can list new products only here in the web portal. Mobile app supports viewing/managing listed products.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">Total products</p>
          <p className="text-2xl font-bold text-gray-800 mt-1">{productCount}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">Active listings</p>
          <p className="text-2xl font-bold text-gray-800 mt-1">{activeCount}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">Assigned shop</p>
          <p className="text-lg font-semibold text-gray-800 mt-1">{user?.shopId || 'Admin view'}</p>
        </div>
        <div className="bg-white rounded-xl shadow-sm p-4 border border-gray-100">
          <p className="text-sm text-gray-500">Low stock (≤ 5)</p>
          <p className="text-2xl font-bold text-amber-600 mt-1">{lowStockCount}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-5 gap-6">
        <div className="xl:col-span-2 bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between mb-4 gap-3">
            <h3 className="text-lg font-semibold text-gray-800">{editingId ? 'Edit product' : 'Create product'}</h3>
            {editingId && (
              <button onClick={resetForm} className="text-sm text-gray-500 hover:text-gray-800">
                Clear form
              </button>
            )}
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
              <div className="flex items-center justify-between">
                <p className="text-sm font-medium text-gray-800">Listing completeness</p>
                <p className="text-sm font-semibold text-primary-700">{completeness.score}%</p>
              </div>
              <div className="mt-2 grid grid-cols-1 md:grid-cols-2 gap-1 text-xs">
                {completeness.checks.map((item) => (
                  <p key={item.label} className={item.ok ? 'text-emerald-700' : 'text-amber-700'}>
                    {item.ok ? '✓' : '•'} {item.label}
                  </p>
                ))}
              </div>
            </div>

            {duplicateMatches.length > 0 && (
              <div className="rounded-lg border border-amber-300 bg-amber-50 p-3 text-xs text-amber-800">
                <p className="font-semibold mb-1">Potential duplicate found:</p>
                <ul className="list-disc ml-4 space-y-1">
                  {duplicateMatches.map((item) => (
                    <li key={item.id}>{item.name} {item.sku ? `(${item.sku})` : ''}</li>
                  ))}
                </ul>
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Product name</label>
              <input name="name" value={form.name} onChange={handleChange} required className="w-full px-3 py-2 border rounded-lg" />
            </div>

            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="block text-sm font-medium text-gray-700">Short description (template required)</label>
                <button
                  type="button"
                  onClick={() => setForm((prev) => ({ ...prev, shortDescription: shortDescriptionTemplate }))}
                  className="text-xs text-primary-700 hover:underline"
                >
                  Use template
                </button>
              </div>
              <textarea name="shortDescription" value={form.shortDescription} onChange={handleChange} rows="2" className="w-full px-3 py-2 border rounded-lg" />
              <p className="text-xs text-gray-500 mt-1">Format: {shortDescriptionTemplate}</p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Full description</label>
              <textarea name="description" value={form.description} onChange={handleChange} rows="4" className="w-full px-3 py-2 border rounded-lg" />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Brand</label>
                <input name="brand" value={form.brand} onChange={handleChange} className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">SKU / Article code</label>
                <input name="sku" value={form.sku} onChange={handleChange} className="w-full px-3 py-2 border rounded-lg" />
                <p className="text-xs text-gray-500 mt-1">SEO title suggestion: {seoTitleSuggestion || 'Will appear as you fill fields'}</p>
              </div>
              {renderSingleSelect('Product type', 'productType', PRODUCT_OPTIONS.productTypes)}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Stock quantity</label>
                <input name="quantity" type="number" min="0" value={form.quantity} onChange={handleChange} className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Target group</label>
                <select name="gender" value={form.gender} onChange={handleChange} className="w-full px-3 py-2 border rounded-lg">
                  <option value="men">Men</option>
                  <option value="women">Women</option>
                  <option value="unisex">Unisex</option>
                  <option value="kids">Kids</option>
                  <option value="boys">Boys</option>
                  <option value="girls">Girls</option>
                </select>
              </div>
              {renderSingleSelect('Material / Fabric', 'material', PRODUCT_OPTIONS.materials)}
              {renderSingleSelect('Fit', 'fit', PRODUCT_OPTIONS.fits)}
              {renderSingleSelect('Pattern', 'pattern', PRODUCT_OPTIONS.patterns)}
              {renderSingleSelect('Occasion', 'occasion', PRODUCT_OPTIONS.occasions)}
              {renderSingleSelect('Care instructions', 'careInstructions', PRODUCT_OPTIONS.careInstructions)}
              {renderSingleSelect('Sleeve type (apparel)', 'sleeveType', PRODUCT_OPTIONS.sleeveTypes)}
              {renderSingleSelect('Neck type (apparel)', 'neckType', PRODUCT_OPTIONS.neckTypes)}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Country of origin</label>
                <input name="countryOfOrigin" value={form.countryOfOrigin} onChange={handleChange} placeholder="India" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Manufacturer / Packer</label>
                <input name="manufacturerDetails" value={form.manufacturerDetails} onChange={handleChange} placeholder="Company name & address" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              {renderSingleSelect('Return / exchange policy', 'returnPolicy', PRODUCT_OPTIONS.returnPolicies)}
              {renderSingleSelect('Delivery timeline', 'deliveryTimeline', PRODUCT_OPTIONS.deliveryTimelines)}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Shipping weight</label>
                <input name="shippingWeight" value={form.shippingWeight} onChange={handleChange} placeholder="350 g" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Package dimensions</label>
                <input name="packageDimensions" value={form.packageDimensions} onChange={handleChange} placeholder="30 x 20 x 3 cm" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              {renderSingleSelect('GST / Tax rate (%)', 'gstRate', PRODUCT_OPTIONS.gstRates)}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Size chart URL</label>
                <input name="sizeChartUrl" value={form.sizeChartUrl} onChange={handleChange} placeholder="https://..." className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
                <select name="categoryId" value={form.categoryId} onChange={handleChange} required className="w-full px-3 py-2 border rounded-lg">
                  <option value="">Select category</option>
                  {categories.map((category) => (
                    <option key={category.id} value={category.id}>{category.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Subcategory</label>
                <select name="subcategoryId" value={form.subcategoryId} onChange={handleChange} className="w-full px-3 py-2 border rounded-lg">
                  <option value="">Optional</option>
                  {subcategories.map((subcategory) => (
                    <option key={subcategory.id} value={subcategory.id}>{subcategory.name}</option>
                  ))}
                </select>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">MRP</label>
                <input name="mrp" type="number" min="0" step="0.01" value={form.mrp} onChange={handleChange} required className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Selling price</label>
                <input name="sellingPrice" type="number" min="0" step="0.01" value={form.sellingPrice} onChange={handleChange} required className="w-full px-3 py-2 border rounded-lg" />
              </div>
            </div>
            {form.mrp && form.sellingPrice && (
              <p className="text-xs text-emerald-700">
                Customer offer: {discountPercent}% off
              </p>
            )}

            {renderMultiChoice('Available sizes', 'size', PRODUCT_OPTIONS.sizes)}
            {renderMultiChoice('Available colors', 'color', PRODUCT_OPTIONS.colors)}
            {renderMultiChoice('Tags', 'tags', PRODUCT_OPTIONS.tags)}
            {renderMultiChoice('Highlights', 'highlights', PRODUCT_OPTIONS.highlights)}

            <div className="rounded-lg border border-gray-200 p-3">
              <div className="flex items-center justify-between">
                <p className="text-sm font-medium text-gray-800">Variant stock matrix (Size × Color)</p>
                <p className="text-xs text-gray-600">Total variant qty: {totalVariantQty}</p>
              </div>
              {variantRows.length === 0 ? (
                <p className="text-xs text-gray-500 mt-2">Select at least one size and one color to enter variant-level stock.</p>
              ) : (
                <div className="mt-2 max-h-48 overflow-auto space-y-2">
                  {variantRows.map((row) => (
                    <div key={row.key} className="grid grid-cols-3 gap-2 items-center text-xs">
                      <span className="px-2 py-1 bg-gray-100 rounded">{row.size}</span>
                      <span className="px-2 py-1 bg-gray-100 rounded">{row.color}</span>
                      <input
                        type="number"
                        min="0"
                        value={variantStock[row.key] ?? 0}
                        onChange={(e) => setVariantQty(row.size, row.color, e.target.value)}
                        className="w-full px-2 py-1 border rounded"
                      />
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Specifications</label>
              <textarea name="specificationsText" value={form.specificationsText} onChange={handleChange} rows="3" placeholder="Weight: 1kg&#10;Origin: Dhaka" className="w-full px-3 py-2 border rounded-lg" />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Video URL</label>
              <input name="videoUrl" value={form.videoUrl} onChange={handleChange} placeholder="https://..." className="w-full px-3 py-2 border rounded-lg" />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Images</label>
              <input type="file" accept="image/*" multiple onChange={handleImageChange} className="w-full text-sm" />
              <p className="text-xs text-gray-500 mt-1">Recommended: min 800×800 px, aspect ratio between 4:5 and 1.91:1.</p>
              {imageQualityIssues.length > 0 && (
                <div className="mt-2 rounded border border-amber-300 bg-amber-50 p-2 text-xs text-amber-800">
                  {imageQualityIssues.map((item) => (
                    <p key={item.name}>
                      {item.name}: {item.width}×{item.height} {!item.minResolutionOk ? '(low resolution)' : ''} {!item.ratioOk ? '(bad ratio)' : ''}
                    </p>
                  ))}
                </div>
              )}
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Promo video</label>
              <input type="file" accept="video/*" onChange={(e) => setVideo(e.target.files?.[0] || null)} className="w-full text-sm" />
            </div>

            <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm font-medium text-gray-800">Customer listing preview</p>
                <button type="button" onClick={() => setPreviewOpen(true)} className="text-xs text-primary-700 hover:underline">Preview as customer</button>
              </div>
              <div className="space-y-1 text-xs text-gray-600">
                <p><span className="font-medium">Name:</span> {form.name || '—'}</p>
                <p><span className="font-medium">Price:</span> {form.sellingPrice ? formatCurrency(form.sellingPrice) : '—'}</p>
                <p><span className="font-medium">Sizes:</span> {form.size.length ? form.size.join(', ') : 'Not selected'}</p>
                <p><span className="font-medium">Colors:</span> {form.color.length ? form.color.join(', ') : 'Not selected'}</p>
                <p><span className="font-medium">Highlights:</span> {form.highlights.length ? form.highlights.join(', ') : 'Not selected'}</p>
              </div>
            </div>

            <label className="flex items-center gap-2 text-sm text-gray-700">
              <input
                type="checkbox"
                name="isFeatured"
                checked={form.isFeatured}
                onChange={handleChange}
              />
              Feature this product more prominently for customers
            </label>

            <button type="submit" disabled={saving} className="w-full py-3 bg-primary-600 text-white rounded-lg font-medium hover:bg-primary-700 disabled:opacity-50">
              {saving ? 'Saving...' : editingId ? 'Update product' : 'Create product'}
            </button>
          </form>
        </div>

        <div className="xl:col-span-3 bg-white rounded-xl shadow-sm p-6 border border-gray-100">
          <div className="flex items-center justify-between mb-4 gap-3">
            <h3 className="text-lg font-semibold text-gray-800">Current listings</h3>
            <button onClick={fetchProducts} className="text-sm text-primary-600 hover:underline">
              Refresh
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-4 gap-3 mb-4">
            <input
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by name, brand, description..."
              className="md:col-span-2 px-3 py-2 border rounded-lg"
            />
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="px-3 py-2 border rounded-lg">
              <option value="all">All status</option>
              <option value="active">Active only</option>
              <option value="hidden">Hidden only</option>
              <option value="low_stock">Low stock only</option>
            </select>
            <select value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)} className="px-3 py-2 border rounded-lg">
              <option value="all">All categories</option>
              {categories.map((category) => (
                <option key={category.id} value={String(category.id)}>{category.name}</option>
              ))}
            </select>
            <select value={sortBy} onChange={(e) => setSortBy(e.target.value)} className="px-3 py-2 border rounded-lg">
              <option value="updated_desc">Latest updated</option>
              <option value="name_asc">Name (A-Z)</option>
              <option value="price_asc">Price (low-high)</option>
              <option value="price_desc">Price (high-low)</option>
              <option value="stock_asc">Stock (low-high)</option>
              <option value="stock_desc">Stock (high-low)</option>
            </select>
            <p className="text-xs text-gray-500 md:col-span-4">
              Showing {filteredProducts.length} of {products.length} products.
            </p>
          </div>

          {loading ? (
            <p className="text-gray-500">Loading products...</p>
          ) : filteredProducts.length === 0 ? (
            <p className="text-gray-500">No products listed yet.</p>
          ) : (
            <div className="space-y-4">
              {filteredProducts.map((product) => (
                <div key={product.id} className="border border-gray-200 rounded-xl p-4">
                  <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                    <div className="flex gap-4 min-w-0">
                      <img
                        src={product.images?.[0] || 'https://placehold.co/96x96?text=Item'}
                        alt={product.name}
                        className="w-24 h-24 rounded-lg object-cover border"
                      />
                      <div className="min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <h4 className="font-semibold text-gray-800">{product.name}</h4>
                          <span className={`px-2 py-1 text-xs rounded-full ${product.isActive ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-700'}`}>
                            {product.isActive ? 'Active' : 'Hidden'}
                          </span>
                        </div>
                        <p className="text-sm text-gray-500 mt-1">{product.shortDescription || product.description || 'No description added yet.'}</p>
                        <div className="flex flex-wrap gap-2 mt-2 text-xs text-gray-600">
                          <span className="bg-gray-100 rounded px-2 py-1">{product.category?.name || 'Uncategorized'}</span>
                          {product.subcategory?.name && <span className="bg-gray-100 rounded px-2 py-1">{product.subcategory.name}</span>}
                          <span className="bg-gray-100 rounded px-2 py-1">Stock: {product.inventory?.quantity ?? 0}</span>
                          {product.attributes?.productType && <span className="bg-gray-100 rounded px-2 py-1">Type: {product.attributes.productType}</span>}
                          {product.size && <span className="bg-gray-100 rounded px-2 py-1">Size: {product.size}</span>}
                          {product.color && <span className="bg-gray-100 rounded px-2 py-1">Color: {product.color}</span>}
                          {product.material && <span className="bg-gray-100 rounded px-2 py-1">Fabric: {product.material}</span>}
                        </div>
                      </div>
                    </div>

                    <div className="text-left md:text-right">
                      <p className="text-lg font-bold text-gray-800">{formatCurrency(product.sellingPrice)}</p>
                      <p className="text-sm text-gray-500 line-through">{formatCurrency(product.mrp)}</p>
                      <div className="mt-3 flex flex-wrap gap-2 md:justify-end">
                        <button onClick={() => startEdit(product)} className="px-3 py-1.5 bg-blue-50 text-blue-700 rounded-lg text-sm">
                          Edit
                        </button>
                        <button onClick={() => toggleStatus(product)} className="px-3 py-1.5 bg-gray-100 text-gray-700 rounded-lg text-sm">
                          {product.isActive ? 'Hide' : 'Activate'}
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {previewOpen && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md p-4">
            <div className="flex items-center justify-between mb-3">
              <h4 className="font-semibold text-gray-800">Customer app preview</h4>
              <button type="button" className="text-sm text-gray-500" onClick={() => setPreviewOpen(false)}>Close</button>
            </div>
            <img src="https://placehold.co/600x600?text=Product+Image" alt="Preview" className="w-full h-52 object-cover rounded-lg border" />
            <h5 className="mt-3 font-semibold">{seoTitleSuggestion || form.name || 'Product title'}</h5>
            <p className="text-sm text-gray-500 mt-1">{form.shortDescription || 'Short description will appear here.'}</p>
            <div className="mt-2 flex items-center gap-2">
              <span className="text-lg font-bold text-gray-800">{form.sellingPrice ? formatCurrency(form.sellingPrice) : '₹0'}</span>
              {form.mrp && <span className="text-sm line-through text-gray-500">{formatCurrency(form.mrp)}</span>}
              {discountPercent > 0 && <span className="text-xs bg-emerald-100 text-emerald-700 px-2 py-1 rounded">{discountPercent}% OFF</span>}
            </div>
            <p className="text-xs text-gray-600 mt-2">Sizes: {form.size.length ? form.size.join(', ') : '—'}</p>
            <p className="text-xs text-gray-600">Colors: {form.color.length ? form.color.join(', ') : '—'}</p>
          </div>
        </div>
      )}
    </div>
  );
}
