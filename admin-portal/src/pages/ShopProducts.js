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
  size: '',
  color: '',
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
  tags: '',
  highlights: '',
  specificationsText: '',
  videoUrl: '',
};

const parseList = (value) =>
  String(value || '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);

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
      size: product.size || '',
      color: product.color || '',
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
      tags: Array.isArray(product.tags) ? product.tags.join(', ') : '',
      highlights: Array.isArray(product.highlights) ? product.highlights.join(', ') : '',
      specificationsText: product.specifications
        ? Object.entries(product.specifications).map(([key, value]) => `${key}: ${value}`).join('\n')
        : '',
      videoUrl: product.videoUrl || '',
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleChange = (event) => {
    const { name, value } = event.target;
    setForm((prev) => ({
      ...prev,
      [name]: value,
      ...(name === 'categoryId' ? { subcategoryId: '' } : {}),
    }));
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);

    try {
      const payload = {
        name: form.name,
        shortDescription: form.shortDescription,
        description: form.description,
        brand: form.brand,
        sku: form.sku || undefined,
        gender: form.gender || 'unisex',
        size: form.size || undefined,
        color: form.color || undefined,
        material: form.material || undefined,
        categoryId: Number(form.categoryId),
        subcategoryId: form.subcategoryId ? Number(form.subcategoryId) : undefined,
        mrp: Number(form.mrp),
        sellingPrice: Number(form.sellingPrice),
        quantity: Number(form.quantity || 0),
        tags: parseList(form.tags),
        highlights: parseList(form.highlights),
        attributes: {
          ...parseSpecifications(form.specificationsText),
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
        await api.put(`/products/${editingId}/inventory`, { quantity: Number(form.quantity || 0) });
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
          Shop owners can now manage products here using their existing portal credentials.
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
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Product name</label>
              <input name="name" value={form.name} onChange={handleChange} required className="w-full px-3 py-2 border rounded-lg" />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Short description</label>
              <textarea name="shortDescription" value={form.shortDescription} onChange={handleChange} rows="2" className="w-full px-3 py-2 border rounded-lg" />
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
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Product type</label>
                <input name="productType" value={form.productType} onChange={handleChange} placeholder="Sneaker, Kurta, Hoodie..." className="w-full px-3 py-2 border rounded-lg" />
              </div>
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
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Size</label>
                <input name="size" value={form.size} onChange={handleChange} placeholder="S, M, L, XL / 42 / 8UK" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Color</label>
                <input name="color" value={form.color} onChange={handleChange} placeholder="Black, Navy Blue..." className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Material / Fabric</label>
                <input name="material" value={form.material} onChange={handleChange} placeholder="Cotton, Denim, PU..." className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Fit</label>
                <input name="fit" value={form.fit} onChange={handleChange} placeholder="Slim fit, Regular fit" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Pattern</label>
                <input name="pattern" value={form.pattern} onChange={handleChange} placeholder="Solid, Printed, Striped" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Occasion</label>
                <input name="occasion" value={form.occasion} onChange={handleChange} placeholder="Casual, Party, Sports" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Care instructions</label>
                <input name="careInstructions" value={form.careInstructions} onChange={handleChange} placeholder="Machine wash, Hand wash" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Sleeve type (apparel)</label>
                <input name="sleeveType" value={form.sleeveType} onChange={handleChange} placeholder="Half sleeve, Full sleeve" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Neck type (apparel)</label>
                <input name="neckType" value={form.neckType} onChange={handleChange} placeholder="Round neck, Polo, V-neck" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Country of origin</label>
                <input name="countryOfOrigin" value={form.countryOfOrigin} onChange={handleChange} placeholder="India" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Manufacturer / Packer</label>
                <input name="manufacturerDetails" value={form.manufacturerDetails} onChange={handleChange} placeholder="Company name & address" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Return / exchange policy</label>
                <input name="returnPolicy" value={form.returnPolicy} onChange={handleChange} placeholder="7 days return, unused condition" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Delivery timeline</label>
                <input name="deliveryTimeline" value={form.deliveryTimeline} onChange={handleChange} placeholder="1-3 business days" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Shipping weight</label>
                <input name="shippingWeight" value={form.shippingWeight} onChange={handleChange} placeholder="350 g" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Package dimensions</label>
                <input name="packageDimensions" value={form.packageDimensions} onChange={handleChange} placeholder="30 x 20 x 3 cm" className="w-full px-3 py-2 border rounded-lg" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">GST / Tax rate (%)</label>
                <input name="gstRate" type="number" min="0" step="0.01" value={form.gstRate} onChange={handleChange} placeholder="5" className="w-full px-3 py-2 border rounded-lg" />
              </div>
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

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Tags</label>
              <input name="tags" value={form.tags} onChange={handleChange} placeholder="fresh, organic, bestseller" className="w-full px-3 py-2 border rounded-lg" />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Highlights</label>
              <input name="highlights" value={form.highlights} onChange={handleChange} placeholder="Free delivery, premium quality" className="w-full px-3 py-2 border rounded-lg" />
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
              <input type="file" accept="image/*" multiple onChange={(e) => setImages(Array.from(e.target.files || []))} className="w-full text-sm" />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Promo video</label>
              <input type="file" accept="video/*" onChange={(e) => setVideo(e.target.files?.[0] || null)} className="w-full text-sm" />
            </div>

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
    </div>
  );
}
