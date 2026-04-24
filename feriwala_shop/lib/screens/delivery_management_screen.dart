import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shop_auth_provider.dart';
import '../services/api_service.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _nearbyAgents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final shopId = context.read<ShopAuthProvider>().shopId;
    if (shopId == null) return;
    try {
      final res = await ShopApiService().get('/delivery/shop-tasks/$shopId');
      final agentsRes = await ShopApiService().get('/delivery/agents/nearby/$shopId');
      setState(() {
        _tasks = res['data'] ?? [];
        _nearbyAgents = agentsRes['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _reassignTask(int taskId) async {
    final selectedAgentId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reassign task'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_mode),
                title: const Text('Auto nearest available'),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              ..._nearbyAgents.map((a) => ListTile(
                    title: Text(a['name'] ?? 'Delivery Agent'),
                    subtitle: Text('${a['phone'] ?? ''} • ${a['distanceKm'] ?? '-'} km • load ${a['activeTaskCount'] ?? 0}'),
                    onTap: () => Navigator.pop(ctx, a['agentId']?.toString() ?? ''),
                  )),
            ],
          ),
        ),
      ),
    );

    if (selectedAgentId == null) return;
    try {
      await ShopApiService().put('/delivery/tasks/$taskId/reassign', body: {
        if (selectedAgentId.isNotEmpty) 'newAgentId': selectedAgentId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task reassigned')));
      _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Color _taskColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'assigned': return Colors.blue;
      case 'accepted': return Colors.indigo;
      case 'picking': case 'picked_up': return Colors.purple;
      case 'in_transit': return Colors.deepOrange;
      case 'completed': return Colors.green;
      case 'cancelled': case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _taskIcon(String type) {
    switch (type) {
      case 'delivery': return Icons.delivery_dining;
      case 'pickup': return Icons.store;
      case 'return_pickup': return Icons.keyboard_return;
      default: return Icons.local_shipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Tasks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No delivery tasks'))
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_taskIcon(task['taskType']), color: const Color(0xFFF47721)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${task['taskType']?.toString().replaceAll('_', ' ').toUpperCase() ?? ''} #${task['id']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _taskColor(task['status']).withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      task['status']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
                                      style: TextStyle(color: _taskColor(task['status']), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Order #${task['orderId']}', style: const TextStyle(color: Colors.grey)),
                              if (task['agentId'] != null)
                                Text('Agent: ${task['agentId']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              if (task['agentId'] == null)
                                const Text('⚠ No agent assigned', style: TextStyle(color: Colors.orange, fontSize: 12)),
                              if (task['estimatedMinutes'] != null)
                                Text('ETA: ${task['estimatedMinutes']} min', style: const TextStyle(fontSize: 12)),
                              if (task['sla'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (task['sla']['level'] == 'critical'
                                              ? Colors.red
                                              : task['sla']['level'] == 'warning'
                                                  ? Colors.orange
                                                  : Colors.green)
                                          .withAlpha(30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'SLA: ${task['sla']['reason']} (${task['sla']['ageMinutes']}m)',
                                      style: TextStyle(
                                        color: task['sla']['level'] == 'critical'
                                            ? Colors.red
                                            : task['sla']['level'] == 'warning'
                                                ? Colors.orange.shade800
                                                : Colors.green.shade700,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              if (['assigned', 'accepted', 'picking', 'in_transit'].contains(task['status']))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _reassignTask(task['id']),
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Reassign'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
