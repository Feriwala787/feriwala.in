import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});
  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _sellingCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '10');

  bool _saving = false;
  List<dynamic> _categories = [];
  int? _categoryId;
  bool _isFeatured = false;

  // Single-select
  String _gender = 'men';
  String? _size;
  String? _material;
  String? _productType;
  String? _fit;
  String? _pattern;
  String? _sleeveType;
  String? _neckType;
  String? _occasion;

  // Multi-select
  final Set<String> _selectedColors = {};
  final Set<String> _tags = {};

  // ── Option lists ──────────────────────────────────────────────────────────
  static const _genders = ['men', 'women', 'unisex', 'kids', 'boys', 'girls'];

  static const _sizes = [
    'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL',
    '28', '30', '32', '34', '36', '38', '40', '42',
    'Free Size',
  ];

  static const _colors = [
    'Black', 'White', 'Navy', 'Blue', 'Sky Blue', 'Grey', 'Charcoal',
    'Red', 'Maroon', 'Burgundy', 'Pink', 'Peach', 'Orange', 'Yellow',
    'Green', 'Olive', 'Mint', 'Brown', 'Beige', 'Cream', 'Purple', 'Lavender',
    'Multi-color',
  ];

  static const _materials = [
    'Cotton', '100% Cotton', 'Denim', 'Linen', 'Polyester', 'Nylon',
    'Wool', 'Rayon', 'Viscose', 'Silk', 'Satin', 'Velvet',
    'Spandex', 'Fleece', 'Leather', 'Synthetic',
  ];

  static const _productTypes = [
    'T-Shirt', 'Shirt', 'Polo Shirt', 'Kurta', 'Kurti',
    'Jeans', 'Trousers', 'Chinos', 'Shorts', 'Track Pants', 'Joggers',
    'Dress', 'Skirt', 'Leggings', 'Saree', 'Salwar Suit',
    'Jacket', 'Hoodie', 'Sweatshirt', 'Blazer', 'Coat',
    'Innerwear', 'Sleepwear', 'Swimwear',
  ];

  static const _fits = [
    'Regular Fit', 'Slim Fit', 'Relaxed Fit', 'Oversized',
    'Skinny Fit', 'Straight Fit', 'Tapered Fit',
  ];

  static const _patterns = [
    'Solid', 'Striped', 'Checked', 'Printed', 'Floral',
    'Geometric', 'Abstract', 'Camouflage', 'Tie-Dye', 'Embroidered',
  ];

  static const _sleeveTypes = [
    'Half Sleeve', 'Full Sleeve', 'Sleeveless',
    '3/4 Sleeve', 'Cap Sleeve', 'Raglan',
  ];

  static const _neckTypes = [
    'Round Neck', 'V Neck', 'Collar', 'Polo Collar',
    'Mandarin', 'Hooded', 'Boat Neck', 'Square Neck',
  ];

  static const _occasions = [
    'Casual', 'Formal', 'Party', 'Sports', 'Festive',
    'Beach', 'Lounge', 'Workwear', 'Wedding',
  ];

  static const _presetTags = [
    'new arrival', 'bestseller', 'trending', 'sale', 'limited edition',
    'summer collection', 'winter collection', 'festive collection',
    'casual wear', 'party wear', 'formal wear', 'sportswear', 'ethnic',
    'mens', 'womens', 'kids collection', 'gym wear', 'rain wear',
    't-shirts', 'jeans', 'denims', 'kurta', 'formals', 'sneakers',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ShopApiService().get('/products/categories/all');
      final data = res['data'] as List? ?? [];
      setState(() {
        _categories = data;
        if (_categories.isNotEmpty) {
          _categoryId = (_categories.first['id'] as num?)?.toInt();
        }
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ShopApiService().post('/products', body: {
        'name': _nameCtrl.text.trim(),
        'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'categoryId': _categoryId,
        'mrp': double.parse(_mrpCtrl.text.trim()),
        'sellingPrice': double.parse(_sellingCtrl.text.trim()),
        'quantity': int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        'gender': _gender,
        'size': _size,
        'color': _selectedColors.isNotEmpty ? _selectedColors.join(', ') : null,
        'material': _material,
        'tags': _tags.toList(),
        'isFeatured': _isFeatured,
        'attributes': {
          if (_productType != null) 'productType': _productType,
          if (_fit != null) 'fit': _fit,
          if (_pattern != null) 'pattern': _pattern,
          if (_sleeveType != null) 'sleeveType': _sleeveType,
          if (_neckType != null) 'neckType': _neckType,
          if (_occasion != null) 'occasion': _occasion,
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFF47721))),
      );

  /// Single-select chip row
  Widget _chipSingle(String label, List<String> options, String? selected, ValueChanged<String?> onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((o) {
            final sel = selected == o;
            return GestureDetector(
              onTap: () => onTap(sel ? null : o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFF47721) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? const Color(0xFFF47721) : Colors.grey.shade300),
                ),
                child: Text(o, style: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Multi-select chip row
  Widget _chipMulti(String label, List<String> options, Set<String> selected, Function(String) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((o) {
            final sel = selected.contains(o);
            return GestureDetector(
              onTap: () => setState(() => sel ? selected.remove(o) : selected.add(o)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1A1A2E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? const Color(0xFF1A1A2E) : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sel) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.check, size: 14, color: Colors.white)),
                    Text(o, style: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('List New Product'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [

            // ── Basic Info ──────────────────────────────────────────────────
            _sectionTitle('BASIC INFORMATION'),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDec('Product Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _brandCtrl, decoration: _inputDec('Brand (optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _descCtrl, decoration: _inputDec('Description (optional)'), maxLines: 3),

            // ── Category ────────────────────────────────────────────────────
            _sectionTitle('CATEGORY *'),
            if (_categories.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _categories.map((c) {
                  final id = (c['id'] as num?)?.toInt();
                  final sel = _categoryId == id;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryId = id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFF47721) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sel ? const Color(0xFFF47721) : Colors.grey.shade300),
                      ),
                      child: Text(c['name']?.toString() ?? '', style: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),

            // ── Pricing ─────────────────────────────────────────────────────
            _sectionTitle('PRICING & STOCK'),
            Row(children: [
              Expanded(child: TextFormField(controller: _mrpCtrl, keyboardType: TextInputType.number, decoration: _inputDec('MRP (INR) *'), validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _sellingCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Selling Price *'), validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null)),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: _inputDec('Opening Stock Qty')),

            // ── Gender ──────────────────────────────────────────────────────
            _chipSingle('FOR', _genders, _gender, (v) => setState(() => _gender = v ?? 'men')),

            // ── Product Type ────────────────────────────────────────────────
            _chipSingle('PRODUCT TYPE', _productTypes, _productType, (v) => setState(() => _productType = v)),

            // ── Size ────────────────────────────────────────────────────────
            _chipSingle('SIZE', _sizes, _size, (v) => setState(() => _size = v)),

            // ── Color (multi) ───────────────────────────────────────────────
            _chipMulti('COLOR (select all that apply)', _colors, _selectedColors, (_) {}),

            // ── Material ────────────────────────────────────────────────────
            _chipSingle('MATERIAL', _materials, _material, (v) => setState(() => _material = v)),

            // ── Fit ─────────────────────────────────────────────────────────
            _chipSingle('FIT', _fits, _fit, (v) => setState(() => _fit = v)),

            // ── Pattern ─────────────────────────────────────────────────────
            _chipSingle('PATTERN', _patterns, _pattern, (v) => setState(() => _pattern = v)),

            // ── Sleeve ──────────────────────────────────────────────────────
            _chipSingle('SLEEVE TYPE', _sleeveTypes, _sleeveType, (v) => setState(() => _sleeveType = v)),

            // ── Neck ────────────────────────────────────────────────────────
            _chipSingle('NECK TYPE', _neckTypes, _neckType, (v) => setState(() => _neckType = v)),

            // ── Occasion ────────────────────────────────────────────────────
            _chipSingle('OCCASION', _occasions, _occasion, (v) => setState(() => _occasion = v)),

            // ── Tags (multi) ────────────────────────────────────────────────
            _chipMulti('COLLECTION TAGS (multi-select)', _presetTags, _tags, (_) {}),

            // ── Featured ────────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                value: _isFeatured,
                title: const Text('Mark as Featured', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Show in featured section on home screen'),
                activeColor: const Color(0xFFF47721),
                onChanged: (v) => setState(() => _isFeatured = v),
              ),
            ),

            // ── Submit ──────────────────────────────────────────────────────
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF47721),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('List Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
