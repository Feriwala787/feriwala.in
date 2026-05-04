import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopOrdersScreen extends StatefulWidget {
  const ShopOrdersScreen({super.key});

  @override
  State<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends State<ShopOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _orders = [];
  bool _loading = true;
  String _currentStatus = '';
  String _sortBy = 'latest';
  String _paymentFilter = 'all';
  bool _highValueOnly = false;
  Timer? _pollTimer;
  DateTime? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final statuses = ['', 'pending', 'confirmed', 'delivered'];
        _currentStatus = statuses[_tabController.index];
        _loadOrders();
      }
    });
    _loadOrders();
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) => _loadOrders(silent: true));
  }

  Future<void> _loadOrders({bool silent = false}) async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) {
      setState(() => _loading = false);
      return;
    }
    if (!silent) setState(() => _loading = true);
    try {
      final params = <String, String>{'limit': '100'};
      if (_currentStatus.isNotEmpty) params['status'] = _currentStatus;
      final query = _searchCtrl.text.trim();
      if (query.isNotEmpty) params['search'] = query;
      if (_paymentFilter != 'all') params['paymentMethod'] = _paymentFilter;
      if (_highValueOnly) params['minTotal'] = '1000';

      final res = await ShopApiService().get('/orders/shop/$shopId', queryParams: params);
      final data = (res['data'] ?? []) as List<dynamic>;

      data.sort((a, b) {
        if (_sortBy == 'amount_high') {
          final av = (a['total'] ?? 0) as num;
          final bv = (b['total'] ?? 0) as num;
          return bv.compareTo(av);
        }
        if (_sortBy == 'oldest') {
          return (a['createdAt'] ?? '').toString().compareTo((b['createdAt'] ?? '').toString());
        }
        return (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString());
      });

      if (!mounted) return;
      setState(() {
        _orders = data;
        _loading = false;
        _lastSyncAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      await ShopApiService().put('/orders/$orderId/status', body: {'status': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $newStatus'), backgroundColor: Colors.green),
      );
      _loadOrders(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmAllPending() async {
    final pending = _orders.where((o) => o['status'] == 'pending').toList();
    if (pending.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm all pending orders?'),
        content: Text('This will confirm ${pending.length} pending order(s).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm All')),
        ],
      ),
    );
    if (ok != true) return;

    int success = 0;
    for (final order in pending) {
      try {
        await ShopApiService().put('/orders/${order['id']}/status', body: {'status': 'confirmed'});
        success++;
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Confirmed $success/${pending.length} pending order(s).')),
    );
    _loadOrders(silent: true);
  }

  Future<bool> _confirmDangerAction(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Continue')),
        ],
      ),
    );
    return result == true;
  }

  bool _isOverdue(dynamic order) {
    final createdAtRaw = order['createdAt']?.toString();
    if (createdAtRaw == null || createdAtRaw.isEmpty) return false;
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return false;
    final status = order['status']?.toString() ?? '';
    if (!(status == 'pending' || status == 'confirmed' || status == 'preparing')) return false;
    return DateTime.now().difference(createdAt).inMinutes > 15;
  }

  String _ageText(dynamic order) {
    final createdAt = DateTime.tryParse(order['createdAt']?.toString() ?? '');
    if (createdAt == null) return '-';
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    return '${minutes}m';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(onPressed: _confirmAllPending, icon: const Icon(Icons.done_all), tooltip: 'Confirm all pending'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF47721),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search order # / customer',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _loadOrders(),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadOrders(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Sort'),
                        items: const [
                          DropdownMenuItem(value: 'latest', child: Text('Latest')),
                          DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                          DropdownMenuItem(value: 'amount_high', child: Text('High value')),
                        ],
                        onChanged: (v) => setState(() => _sortBy = v ?? 'latest'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentFilter,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Payment'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'cod', child: Text('COD')),
                          DropdownMenuItem(value: 'online', child: Text('Online')),
                          DropdownMenuItem(value: 'upi', child: Text('UPI')),
                          DropdownMenuItem(value: 'card', child: Text('Card')),
                        ],
                        onChanged: (v) => setState(() => _paymentFilter = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Only high-value orders (>= INR 1000)'),
                  value: _highValueOnly,
                  onChanged: (v) => setState(() => _highValueOnly = v ?? false),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _lastSyncAt == null
                        ? 'Live sync: starting...'
                        : 'Live sync: active • last ${_lastSyncAt!.hour.toString().padLeft(2, '0')}:${_lastSyncAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(child: Text('No orders'))
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final overdue = _isOverdue(order);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () => Navigator.pushNamed(context, '/order-detail', arguments: order['id']),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('#${order['orderNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          _StatusChip(order['status']),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('${(order['items'] as List?)?.length ?? 0} items | INR ${order['total']}'),
                                      Text('Age: ${_ageText(order)}'),
                                      if (overdue)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text('⚠ Overdue prep/delivery risk', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                        ),
                                      const SizedBox(height: 8),
                                      if (order['status'] == 'pending')
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () async {
                                                  final ok = await _confirmDangerAction('Reject order?', 'This cannot be easily undone.');
                                                  if (ok) _updateStatus(order['id'], 'cancelled');
                                                },
                                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Reject'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _updateStatus(order['id'], 'confirmed'),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                child: const Text('Accept'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (order['status'] == 'confirmed')
                                        ElevatedButton(
                                          onPressed: () => _updateStatus(order['id'], 'preparing'),
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF47721)),
                                          child: const Text('Start Preparing'),
                                        ),
                                      if (order['status'] == 'preparing')
                                        ElevatedButton(
                                          onPressed: () => _updateStatus(order['id'], 'ready_for_pickup'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                                          child: const Text('Ready for Pickup'),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadOrders,
        backgroundColor: const Color(0xFFF47721),
        label: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.filter_alt, color: Colors.white),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'preparing': Colors.indigo,
      'ready_for_pickup': Colors.purple,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (colors[status] ?? Colors.grey).withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: colors[status] ?? Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
