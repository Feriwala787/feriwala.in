import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopPromosScreen extends StatefulWidget {
  const ShopPromosScreen({super.key});

  @override
  State<ShopPromosScreen> createState() => _ShopPromosScreenState();
}

class _ShopPromosScreenState extends State<ShopPromosScreen> {
  List<dynamic> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPromos();
  }

  Future<void> _loadPromos() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    try {
      final res = await ShopApiService().get('/promos/manage/$shopId');
      setState(() { _promos = res['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showAddDialog() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    String type = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Promo Code'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
                    DropdownMenuItem(value: 'flat', child: Text('Flat Amount')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: valueCtrl, keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: type == 'percentage' ? 'Discount %' : 'Discount ₹', border: const OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: minCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min Order Amount', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final now = DateTime.now();
                  await ShopApiService().post('/promos', body: {
                    'code': codeCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'discountType': type,
                    'discountValue': double.parse(valueCtrl.text),
                    'minOrderAmount': double.parse(minCtrl.text),
                    'validFrom': now.toIso8601String(),
                    'validTo': now.add(const Duration(days: 30)).toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadPromos();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo Codes')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFF47721),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? const Center(child: Text('No promo codes yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _promos.length,
                  itemBuilder: (context, index) {
                    final p = _promos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF47721).withAlpha(25), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.local_offer, color: Color(0xFFF47721)),
                        ),
                        title: Text(p['code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p['discountType'] == 'percentage' ? '${p['discountValue']}%' : '₹${p['discountValue']}'} off | Min: ₹${p['minOrderAmount']}',
                        ),
                        trailing: Switch(
                          value: p['isActive'] ?? false,
                          onChanged: (v) async {
                            await ShopApiService().put('/promos/${p['id']}', body: {'isActive': v});
                            _loadPromos();
                          },
                          activeThumbColor: const Color(0xFFF47721),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
