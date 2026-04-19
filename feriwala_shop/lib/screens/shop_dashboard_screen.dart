import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) return;
    try {
      final res = await ShopApiService().get('/shops/$shopId/stats');
      setState(() => _stats = res['data']);
    } catch (e) {
      debugPrint('Failed to load stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ShopAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feriwala Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome, ${auth.user?['name'] ?? 'Shop Admin'}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Stats cards
              if (_stats != null)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(title: 'Total Orders', value: '${_stats!['totalOrders']}', icon: Icons.receipt, color: Colors.blue),
                    _StatCard(title: "Today's Orders", value: '${_stats!['todayOrders']}', icon: Icons.today, color: Colors.orange),
                    _StatCard(title: 'Products', value: '${_stats!['totalProducts']}', icon: Icons.checkroom, color: Colors.green),
                    _StatCard(title: 'Pending', value: '${_stats!['pendingOrders']}', icon: Icons.pending_actions, color: Colors.red),
                  ],
                ),

              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              _ActionTile(icon: Icons.receipt_long, title: 'Orders', subtitle: 'Manage incoming orders',
                  onTap: () => Navigator.pushNamed(context, '/orders')),
              _ActionTile(icon: Icons.checkroom, title: 'Products', subtitle: 'Add and manage products',
                  onTap: () => Navigator.pushNamed(context, '/products')),
              _ActionTile(icon: Icons.inventory_2, title: 'Inventory', subtitle: 'Track stock levels',
                  onTap: () => Navigator.pushNamed(context, '/inventory')),
              _ActionTile(icon: Icons.local_offer, title: 'Promo Codes', subtitle: 'Create deals and offers',
                  onTap: () => Navigator.pushNamed(context, '/promos')),
              _ActionTile(icon: Icons.delivery_dining, title: 'Delivery', subtitle: 'Assign and track deliveries',
                  onTap: () => Navigator.pushNamed(context, '/delivery')),
              _ActionTile(icon: Icons.keyboard_return, title: 'Returns', subtitle: 'Review return requests and plan day-end pickups',
                  onTap: () => Navigator.pushNamed(context, '/returns')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF47721).withAlpha(25), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFFF47721)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
