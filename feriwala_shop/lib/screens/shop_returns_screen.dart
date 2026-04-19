import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopReturnsScreen extends StatefulWidget {
  const ShopReturnsScreen({super.key});

  @override
  State<ShopReturnsScreen> createState() => _ShopReturnsScreenState();
}

class _ShopReturnsScreenState extends State<ShopReturnsScreen> {
  bool _loading = true;
  List<dynamic> _returns = [];
  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _loadReturns();
  }

  Future<void> _loadReturns() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) return;
    try {
      final res = await ShopApiService().get('/delivery/returns/shop/$shopId');
      setState(() {
        _returns = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _createDayEndPlan() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) return;

    final targetIds = _selected.isNotEmpty
        ? _selected.toList()
        : _returns
            .where((r) => ['requested', 'approved'].contains(r['status']))
            .map<int>((r) => r['id'] as int)
            .toList();

    if (targetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible return requests for day-end plan')),
      );
      return;
    }

    try {
      await ShopApiService().post('/delivery/returns/day-end-plan', body: {
        'shopId': shopId,
        'returnRequestIds': targetIds,
        'pickupDate': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Day-end return plan created for ${targetIds.length} request(s)')),
      );
      _selected.clear();
      _loadReturns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create day-end return plan')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'pickup_assigned':
        return Colors.indigo;
      case 'picked_up':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            onPressed: _createDayEndPlan,
            tooltip: 'Create day-end pickup plan',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _returns.isEmpty
              ? const Center(child: Text('No return requests'))
              : RefreshIndicator(
                  onRefresh: _loadReturns,
                  child: ListView.builder(
                    itemCount: _returns.length,
                    itemBuilder: (context, index) {
                      final item = _returns[index];
                      final id = item['id'] as int;
                      final canPlan = ['requested', 'approved'].contains(item['status']);
                      final color = _statusColor(item['status']?.toString() ?? '');

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: CheckboxListTile(
                          value: _selected.contains(id),
                          onChanged: canPlan
                              ? (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  });
                                }
                              : null,
                          title: Text('Return #$id • Order #${item['orderId']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['reason'] ?? ''),
                              const SizedBox(height: 4),
                              Text('Type: ${(item['returnType'] ?? 'return').toString().toUpperCase()}'),
                              if (item['bankDetails'] is Map && (item['bankDetails']['bankName'] ?? '').toString().isNotEmpty)
                                Text('Bank: ${item['bankDetails']['bankName']}'),
                              if ((item['refundStatus'] ?? '').toString().isNotEmpty)
                                Text('Refund: ${item['refundStatus']}'),
                            ],
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (item['status'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDayEndPlan,
        icon: const Icon(Icons.route),
        label: const Text('Day-end Plan'),
      ),
    );
  }
}
