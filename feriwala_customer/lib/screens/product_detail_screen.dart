import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/cart_provider.dart';
import '../services/analytics_service.dart';

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
  int _selectedImageIndex = 0;
  final PageController _pageController = PageController();

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

  Map<String, dynamic> get _variantPrices {
    final raw = _attributes['variantPrices'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    return const {};
  }

  Map<String, dynamic> get _colorImages {
    final raw = _attributes['colorImages'];
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

  bool _isVariantSelectable(String size, String color) {
    if (_variantStock.isEmpty) return true;
    final key = '${size}__${color}';
    return (int.tryParse(_variantStock[key].toString()) ?? 0) > 0;
  }

  void _ensureValidVariantSelection() {
    if (_selectedSize == null || _selectedColor == null || _variantStock.isEmpty) return;
    if (_isVariantSelectable(_selectedSize!, _selectedColor!)) return;
    for (final c in _availableColors) {
      if (_isVariantSelectable(_selectedSize!, c)) {
        _selectedColor = c;
        return;
      }
    }
    for (final s in _availableSizes) {
      if (_isVariantSelectable(s, _selectedColor!)) {
        _selectedSize = s;
        return;
      }
    }
  }

  String _variantFallbackHint() {
    if (_selectedSize == null || _selectedColor == null) return '';
    if (_isVariantSelectable(_selectedSize!, _selectedColor!)) return '';
    final altSize = _availableSizes.where((s) => _isVariantSelectable(s, _selectedColor!)).cast<String?>().firstWhere((e) => e != null, orElse: () => null);
    final altColor = _availableColors.where((c) => _isVariantSelectable(_selectedSize!, c)).cast<String?>().firstWhere((e) => e != null, orElse: () => null);
    if (altSize != null) return 'Try size $altSize in $_selectedColor';
    if (altColor != null) return 'Try $_selectedSize in color $altColor';
    return 'Selected combination is unavailable.';
  }

  double _selectedVariantPrice() {
    if (_selectedSize != null && _selectedColor != null && _variantPrices.isNotEmpty) {
      final key = '${_selectedSize!}__${_selectedColor!}';
      final v = _variantPrices[key];
      if (v != null) return double.tryParse(v.toString()) ?? double.parse(_product!['sellingPrice'].toString());
    }
    return double.parse(_product!['sellingPrice'].toString());
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        price: _selectedVariantPrice(),
        image: (_product!['images'] as List?)?.isNotEmpty == true ? _product!['images'][0] : null,
        size: _selectedSize ?? _product!['size'],
        color: _selectedColor ?? _product!['color'],
        quantity: _quantity,
      ),
      _product!['shopId'],
    );
    AnalyticsService().track('pdp_add_to_cart', props: {
      'productId': _product!['id'],
      'size': _selectedSize,
      'color': _selectedColor,
      'quantity': _quantity,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart!'), backgroundColor: Color(0xFFF47721)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final selectedStock = _stockForSelection();
    final selectedPrice = _product == null ? 0 : _selectedVariantPrice();

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
                                controller: _pageController,
                                itemCount: (_product!['images'] as List).length,
                                onPageChanged: (i) => setState(() => _selectedImageIndex = i),
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
                      if ((_product!['images'] as List?)?.length != null && (_product!['images'] as List).length > 1)
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            itemCount: (_product!['images'] as List).length,
                            itemBuilder: (context, i) => GestureDetector(
                              onTap: () => setState(() => _selectedImageIndex = i),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: _selectedImageIndex == i ? const Color(0xFFF47721) : Colors.transparent, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network((_product!['images'] as List)[i], width: 54, height: 54, fit: BoxFit.cover),
                                ),
                              ),
                            ),
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
                                Text('INR ${selectedPrice.toStringAsFixed(2)}',
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
                                    onSelected: disabled ? null : (_) => setState(() { _selectedSize = size; _ensureValidVariantSelection(); AnalyticsService().track('pdp_size_selected', props: {'size': size}); }),
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
                                  final sizeForCheck = _selectedSize ?? (_availableSizes.isNotEmpty ? _availableSizes.first : '');
                                  final selectable = sizeForCheck.isEmpty ? true : _isVariantSelectable(sizeForCheck, color);
                                  final normalized = color.toLowerCase();
                                  final swatchColor = normalized.contains('black')
                                      ? Colors.black
                                      : normalized.contains('white')
                                          ? Colors.white
                                          : normalized.contains('blue')
                                              ? Colors.blue
                                              : normalized.contains('red')
                                                  ? Colors.red
                                                  : normalized.contains('green')
                                                      ? Colors.green
                                                      : Colors.grey;
                                  return ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: swatchColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.black12),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(selectable ? color : '$color (Out)'),
                                      ],
                                    ),
                                    selected: _selectedColor == color,
                                    onSelected: selectable
                                        ? (_) => setState(() {
                                              _selectedColor = color;
                                              _ensureValidVariantSelection();
                                              AnalyticsService().track('pdp_color_selected', props: {'color': color});
                                              final colorImage = _colorImages[color];
                                              final images = (_product!['images'] as List?) ?? [];
                                              if (colorImage != null) {
                                                final idx = images.indexWhere((img) => img.toString() == colorImage.toString());
                                                if (idx >= 0) {
                                                  _selectedImageIndex = idx;
                                                  _pageController.animateToPage(idx, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
                                                }
                                              }
                                            })
                                        : null,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(selectedStock > 0 ? 'In Stock: $selectedStock' : 'Out of Stock',
                                style: TextStyle(color: selectedStock > 0 ? Colors.green : Colors.red)),
                            if (_variantFallbackHint().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(_variantFallbackHint(), style: const TextStyle(fontSize: 12, color: Colors.orange)),
                              ),
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
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Policy highlights', style: TextStyle(fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Text('• Free cancellation before pickup'),
                                  Text('• 7-day return window on eligible items'),
                                  Text('• Refund processed after quality check'),
                                  Text('• Real customer photos: coming soon'),
                                ],
                              ),
                            ),
                            if ((_product!['highlights'] as List?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 12),
                              const Text('Highlights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              ...( (_product!['highlights'] as List).map((h) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• ${h.toString()}'),
                              )) ),
                            ],
                            const SizedBox(height: 10),
                            const Text('Complete the look', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text('You may also like matching styles from this shop.', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                              child: const Text('Similar style in your size and preferred colors will be recommended here.'),
                            ),
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
                                  onPressed: selectedStock > 0 && _quantity < selectedStock ? () => setState(() => _quantity++) : null,
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
