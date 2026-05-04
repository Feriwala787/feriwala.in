import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/delivery_auth_provider.dart';
import '../services/api_service.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> with WidgetsBindingObserver {
  static const _closedTaskStatuses = {'completed', 'cancelled', 'failed'};

  List<dynamic> _activeTasks = [];
  List<dynamic> _completedTasks = [];
  bool _loading = true;
  String? _loadError;
  DateTime? _lastSyncedAt;
  int _currentIndex = 0;
  Timer? _locationSyncTimer;
  Timer? _taskPollingTimer;
  final Set<int> _acceptingTaskIds = <int>{};
  final DeliveryApiService _apiService = DeliveryApiService();
  bool _isLoadingTasks = false;
  bool _queuedTaskRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTasks();
    _startLocationSync();
    _startTaskPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSyncTimer?.cancel();
    _taskPollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTasks(showLoader: false);
      _pushLocationIfOnline();
    }
  }

  void _startTaskPolling() {
    _taskPollingTimer?.cancel();
    _taskPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (context.read<DeliveryAuthProvider>().isOnline) {
        _loadTasks(showLoader: false);
      }
    });
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
      await _apiService.put('/delivery/location', body: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
    } catch (_) {}
  }

  void _splitTasks(List<dynamic> tasks) {
    _activeTasks = [];
    _completedTasks = [];

    for (final task in tasks) {
      final status = task['status'];
      if (_closedTaskStatuses.contains(status)) {
        _completedTasks.add(task);
      } else {
        _activeTasks.add(task);
      }
    }
  }

  Future<void> _loadTasks({bool showLoader = true}) async {
    if (_isLoadingTasks) {
      _queuedTaskRefresh = true;
      return;
    }

    _isLoadingTasks = true;

    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    try {
      final res = await _apiService.get('/delivery/my-tasks');
      if (!mounted) return;

      final tasks = res['data'] ?? [];
      setState(() {
        _splitTasks(tasks);
        _loading = false;
        _loadError = null;
        _lastSyncedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    } finally {
      _isLoadingTasks = false;
      if (_queuedTaskRefresh) {
        _queuedTaskRefresh = false;
        _loadTasks(showLoader: false);
      }
    }
  }

  Future<void> _acceptTask(int taskId) async {
    if (_acceptingTaskIds.contains(taskId)) return;

    setState(() => _acceptingTaskIds.add(taskId));
    try {
      await _apiService.put('/delivery/tasks/$taskId/accept');
      await _loadTasks(showLoader: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task accepted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _acceptingTaskIds.remove(taskId));
      }
    }
  }

  Future<void> _openMapsForTask(Map<String, dynamic> task) async {
    final isDeliveryLeg = task['status'] == 'picked_up' || task['status'] == 'in_transit';
    final location = ((isDeliveryLeg ? task['dropLocation'] : task['pickupLocation']) as Map?) ?? const {};
    final lat = location['latitude'];
    final lng = location['longitude'];

    if (lat is! num || lng is! num) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location coordinates not available for this task.')),
        );
      }
      return;
    }

    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${lat.toDouble()},${lng.toDouble()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DeliveryAuthProvider>();
    final assignedCount = _activeTasks.where((t) => t['status'] == 'assigned').length;

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
              IconButton(
                tooltip: 'Refresh tasks',
                onPressed: () => _loadTasks(showLoader: false),
                icon: const Icon(Icons.refresh),
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
              : _loadError != null
                  ? _ErrorState(message: _loadError!, onRetry: _loadTasks)
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: _activeTasks.isEmpty
                      ? ListView(children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (assignedCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                                    child: Text('$assignedCount new task${assignedCount > 1 ? 's' : ''} waiting',
                                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                                  ),
                                Icon(auth.isOnline ? Icons.hourglass_empty : Icons.cloud_off, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(auth.isOnline ? 'Waiting for tasks...' : 'Go online to receive tasks'),
                                if (_lastSyncedAt != null) ...[
                                  const SizedBox(height: 8),
                                  Text('Last synced: ${_lastSyncedAt!.hour.toString().padLeft(2, '0')}:${_lastSyncedAt!.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
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
                                ? () => _acceptTask((_activeTasks[index]['id'] as num).toInt())
                                : null,
                            isAccepting: _acceptingTaskIds.contains((_activeTasks[index]['id'] as num).toInt()),
                            onNavigate: () => _openMapsForTask(_activeTasks[index]),
                          ),
                        ),
                ),

          // History
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: _completedTasks.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(
                              height: 400,
                              child: Center(child: Text('No task history')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _completedTasks.length,
                          itemBuilder: (context, index) => _TaskCard(task: _completedTasks[index], onTap: () {}),
                        ),
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
  final VoidCallback? onNavigate;
  final bool isAccepting;
  const _TaskCard({required this.task, required this.onTap, this.onAccept, this.onNavigate, this.isAccepting = false});

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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isAccepting ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isAccepting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Accept Task'),
                      ),
                    ),
                    if (onNavigate != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.navigation),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFFF47721), foregroundColor: Colors.white),
                      ),
                    ],
                  ],
                ),
              ] else if (onNavigate != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Could not load tasks', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
