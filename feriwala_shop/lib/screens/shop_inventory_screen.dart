import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopInventoryScreen extends StatefulWidget {
  const ShopInventoryScreen({super.key});

  @override
  State<ShopInventoryScreen> createState() => _ShopInventoryScreenState();
}

class _ShopInventoryScreenState extends State<ShopInventoryScreen> {
  static const List<String> _reasons = [
    'sale_correction',
    'damaged',
    'return',
    'manual_correction',
  ];

  List<dynamic> _products = [];
  bool _loading = true;
  bool _onlyLowStock = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    try {
      final res = await ShopApiService().get('/products', queryParams: {'shopId': '$shopId', 'limit': '200'});
      setState(() {
        _products = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  bool _isLow(dynamic product) {
    final inv = (product['inventory'] as List?)?.isNotEmpty == true ? product['inventory'][0] : null;
    final qty = inv?['quantity'] ?? 0;
    final threshold = inv?['lowStockThreshold'] ?? 5;
    return qty <= threshold;
  }

  Future<void> _showUpdateDialog(Map<String, dynamic> product) async {
    final inv = (product['inventory'] as List?)?.isNotEmpty == true ? product['inventory'][0] : null;
    final qtyCtrl = TextEditingController(text: '${inv?['quantity'] ?? 0}');
    final thresholdCtrl = TextEditingController(text: '${inv?['lowStockThreshold'] ?? 5}');
    String reason = _reasons.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Update Stock: ${product['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Low-stock threshold', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(labelText: 'Adjustment reason', border: OutlineInputBorder()),
                  items: _reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').toUpperCase())))
                      .toList(),
                  onChanged: (v) => setDialogState(() => reason = v ?? _reasons.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ShopApiService().put('/products/${product['id']}/inventory', body: {
                    'quantity': int.parse(qtyCtrl.text),
                    'lowStockThreshold': int.parse(thresholdCtrl.text),
                    'reason': reason,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadProducts();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInventoryHistory(Map<String, dynamic> product) async {
    try {
      final res = await ShopApiService().get('/products/${product['id']}/inventory/history');
      final history = (res['data'] ?? []) as List<dynamic>;
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          builder: (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Stock History - ${product['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('No inventory history yet'))
                    : ListView.builder(
                        controller: controller,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final h = history[index];
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text('${h['delta'] ?? 0} (${h['reason'] ?? 'manual'})'),
                            subtitle: Text('${h['createdAt'] ?? ''} | by ${h['actor'] ?? 'system'}'),
                            trailing: Text('Qty: ${h['quantityAfter'] ?? '-'}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory history unavailable for this product')),
      );
    }
  }

  Future<void> _restockLowStockQueue() async {
    final lowStock = _products.where(_isLow).toList();
    if (lowStock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No low-stock items found')));
      return;
    }

    for (final p in lowStock) {
      final inv = (p['inventory'] as List?)?.isNotEmpty == true ? p['inventory'][0] : null;
      final threshold = inv?['lowStockThreshold'] ?? 5;
      final targetQty = threshold + 10;
      try {
        await ShopApiService().put('/products/${p['id']}/inventory', body: {
          'quantity': targetQty,
          'lowStockThreshold': threshold,
          'reason': 'manual_correction',
        });
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restock plan applied for ${lowStock.length} item(s).')),
    );
    _loadProducts();
  }

  Future<void> _importCsvUpdate() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final content = String.fromCharCodes(result.files.first.bytes!);
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV has no data rows')));
      return;
    }

    int success = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;
      final sku = row[0].toString();
      final qty = int.tryParse(row[1].toString());
      final threshold = int.tryParse(row[2].toString());
      if (qty == null || threshold == null) continue;
      final product = _products.cast<Map<String, dynamic>?>().firstWhere(
            (p) => p?['sku']?.toString() == sku,
            orElse: () => null,
          );
      if (product == null) continue;
      try {
        await ShopApiService().put('/products/${product['id']}/inventory', body: {
          'quantity': qty,
          'lowStockThreshold': threshold,
          'reason': 'manual_correction',
        });
        success++;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV import done. Updated $success product(s).')));
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final displayProducts = _onlyLowStock ? _products.where(_isLow).toList() : _products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(onPressed: _restockLowStockQueue, icon: const Icon(Icons.playlist_add_check), tooltip: 'One-click restock plan'),
          IconButton(
            onPressed: _importCsvUpdate,
            icon: const Icon(Icons.upload_file),
            tooltip: 'CSV bulk import',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SwitchListTile(
                  title: const Text('Show only low-stock queue'),
                  value: _onlyLowStock,
                  onChanged: (v) => setState(() => _onlyLowStock = v),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: displayProducts.length,
                      itemBuilder: (context, index) {
                        final p = displayProducts[index];
                        final inv = (p['inventory'] as List?)?.isNotEmpty == true ? p['inventory'][0] : null;
                        final qty = inv?['quantity'] ?? 0;
                        final isLow = _isLow(p);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(p['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('SKU: ${p['sku'] ?? 'N/A'} | Threshold: ${inv?['lowStockThreshold'] ?? 5}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isLow ? Colors.red[50] : Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$qty',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isLow ? Colors.red : Colors.green[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.history, color: Colors.blueGrey),
                                  onPressed: () => _showInventoryHistory(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFFF47721)),
                                  onPressed: () => _showUpdateDialog(p),
                                ),
                              ],
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
