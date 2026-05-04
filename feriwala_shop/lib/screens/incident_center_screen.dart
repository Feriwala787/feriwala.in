import 'package:flutter/material.dart';
import '../services/offline_action_queue_service.dart';
import '../services/operation_audit_service.dart';
import '../services/shop_socket_service.dart';

class IncidentCenterScreen extends StatefulWidget {
  const IncidentCenterScreen({super.key});

  @override
  State<IncidentCenterScreen> createState() => _IncidentCenterScreenState();
}

class _IncidentCenterScreenState extends State<IncidentCenterScreen> {
  int _pendingQueue = 0;
  bool _socketLive = false;
  List<Map<String, dynamic>> _audit = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final queue = await OfflineActionQueueService().pendingCount();
    final logs = await OperationAuditService().all();
    if (!mounted) return;
    setState(() {
      _pendingQueue = queue;
      _socketLive = ShopSocketService().isConnected;
      _audit = logs.take(20).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Center')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(title: const Text('Socket Health'), trailing: Text(_socketLive ? 'LIVE' : 'DEGRADED', style: TextStyle(color: _socketLive ? Colors.green : Colors.orange))),
            ListTile(title: const Text('Offline Queue'), trailing: Text('$_pendingQueue pending')),
            const Divider(),
            const ListTile(title: Text('Recent Operation Logs')),
            ..._audit.map((a) => ListTile(
                  leading: Icon(a['status'] == 'success' ? Icons.check_circle : Icons.error, color: a['status'] == 'success' ? Colors.green : Colors.red),
                  title: Text(a['action'] ?? '-'),
                  subtitle: Text('${a['detail'] ?? ''}\n${a['at'] ?? ''}'),
                  isThreeLine: true,
                )),
            if (_audit.isEmpty) const ListTile(title: Text('No operation logs yet')),
          ],
        ),
      ),
    );
  }
}
