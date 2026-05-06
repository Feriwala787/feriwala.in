import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_action_queue_service.dart';
import 'error_reporter.dart';

// Simplified background sync using in-app periodic timer
// (workmanager removed due to Flutter embedding v2 incompatibility)
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  Timer? _timer;

  Future<void> init() async {
    // No-op: timer started via registerPeriodicTasks
  }

  Future<void> registerPeriodicTasks() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) async {
      try {
        await DeliveryApiService().init();
        await OfflineActionQueueService.instance.processQueue();
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: 'background-sync');
      }
    });
    if (kDebugMode) debugPrint('[BackgroundSyncService] periodic sync started');
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
