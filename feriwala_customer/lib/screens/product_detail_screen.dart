import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _loading = true;
  int _quantity = 1;

  Map<String, dynamic> get _attributes {
    final raw = _product?['attributes'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry(key.toString(), value));
    return const {};
  }

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final res = await ApiService().get('/products/${widget.productId}');
      setState(() {
        _product = res['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _addToCart() {
    if (_product == null) return;
    final cart = context.read<CartProvider>();
    cart.addItem(
      CartItem(
        productId: _product!['id'],
        name: _product!['name'],
        price: double.parse(_product!['sellingPrice'].toString()),
        image: (_product!['images'] as List?)?.isNotEmpty == true ? _product!['images'][0] : null,
        size: _product!['size'],
        color: _product!['color'],
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
                      // Images
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

                            // Price
                            Row(
                              children: [
                                Text('₹${_product!['sellingPrice']}',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF47721))),
                                const SizedBox(width: 8),
                                if (_product!['mrp'].toString() != _product!['sellingPrice'].toString())
                                  Text('₹${_product!['mrp']}',
                                      style: const TextStyle(fontSize: 16, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                const SizedBox(width: 8),
                                if (_product!['discount'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                                    child: Text('${double.parse(_product!['discount'].toString()).toStringAsFixed(0)}% OFF',
                                        style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Details
                            if (_product!['size'] != null) _DetailRow(label: 'Size', value: _product!['size']),
                            if (_product!['color'] != null) _DetailRow(label: 'Color', value: _product!['color']),
                            if (_product!['material'] != null) _DetailRow(label: 'Material', value: _product!['material']),
                            if (_product!['gender'] != null) _DetailRow(label: 'For', value: _product!['gender']),
                            if (_attributes['productType'] != null) _DetailRow(label: 'Type', value: _attributes['productType']),
                            if (_attributes['fit'] != null) _DetailRow(label: 'Fit', value: _attributes['fit']),
                            if (_attributes['pattern'] != null) _DetailRow(label: 'Pattern', value: _attributes['pattern']),
                            if (_attributes['sleeveType'] != null) _DetailRow(label: 'Sleeve', value: _attributes['sleeveType']),
                            if (_attributes['neckType'] != null) _DetailRow(label: 'Neck', value: _attributes['neckType']),
                            if (_attributes['occasion'] != null) _DetailRow(label: 'Occasion', value: _attributes['occasion']),

                            // Stock
                            if (_product!['inventory'] != null && (_product!['inventory'] as List).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  (_product!['inventory'][0]['quantity'] ?? 0) > 0 ? 'In Stock' : 'Out of Stock',
                                  style: TextStyle(
                                    color: (_product!['inventory'][0]['quantity'] ?? 0) > 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),
                            if (_attributes['careInstructions'] != null || _attributes['sizeChartUrl'] != null) ...[
                              const Text('Care & Sizing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (_attributes['careInstructions'] != null)
                                _DetailRow(label: 'Care', value: _attributes['careInstructions']),
                              if (_attributes['sizeChartUrl'] != null)
                                _DetailRow(label: 'Size Chart', value: _attributes['sizeChartUrl']),
                              const SizedBox(height: 12),
                            ],

                            if (_attributes['countryOfOrigin'] != null ||
                                _attributes['manufacturerDetails'] != null ||
                                _attributes['returnPolicy'] != null ||
                                _attributes['deliveryTimeline'] != null ||
                                _attributes['shippingWeight'] != null ||
                                _attributes['packageDimensions'] != null ||
                                _attributes['gstRate'] != null) ...[
                              const Text('Shipping & Policy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (_attributes['countryOfOrigin'] != null)
                                _DetailRow(label: 'Origin', value: _attributes['countryOfOrigin']),
                              if (_attributes['manufacturerDetails'] != null)
                                _DetailRow(label: 'Manufacturer', value: _attributes['manufacturerDetails']),
                              if (_attributes['returnPolicy'] != null)
                                _DetailRow(label: 'Return', value: _attributes['returnPolicy']),
                              if (_attributes['deliveryTimeline'] != null)
                                _DetailRow(label: 'Delivery', value: _attributes['deliveryTimeline']),
                              if (_attributes['shippingWeight'] != null)
                                _DetailRow(label: 'Weight', value: _attributes['shippingWeight']),
                              if (_attributes['packageDimensions'] != null)
                                _DetailRow(label: 'Dimensions', value: _attributes['packageDimensions']),
                              if (_attributes['gstRate'] != null)
                                _DetailRow(label: 'GST', value: '${_attributes['gstRate']}%'),
                              const SizedBox(height: 12),
                            ],

                            if (_product!['description'] != null) ...[
                              const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(_product!['description'], style: const TextStyle(color: Colors.grey, height: 1.5)),
                            ],

                            const SizedBox(height: 24),

                            // Quantity
                            Row(
                              children: [
                                const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(width: 16),
                                IconButton(
                                  onPressed: () => setState(() { if (_quantity > 1) _quantity--; }),
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
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF47721),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          : null,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
