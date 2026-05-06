import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String title;
  final List<String> searchKeys;

  const CategoryProductsScreen({
    super.key,
    required this.title,
    required this.searchKeys,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<dynamic> _products = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/products', queryParams: {
        'limit': '50',
        'page': '$_page',
      });
      final list = (res['data'] as List? ?? []).whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .where((p) {
        final text = '${p['name']} ${p['description']} ${p['category']?['name'] ?? ''} ${(p['tags'] as List? ?? []).join(' ')}'.toLowerCase();
        return widget.searchKeys.any((k) => text.contains(k));
      }).toList();
      if (mounted) {
        setState(() {
          _products = reset ? list : [..._products, ...list];
          _hasMore = list.length >= 20;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _products = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('No products found'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _products.length + (_hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _products.length) {
                      return Center(
                        child: OutlinedButton(
                          onPressed: () {
                            _page++;
                            _loadProducts();
                          },
                          child: const Text('Load more'),
                        ),
                      );
                    }
                    return _ProductCard(product: _products[i] as Map<String, dynamic>);
                  },
                ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final images = (product['images'] as List? ?? []);
    final name = product['name'] ?? '';
    final price = product['sellingPrice']?.toString() ?? '';
    final mrp = product['mrp']?.toString() ?? '';
    final discount = double.tryParse((product['discount'] ?? '0').toString()) ?? 0;
    final brand = product['brand'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product', arguments: product['id']),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 0.9,
              child: images.isNotEmpty
                  ? Image.network(images[0], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade100, child: const Icon(Icons.checkroom, color: Colors.grey)))
                  : Container(color: Colors.grey.shade100, child: const Icon(Icons.checkroom, color: Colors.grey, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (brand.isNotEmpty) Text(brand, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(children: [
                Text('₹$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF47721))),
                if (mrp != price && mrp.isNotEmpty) ...[ 
                  const SizedBox(width: 4),
                  Text('₹$mrp', style: const TextStyle(decoration: TextDecoration.lineThrough, fontSize: 11, color: Colors.grey)),
                ],
              ]),
              if (discount > 0)
                Text('${discount.toStringAsFixed(0)}% off', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500)),
            ]),
          ),
        ]),
      ),
    );
  }
}
