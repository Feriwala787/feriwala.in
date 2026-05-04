import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/offline_action_queue_service.dart';
import '../services/security_posture_service.dart';

class DeliveryDiagnosticsScreen extends StatefulWidget {
  const DeliveryDiagnosticsScreen({super.key});

  @override
  State<DeliveryDiagnosticsScreen> createState() => _DeliveryDiagnosticsScreenState();
}

class _DeliveryDiagnosticsScreenState extends State<DeliveryDiagnosticsScreen> {
  int _queuedActions = 0;
  int _pendingTelemetry = 0;
  bool _securityGate = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final queued = await OfflineActionQueueService.instance.pendingCount();
    final telemetry = await AnalyticsService.instance.pendingCount();
    final security = SecurityPostureService.instance.allowSensitiveNetworkCalls;
    if (mounted) {
      setState(() {
        _queuedActions = queued;
        _pendingTelemetry = telemetry;
        _securityGate = security;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(title: const Text('Queued offline actions'), trailing: Text('$_queuedActions')),
            ListTile(title: const Text('Pending telemetry events'), trailing: Text('$_pendingTelemetry')),
            ListTile(
              title: const Text('Security posture gate'),
              trailing: Text(_securityGate ? 'ALLOWED' : 'BLOCKED', style: TextStyle(color: _securityGate ? Colors.green : Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
