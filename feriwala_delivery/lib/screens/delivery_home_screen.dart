import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/delivery_auth_provider.dart';
import '../services/api_service.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  List<dynamic> _tasks = [];
  bool _loading = true;
  int _currentIndex = 0;
  Timer? _locationSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _startLocationSync();
  }

  @override
  void dispose() {
    _locationSyncTimer?.cancel();
    super.dispose();
  }

  void _startLocationSync() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = Timer.periodic(const Duration(minutes: 1), (_) => _pushLocationIfOnline());
    _pushLocationIfOnline();
  }

  Future<void> _pushLocationIfOnline() async {
    final auth = context.read<DeliveryAuthProvider>();
    if (!auth.isOnline) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await DeliveryApiService().put('/delivery/location', body: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    try {
      final res = await DeliveryApiService().get('/delivery/my-tasks');
      setState(() { _tasks = res['data'] ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _activeTasks => _tasks.where((t) => !['completed', 'cancelled', 'failed'].contains(t['status'])).toList();
  List<dynamic> get _completedTasks => _tasks.where((t) => ['completed', 'cancelled', 'failed'].contains(t['status'])).toList();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DeliveryAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feriwala Delivery'),
        actions: [
          // Online toggle
          Row(
            children: [
              Text(auth.isOnline ? 'Online' : 'Offline', style: const TextStyle(fontSize: 12)),
              Switch(
                value: auth.isOnline,
                onChanged: (_) async {
                  await auth.toggleOnline();
                  _pushLocationIfOnline();
                },
                activeThumbColor: Colors.green,
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Active tasks
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: _activeTasks.isEmpty
                      ? ListView(children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(auth.isOnline ? Icons.hourglass_empty : Icons.cloud_off, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(auth.isOnline ? 'Waiting for tasks...' : 'Go online to receive tasks'),
                              ],
                            ),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _activeTasks.length,
                          itemBuilder: (context, index) => _TaskCard(
                            task: _activeTasks[index],
                            onTap: () async {
                              await Navigator.pushNamed(context, '/task-detail', arguments: _activeTasks[index]['id']);
                              _loadTasks();
                            },
                            onAccept: _activeTasks[index]['status'] == 'assigned'
                                ? () async {
                                    try {
                                      await DeliveryApiService().put('/delivery/tasks/${_activeTasks[index]['id']}/accept');
                                      _loadTasks();
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                    }
                                  }
                                : null,
                          ),
                        ),
                ),

          // History
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _completedTasks.isEmpty
                  ? const Center(child: Text('No task history'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _completedTasks.length,
                      itemBuilder: (context, index) => _TaskCard(task: _completedTasks[index], onTap: () {}),
                    ),

          // Profile
          _ProfileTab(auth: auth),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.task), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  const _TaskCard({required this.task, required this.onTap, this.onAccept});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'assigned': Colors.orange, 'accepted': Colors.blue,
      'picking': Colors.indigo, 'picked_up': Colors.purple,
      'in_transit': Colors.deepOrange, 'completed': Colors.green,
      'cancelled': Colors.red, 'failed': Colors.red,
    };
    final icons = {
      'delivery': Icons.delivery_dining,
      'pickup': Icons.store,
      'return_pickup': Icons.keyboard_return,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icons[task['taskType']] ?? Icons.local_shipping, color: const Color(0xFFF47721)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${task['taskType']?.toString().replaceAll('_', ' ').toUpperCase()} #${task['id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (colors[task['status']] ?? Colors.grey).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task['status']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
                      style: TextStyle(color: colors[task['status']] ?? Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task['estimatedMinutes'] != null)
                Text('ETA: ${task['estimatedMinutes']} min | ${task['distanceKm'] ?? '-'} km'),
              if (onAccept != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Accept Task'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final DeliveryAuthProvider auth;
  const _ProfileTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFF47721).withAlpha(25),
            child: const Icon(Icons.person, size: 40, color: Color(0xFFF47721)),
          ),
          const SizedBox(height: 12),
          Text(auth.user?['name'] ?? 'Agent', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(auth.user?['email'] ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Phone'),
            subtitle: Text(auth.user?['phone'] ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await auth.logout();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
