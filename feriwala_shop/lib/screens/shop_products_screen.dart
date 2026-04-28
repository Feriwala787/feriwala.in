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
    if (shopId == null) {
      setState(() => _loading = false);
      return;
    }

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

  static const int _lowStockThreshold = 5;

  int _warehouseStock(dynamic product, int? shopId) {
    final inventoryList = product['inventory'] as List? ?? [];
    if (shopId == null) return 0;

    final currentWarehouseInventory = inventoryList.cast<Map<String, dynamic>?>().firstWhere(
          (inv) => inv != null && inv['shopId'] == shopId,
          orElse: () => null,
        );

    return currentWarehouseInventory?['quantity'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final shopId = context.watch<ShopAuthProvider>().shopId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Create Product',
            onPressed: () async {
              final created = await Navigator.pushNamed(context, '/products/add');
              if (created == true) _loadProducts();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    shopId == null
                        ? 'Warehouse assignment missing. Please contact admin.'
                        : 'Showing products for Warehouse #$shopId only.',
                    style: TextStyle(
                      color: shopId == null ? Colors.red.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: _products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.checkroom, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text('No products in this warehouse'),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap + to create product in a separate page.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
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
                              final stock = _warehouseStock(p, shopId);
                              final isLowStock = stock > 0 && stock <= _lowStockThreshold;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: images.isNotEmpty
                                          ? Image.network(images[0], fit: BoxFit.cover)
                                          : const Icon(Icons.checkroom, color: Colors.grey),
                                    ),
                                  ),
                                  title: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('INR ${p['sellingPrice']} | Warehouse Stock: $stock'),
                                      if (isLowStock)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text('Low stock', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                    ],
                                  ),
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
                ),
              ],
            ),
    );
  }
}
