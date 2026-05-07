import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';
import '../services/security_guard_service.dart';

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
    if (shopId == null) {
      setState(() {
        _promos = [];
        _loading = false;
      });
      return;
    }
    try {
      final res = await ShopApiService().get('/promos/manage/$shopId');
      setState(() {
        _promos = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showPromoDialog({Map<String, dynamic>? existing, bool duplicate = false}) async {
    final codeCtrl = TextEditingController(text: duplicate ? '${existing?['code'] ?? ''}_COPY' : (existing?['code'] ?? ''));
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final valueCtrl = TextEditingController(text: '${existing?['discountValue'] ?? ''}');
    final minCtrl = TextEditingController(text: '${existing?['minOrderAmount'] ?? 0}');
    final usageLimitCtrl = TextEditingController(text: '${existing?['usageLimit'] ?? ''}');
    final perUserLimitCtrl = TextEditingController(text: '${existing?['perUserLimit'] ?? 1}');
    String type = (existing?['discountType'] ?? 'percentage').toString();
    bool firstOrderOnly = existing?['firstOrderOnly'] == true;
    DateTime validTo = DateTime.tryParse((existing?['validTo'] ?? '').toString()) ?? DateTime.now().add(const Duration(days: 30));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null || duplicate ? 'Create Promo Code' : 'Edit Promo Code'),
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
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: type == 'percentage' ? 'Discount %' : 'Discount INR', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Order Amount', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: usageLimitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Usage Limit (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(controller: perUserLimitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Per User Limit', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text('Expires: ${validTo.toLocal().toString().split(' ').first}'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: validTo,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => validTo = picked);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: firstOrderOnly,
                  title: const Text('First order only'),
                  onChanged: (v) => setDialogState(() => firstOrderOnly = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final code = codeCtrl.text.trim();
                final value = double.tryParse(valueCtrl.text.trim());
                final minOrder = double.tryParse(minCtrl.text.trim());
                final perUser = int.tryParse(perUserLimitCtrl.text.trim());
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo code cannot be empty')));
                  return;
                }
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discount must be greater than zero')));
                  return;
                }
                if (type == 'percentage' && value > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percentage discount cannot exceed 100')));
                  return;
                }
                if (minOrder == null || minOrder < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min order must be zero or greater')));
                  return;
                }
                if (perUser == null || perUser <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Per-user limit must be at least 1')));
                  return;
                }

                try {
                  final payload = {
                    'code': code,
                    'description': descCtrl.text.trim(),
                    'discountType': type,
                    'discountValue': value,
                    'minOrderAmount': minOrder,
                    'usageLimit': usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitCtrl.text.trim()),
                    'perUserLimit': perUser,
                    'firstOrderOnly': firstOrderOnly,
                    'validTo': validTo.toIso8601String(),
                  };

                  if (existing == null || duplicate) {
                    final shopId = context.read<ShopAuthProvider>().shopId;
                    if (shopId == null) return;
                    await ShopApiService().post('/promos', body: {
                      ...payload,
                      'validFrom': DateTime.now().toIso8601String(),
                    });
                  } else {
                    await ShopApiService().put('/promos/${existing['id']}', body: payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadPromos();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              },
              child: Text(existing == null || duplicate ? 'Create' : 'Save'),
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
        onPressed: () => _showPromoDialog(),
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
                    final usage = (p['usageCount'] ?? 0) as num;
                    final conversion = (p['conversionRate'] ?? 0) as num;
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
                          '${p['discountType'] == 'percentage' ? '${p['discountValue']}%' : 'INR ${p['discountValue']}'} off | Min: INR ${p['minOrderAmount']}\n'
                          'Uses: $usage | Conv: ${conversion.toStringAsFixed(1)}% | ${p['firstOrderOnly'] == true ? 'First-order only' : 'All users'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'toggle') {
                              final verified = await SecurityGuardService().guardAction(
                                context,
                                title: 'Promo security check',
                                subtitle: 'Enter PIN to activate/deactivate this promo.',
                              );
                              if (verified) {
                                await ShopApiService().put('/promos/${p['id']}', body: {'isActive': !(p['isActive'] ?? false)});
                                _loadPromos();
                              }
                            }
                            if (value == 'edit') _showPromoDialog(existing: p);
                            if (value == 'duplicate') _showPromoDialog(existing: p, duplicate: true);
                            if (value == 'archive') {
                              final verified = await SecurityGuardService().guardAction(
                                context,
                                title: 'Archive promo',
                                subtitle: 'Enter PIN to archive this promo.',
                              );
                              if (verified) {
                                await ShopApiService().put('/promos/${p['id']}', body: {'isArchived': true, 'isActive': false});
                                _loadPromos();
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'toggle', child: Text('Activate/Deactivate')),
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                            PopupMenuItem(value: 'archive', child: Text('Archive')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
