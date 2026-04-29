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
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _filterStatus = 'all'; // all | active | inactive | low_stock
  String _sortBy = 'newest'; // newest | price_low | price_high | stock_low

  static const int _lowStock = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) { setState(() => _loading = false); return; }
    try {
      final res = await ShopApiService().get('/products', queryParams: {'shopId': '$shopId', 'limit': '200'});
      setState(() {
        _all = res['data'] ?? [];
        _loading = false;
        _applyFilter();
      });
    } catch (_) { setState(() => _loading = false); }
  }

  void _applyFilter() {
    final shopId = context.read<ShopAuthProvider>().shopId;
    var list = List<dynamic>.from(_all);

    // search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
        (p['name'] ?? '').toLowerCase().contains(q) ||
        (p['brand'] ?? '').toLowerCase().contains(q) ||
        (p['color'] ?? '').toLowerCase().contains(q)
      ).toList();
    }

    // status filter
    if (_filterStatus == 'active') list = list.where((p) => p['isActive'] == true).toList();
    if (_filterStatus == 'inactive') list = list.where((p) => p['isActive'] == false).toList();
    if (_filterStatus == 'low_stock') list = list.where((p) => _stock(p, shopId) <= _lowStock && _stock(p, shopId) > 0).toList();

    // sort
    if (_sortBy == 'price_low') list.sort((a, b) => (a['sellingPrice'] as num).compareTo(b['sellingPrice'] as num));
    if (_sortBy == 'price_high') list.sort((a, b) => (b['sellingPrice'] as num).compareTo(a['sellingPrice'] as num));
    if (_sortBy == 'stock_low') list.sort((a, b) => _stock(a, shopId).compareTo(_stock(b, shopId)));
    if (_sortBy == 'newest') list.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

    setState(() => _filtered = list);
  }

  int _stock(dynamic p, int? shopId) {
    final inv = (p['inventory'] as List? ?? []).cast<Map<String, dynamic>?>();
    final entry = inv.firstWhere((i) => i != null && i['shopId'] == shopId, orElse: () => null);
    return (entry?['quantity'] as num?)?.toInt() ?? 0;
  }

  Future<void> _toggle(int id, bool current) async {
    try {
      await ShopApiService().put('/products/$id', body: {'isActive': !current});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = context.watch<ShopAuthProvider>().shopId;
    final active = _all.where((p) => p['isActive'] == true).length;
    final lowStock = _all.where((p) => _stock(p, shopId) <= _lowStock && _stock(p, shopId) > 0).length;
    final outOfStock = _all.where((p) => _stock(p, shopId) == 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) { setState(() => _sortBy = v); _applyFilter(); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest first')),
              const PopupMenuItem(value: 'price_low', child: Text('Price: Low to High')),
              const PopupMenuItem(value: 'price_high', child: Text('Price: High to Low')),
              const PopupMenuItem(value: 'stock_low', child: Text('Stock: Low first')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Stats bar ──────────────────────────────────────────────
                Container(
                  color: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _statChip('${_all.length}', 'Total', Colors.white),
                      const SizedBox(width: 8),
                      _statChip('$active', 'Active', Colors.green.shade300),
                      const SizedBox(width: 8),
                      _statChip('$lowStock', 'Low Stock', Colors.orange.shade300),
                      const SizedBox(width: 8),
                      _statChip('$outOfStock', 'Out of Stock', Colors.red.shade300),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Product listing is available only on the web Product Listing Portal. This app is for viewing and managing listed products.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),

                // ── Search ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, brand, color...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (v) { setState(() => _search = v); _applyFilter(); },
                  ),
                ),

                // ── Filter tabs ────────────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      _filterTab('All', 'all'),
                      _filterTab('Active', 'active'),
                      _filterTab('Inactive', 'inactive'),
                      _filterTab('Low Stock', 'low_stock'),
                    ],
                  ),
                ),

                // ── Grid ───────────────────────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.checkroom, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(_all.isEmpty ? 'No products yet' : 'No results found',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                              if (_all.isEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 24),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'New product listing is available on the web app only. Please use the Product Listing Portal.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) => _productCard(_filtered[i], shopId),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _productCard(dynamic p, int? shopId) {
    final images = p['images'] as List? ?? [];
    final stock = _stock(p, shopId);
    final isActive = p['isActive'] == true;
    final isLow = stock > 0 && stock <= _lowStock;
    final isOut = stock == 0;
    final mrp = (p['mrp'] as num?)?.toDouble() ?? 0;
    final price = (p['sellingPrice'] as num?)?.toDouble() ?? 0;
    final discount = mrp > 0 ? ((mrp - price) / mrp * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Container(
                  height: 130,
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: images.isNotEmpty
                      ? Image.network(images[0], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, size: 40, color: Colors.grey))
                      : const Icon(Icons.checkroom, size: 40, color: Colors.grey),
                ),
              ),
              // Discount badge
              if (discount > 0)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFF47721), borderRadius: BorderRadius.circular(6)),
                    child: Text('$discount% OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              // Active toggle
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: () => _toggle(p['id'], isActive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(isActive ? 'ON' : 'OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  if ((p['brand'] ?? '').isNotEmpty)
                    Text(p['brand'], style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const Spacer(),
                  Row(
                    children: [
                      Text('INR ${price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
                      if (mrp > price) ...[
                        const SizedBox(width: 4),
                        Text('${mrp.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Stock badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOut ? Colors.red.shade50 : isLow ? Colors.orange.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOut ? 'Out of Stock' : isLow ? 'Low: $stock left' : 'Stock: $stock',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOut ? Colors.red.shade700 : isLow ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String count, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      );

  Widget _filterTab(String label, String value) {
    final sel = _filterStatus == value;
    return GestureDetector(
      onTap: () { setState(() => _filterStatus = value); _applyFilter(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF1A1A2E) : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.black87, fontWeight: sel ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }
}
