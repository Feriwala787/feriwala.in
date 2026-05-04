import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  bool _loading = true;
  bool _updatingStatus = false;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    try {
      final res = await DeliveryApiService().get('/delivery/my-tasks');
      final tasks = res['data'] as List? ?? [];
      final task = tasks.firstWhere((t) => t['id'] == widget.taskId, orElse: () => null);
      setState(() { _task = task; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String status, {String? otp}) async {
    if (_updatingStatus || _task == null) return;
    final currentStatus = _task!['status']?.toString() ?? '';
    final allowedTransitions = {
      'accepted': {'picking'},
      'picking': {'picked_up'},
      'picked_up': {'in_transit', 'completed'},
      'in_transit': {'completed'},
    };

    if (!(allowedTransitions[currentStatus]?.contains(status) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid status transition. Refresh and try again.')),
      );
      return;
    }

    setState(() => _updatingStatus = true);
    try {
      final body = <String, dynamic>{'status': status};
      if (otp != null) body['otp'] = otp;
      await DeliveryApiService().put(
        '/delivery/tasks/${widget.taskId}/status',
        body: body,
        extraHeaders: {'X-Idempotency-Key': 'status-${widget.taskId}-$status'},
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated: $status'), backgroundColor: Colors.green));
      AnalyticsService.instance.track('task_status_updated', props: {'taskId': widget.taskId, 'status': status});
      _loadTask();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update status. Please retry.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  void _showOtpDialog(String nextStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'OTP from customer/shop', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final otp = _otpController.text.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 6-digit OTP.')),
                );
                return;
              }
              Navigator.pop(ctx);
              _updateStatus(nextStatus, otp: otp);
              _otpController.clear();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(double lat, double lng) async {
    final googleUri = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
    final wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Open in Google Maps'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await canLaunchUrl(googleUri)) {
                  await launchUrl(googleUri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.alt_route),
              title: const Text('Open in Waze'),
              onTap: () async {
                Navigator.pop(ctx);
                if (await canLaunchUrl(wazeUri)) {
                  await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(webUri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task #${widget.taskId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? const Center(child: Text('Task not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type and status
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _task!['taskType'] == 'delivery' ? Icons.delivery_dining
                                        : _task!['taskType'] == 'return_pickup' ? Icons.keyboard_return
                                        : Icons.store,
                                    color: const Color(0xFFF47721), size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _task!['taskType'].toString().replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Status: ${_task!['status'].toString().replaceAll('_', ' ').toUpperCase()}',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              if (_task!['estimatedMinutes'] != null)
                                Text('ETA: ${_task!['estimatedMinutes']} min | ${_task!['distanceKm'] ?? '-'} km'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pickup location
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.store, color: Colors.blue),
                          title: const Text('Pickup Location'),
                          subtitle: Text(((_task!['pickupLocation'] as Map?)?['address'])?.toString() ?? 'Shop location'),
                          trailing: IconButton(
                            icon: const Icon(Icons.navigation, color: Color(0xFFF47721)),
                            onPressed: () {
                              final map = (_task!['pickupLocation'] as Map?) ?? const {};
                              final lat = map['latitude'];
                              final lng = map['longitude'];
                              if (lat is num && lng is num) _openMaps(lat.toDouble(), lng.toDouble());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Drop location
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: const Text('Drop Location'),
                          subtitle: Text(((_task!['dropLocation'] as Map?)?['address'])?.toString() ?? 'Customer location'),
                          trailing: IconButton(
                            icon: const Icon(Icons.navigation, color: Color(0xFFF47721)),
                            onPressed: () {
                              final map = (_task!['dropLocation'] as Map?) ?? const {};
                              final lat = map['latitude'];
                              final lng = map['longitude'];
                              if (lat is num && lng is num) _openMaps(lat.toDouble(), lng.toDouble());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons based on status
                      ..._buildActions(),

                      // Return task link
                      if (_task!['taskType'] == 'return_pickup' && _task!['status'] == 'picked_up')
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/return-verification', arguments: widget.taskId),
                              icon: const Icon(Icons.checklist),
                              label: const Text('Return Verification Checklist'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildActions() {
    final status = _task!['status'] as String;
    final paymentMethod = _task?['order']?['paymentMethod']?.toString();
    final widgets = <Widget>[];

    if (status == 'accepted') {
      widgets.add(_actionButton('Start Picking', Colors.indigo, () => _updateStatus('picking')));
    }
    if (status == 'picking') {
      widgets.add(_actionButton('Verify Pickup OTP', Colors.purple, () => _showOtpDialog('picked_up')));
    }
    if (status == 'picked_up' && _task!['taskType'] != 'return_pickup') {
      widgets.add(_actionButton('Start Delivery', Colors.deepOrange, () => _updateStatus('in_transit')));
    }
    if (status == 'in_transit') {
      if (paymentMethod == 'cod') {
        widgets.add(_actionButton('Mark Delivered (COD)', Colors.green, () => _updateStatus('completed')));
      } else {
        widgets.add(_actionButton('Verify Delivery OTP', Colors.green, () => _showOtpDialog('completed')));
      }
    }

    if (_updatingStatus) {
      widgets.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ));
    }

    return widgets;
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _updatingStatus ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
