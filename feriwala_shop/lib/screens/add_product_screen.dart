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
  final _qtyCtrl = TextEditingController(text: '0');
  final _tagCtrl = TextEditingController();

  bool _saving = false;
  List<dynamic> _categories = [];
  int? _categoryId;

  String _gender = 'unisex';
  String? _size;
  String? _color;
  String? _material;
  String? _productType;
  String? _fit;
  String? _pattern;
  String? _sleeveType;
  String? _neckType;
  String? _occasion;
  bool _isFeatured = false;
  final List<String> _tags = [];

  static const _genders = ['men', 'women', 'unisex', 'kids', 'boys', 'girls'];
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '28', '30', '32', '34', '36', '38', '40'];
  static const _colors = ['Black', 'White', 'Blue', 'Navy', 'Grey', 'Red', 'Green', 'Yellow', 'Pink', 'Brown', 'Maroon'];
  static const _materials = ['Cotton', 'Denim', 'Linen', 'Polyester', 'Wool', 'Rayon', 'Silk'];
  static const _productTypes = ['Shirt', 'T-Shirt', 'Jeans', 'Trousers', 'Kurta', 'Dress', 'Jacket', 'Hoodie', 'Shorts'];
  static const _fits = ['Regular', 'Slim', 'Relaxed', 'Oversized'];
  static const _patterns = ['Solid', 'Striped', 'Checked', 'Printed'];
  static const _sleeveTypes = ['Half Sleeve', 'Full Sleeve', 'Sleeveless'];
  static const _neckTypes = ['Round Neck', 'Collar', 'V Neck', 'Mandarin'];
  static const _occasions = ['Casual', 'Formal', 'Party', 'Sports', 'Festive'];
  static const _presetTags = [
    'summer collection', 'party wear', 'casual wear', 'shirts', 'jeans', 'denims',
    'mens', 'womens', 'footwear', 'sportswear', 'ethnic', 'winter collection',
    'sneakers', 'formal shoes', 'heels', 'sandals', 'kids collection', 'gym wear',
    'rain wear', 'kurta', 'formals', 't-shirts', 'underwear', 'lowers', 'pajama',
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
        'color': _color,
        'material': _material,
        'tags': _tags,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product created')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            TextFormField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Brand')),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: _categories
                  .map((c) => DropdownMenuItem<int>(
                        value: (c['id'] as num?)?.toInt(),
                        child: Text(c['name']?.toString() ?? 'Category'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            TextFormField(controller: _mrpCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'MRP *'), validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid MRP' : null),
            TextFormField(controller: _sellingCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price *'), validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid price' : null),
            TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening stock')),
            const SizedBox(height: 10),
            _dropdown('Gender', _gender, _genders, (v) => setState(() => _gender = v ?? 'unisex')),
            _dropdown('Size', _size, _sizes, (v) => setState(() => _size = v)),
            _dropdown('Color', _color, _colors, (v) => setState(() => _color = v)),
            _dropdown('Material', _material, _materials, (v) => setState(() => _material = v)),
            _dropdown('Product Type', _productType, _productTypes, (v) => setState(() => _productType = v)),
            _dropdown('Fit', _fit, _fits, (v) => setState(() => _fit = v)),
            _dropdown('Pattern', _pattern, _patterns, (v) => setState(() => _pattern = v)),
            _dropdown('Sleeve Type', _sleeveType, _sleeveTypes, (v) => setState(() => _sleeveType = v)),
            _dropdown('Neck Type', _neckType, _neckTypes, (v) => setState(() => _neckType = v)),
            _dropdown('Occasion', _occasion, _occasions, (v) => setState(() => _occasion = v)),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isFeatured,
              title: const Text('Featured product'),
              onChanged: (v) => setState(() => _isFeatured = v),
            ),
            Row(
              children: [
                Expanded(child: TextField(controller: _tagCtrl, decoration: const InputDecoration(labelText: 'Add tag'))),
                IconButton(
                  onPressed: () {
                    final tag = _tagCtrl.text.trim();
                    if (tag.isEmpty) return;
                    setState(() => _tags.add(tag));
                    _tagCtrl.clear();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 6,
                children: _tags.map((t) => Chip(label: Text(t), onDeleted: () => setState(() => _tags.remove(t)))).toList(),
              ),
            const SizedBox(height: 10),
            const Text('Quick tags (multi-select)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presetTags
                  .map((t) => FilterChip(
                        label: Text(t),
                        selected: _tags.contains(t),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _tags.add(t);
                            } else {
                              _tags.remove(t);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving ? const CircularProgressIndicator() : const Text('Create Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
