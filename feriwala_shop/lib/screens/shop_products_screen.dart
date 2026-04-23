import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopProductsScreen extends StatefulWidget {
  const ShopProductsScreen({super.key});

  @override
  State<ShopProductsScreen> createState() => _ShopProductsScreenState();
}

class _ShopProductsScreenState extends State<ShopProductsScreen> {
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    try {
      final res = await ShopApiService().get('/products', queryParams: {'shopId': '$shopId', 'limit': '100'});
      setState(() {
        _products = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleProduct(int productId, bool isActive) async {
    try {
      await ShopApiService().put('/products/$productId', body: {'isActive': !isActive});
      _loadProducts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () async {
            await Navigator.pushNamed(context, '/add-product');
            _loadProducts();
          }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.checkroom, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No products yet'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/add-product'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Product'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      final images = p['images'] as List? ?? [];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50, height: 50, color: Colors.grey[200],
                              child: images.isNotEmpty
                                  ? Image.network(images[0], fit: BoxFit.cover)
                                  : const Icon(Icons.checkroom, color: Colors.grey),
                            ),
                          ),
                          title: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('₹${p['sellingPrice']} | Stock: ${p['inventory']?[0]?['quantity'] ?? 0}'),
                          trailing: Switch(
                            value: p['isActive'] ?? true,
                            onChanged: (_) => _toggleProduct(p['id'], p['isActive'] ?? true),
                            activeThumbColor: const Color(0xFFF47721),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
