import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'api_service.dart';
import 'offline_action_queue_service.dart';
import 'error_reporter.dart';

class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  static const String replayQueueTask = 'delivery_replay_queue_task';

  Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: !kReleaseMode);
  }

  Future<void> registerPeriodicTasks() async {
    await Workmanager().registerPeriodicTask(
      'delivery-periodic-replay',
      replayQueueTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        await DeliveryApiService().init();
        if (task == replayQueueTask) {
          await OfflineActionQueueService.instance.processQueue();
        }
        return Future.value(true);
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: 'background-sync');
        return Future.value(false);
      }
    });
  }
}
