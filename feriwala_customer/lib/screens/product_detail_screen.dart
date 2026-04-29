import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _shop;
  bool _loading = true;
  int _quantity = 1;
  String? _selectedSize;
  String? _selectedColor;

  Map<String, dynamic> get _attributes {
    final raw = _product?['attributes'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    return const {};
  }

  List<String> get _availableSizes {
    final list = _attributes['availableSizes'];
    if (list is List) return list.map((e) => e.toString()).toList();
    final sizeString = (_product?['size'] ?? '').toString();
    if (sizeString.isEmpty) return [];
    return sizeString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> get _sizeInventories {
    final raw = _attributes['sizeInventories'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    return const {};
  }

  Map<String, dynamic> get _variantStock {
    final raw = _attributes['variantStock'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    return const {};
  }

  List<String> get _availableColors {
    final colorString = (_product?['color'] ?? '').toString();
    if (colorString.isEmpty) return [];
    return colorString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  int _stockForSize(String size) {
    final value = _sizeInventories[size];
    if (value == null) return (_product?['inventory'] as List?)?.isNotEmpty == true ? ((_product!['inventory'][0]['quantity'] ?? 0) as num).toInt() : 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  int _stockForSelection() {
    if (_selectedSize != null && _selectedColor != null && _variantStock.isNotEmpty) {
      final key = '${_selectedSize!}__${_selectedColor!}';
      return int.tryParse(_variantStock[key].toString()) ?? 0;
    }
    if (_selectedSize != null) return _stockForSize(_selectedSize!);
    return (_product?['inventory'] as List?)?.isNotEmpty == true ? ((_product!['inventory'][0]['quantity'] ?? 0) as num).toInt() : 0;
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _saveRecentlyViewed() async {
    if (_product == null) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_products') ?? [];
    final entry = jsonEncode({
      'id': _product!['id'],
      'name': _product!['name'],
      'image': (_product!['images'] as List?)?.isNotEmpty == true ? _product!['images'][0] : null,
      'sellingPrice': _product!['sellingPrice'],
    });
    list.removeWhere((e) => e.contains('"id":${_product!['id']}'));
    list.insert(0, entry);
    await prefs.setStringList('recent_products', list.take(12).toList());
  }

  Future<void> _loadProduct() async {
    try {
      final res = await ApiService().get('/products/${widget.productId}');
      final product = res['data'];
      Map<String, dynamic>? shop;
      if (product['shopId'] != null) {
        final shopRes = await ApiService().get('/shops/${product['shopId']}');
        shop = shopRes['data'];
      }
      setState(() {
        _product = product;
        _shop = shop;
        final sizes = _availableSizes;
        if (sizes.isNotEmpty) _selectedSize = sizes.first;
        final colors = _availableColors;
        if (colors.isNotEmpty) _selectedColor = colors.first;
        _loading = false;
      });
      _saveRecentlyViewed();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _addToCart() {
    if (_product == null) return;
    if (_availableSizes.isNotEmpty && (_selectedSize == null || _stockForSelection() <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected variant is out of stock'), backgroundColor: Colors.orange));
      return;
    }
    if (_availableColors.isNotEmpty && _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select color'), backgroundColor: Colors.orange));
      return;
    }

    final cart = context.read<CartProvider>();
    cart.addItem(
      CartItem(
        productId: _product!['id'],
        name: _product!['name'],
        price: double.parse(_product!['sellingPrice'].toString()),
        image: (_product!['images'] as List?)?.isNotEmpty == true ? _product!['images'][0] : null,
        size: _selectedSize ?? _product!['size'],
        color: _selectedColor ?? _product!['color'],
        quantity: _quantity,
      ),
      _product!['shopId'],
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart!'), backgroundColor: Color(0xFFF47721)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final selectedStock = _stockForSelection();

    return Scaffold(
      appBar: AppBar(
        title: Text(_product?['name'] ?? 'Product'),
        actions: [
          IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => Navigator.pushNamed(context, '/cart')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? const Center(child: Text('Product not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 350,
                        child: (_product!['images'] as List?)?.isNotEmpty == true
                            ? PageView.builder(
                                itemCount: (_product!['images'] as List).length,
                                itemBuilder: (context, i) => Image.network(
                                  _product!['images'][i],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.checkroom, size: 80, color: Colors.grey)),
                              ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_product!['brand'] != null)
                              Text(_product!['brand'], style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(_product!['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('INR ${_product!['sellingPrice']}',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                                const SizedBox(width: 8),
                                if (_product!['mrp'].toString() != _product!['sellingPrice'].toString())
                                  Text('INR ${_product!['mrp']}',
                                      style: const TextStyle(fontSize: 16, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_shop != null)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.delivery_dining, color: Color(0xFFF47721)),
                                    const SizedBox(width: 8),
                                    Text('Delivery in ${_product!['estimatedDeliveryMinutes'] ?? 30} mins - Fee INR ${_shop!['deliveryFee'] ?? 0}'),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            if (_availableSizes.isNotEmpty) ...[
                              const Text('Select Size', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: _availableSizes.map((size) {
                                  final stock = _stockForSize(size);
                                  final disabled = stock <= 0;
                                  return ChoiceChip(
                                    label: Text(disabled ? '$size (Out)' : size),
                                    selected: _selectedSize == size,
                                    onSelected: disabled ? null : (_) => setState(() => _selectedSize = size),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (_availableColors.isNotEmpty) ...[
                              const Text('Select Color', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: _availableColors.map((color) {
                                  return ChoiceChip(
                                    label: Text(color),
                                    selected: _selectedColor == color,
                                    onSelected: (_) => setState(() => _selectedColor = color),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(selectedStock > 0 ? 'In Stock: $selectedStock' : 'Out of Stock',
                                style: TextStyle(color: selectedStock > 0 ? Colors.green : Colors.red)),
                            const SizedBox(height: 16),
                            if ((_product!['shortDescription'] ?? '').toString().isNotEmpty) ...[
                              Text(_product!['shortDescription'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                              const SizedBox(height: 12),
                            ],
                            if (_product!['description'] != null) ...[
                              const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(_product!['description'], style: const TextStyle(color: Colors.grey, height: 1.5)),
                            ],
                            if ((_product!['highlights'] as List?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              const Text('Highlights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              ...( (_product!['highlights'] as List).map((h) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• ${h.toString()}'),
                              )) ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: () => setState(() {
                                    if (_quantity > 1) _quantity--;
                                  }),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                IconButton(
                                  onPressed: () => setState(() => _quantity++),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _product != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  if (cart.itemCount > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/cart'),
                        icon: const Icon(Icons.shopping_cart),
                        label: Text('Cart (${cart.itemCount})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF47721),
                          side: const BorderSide(color: Color(0xFFF47721)),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                  if (cart.itemCount > 0) const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: selectedStock <= 0 ? null : _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF47721),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(selectedStock <= 0 ? 'Out of Stock' : 'Add to Cart',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
