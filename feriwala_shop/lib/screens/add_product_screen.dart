import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _brandController = TextEditingController();
  final _mrpController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  String _gender = 'unisex';
  int? _categoryId;
  List<dynamic> _categories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ShopApiService().get('/products/categories/all');
      setState(() => _categories = res['data'] ?? []);
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _saving = true);
    try {
      await ShopApiService().post('/products', body: {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'brand': _brandController.text.trim(),
        'categoryId': _categoryId,
        'mrp': double.parse(_mrpController.text),
        'sellingPrice': double.parse(_priceController.text),
        'gender': _gender,
        'quantity': int.parse(_quantityController.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                validator: (v) => v != null && v.isNotEmpty ? null : 'Required',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                items: _categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name']))).toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v != null ? null : 'Select a category',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                items: ['men', 'women', 'unisex', 'kids', 'boys', 'girls']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mrpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'MRP (₹) *', border: OutlineInputBorder()),
                      validator: (v) => v != null && double.tryParse(v) != null ? null : 'Enter valid price',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Selling Price (₹) *', border: OutlineInputBorder()),
                      validator: (v) => v != null && double.tryParse(v) != null ? null : 'Enter valid price',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Initial Stock Quantity', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF47721),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Add Product', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
