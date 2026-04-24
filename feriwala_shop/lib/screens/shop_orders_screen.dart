import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopOrdersScreen extends StatefulWidget {
  const ShopOrdersScreen({super.key});

  @override
  State<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends State<ShopOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _orders = [];
  bool _loading = true;
  String _currentStatus = '';

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
  }

  Future<void> _loadOrders() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final params = <String, String>{'limit': '50'};
      if (_currentStatus.isNotEmpty) params['status'] = _currentStatus;
      final res = await ShopApiService().get('/orders/shop/$shopId', queryParams: params);
      setState(() {
        _orders = res['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      await ShopApiService().put('/orders/$orderId/status', body: {'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order $newStatus'), backgroundColor: Colors.green));
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
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
      body: _loading
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
                                Text('${(order['items'] as List?)?.length ?? 0} items | ₹${order['total']}'),
                                const SizedBox(height: 8),
                                // Action buttons
                                if (order['status'] == 'pending')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _updateStatus(order['id'], 'cancelled'),
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': Colors.orange, 'confirmed': Colors.blue,
      'preparing': Colors.indigo, 'ready_for_pickup': Colors.purple,
      'delivered': Colors.green, 'cancelled': Colors.red,
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
