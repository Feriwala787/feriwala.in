import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feriwala_delivery/services/api_service.dart';
import 'package:feriwala_delivery/services/offline_action_queue_service.dart';

class FakeApiService extends DeliveryApiService {
  int failCount;
  int putCalls = 0;
  FakeApiService({this.failCount = 0});

  @override
  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body, Map<String, String>? extraHeaders}) async {
    putCalls++;
    if (failCount > 0) {
      failCount--;
      throw Exception('fail');
    }
    return {'ok': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('queue drains after successful replay', () async {
    final api = FakeApiService();
    final queue = OfflineActionQueueService(api: api);
    await queue.enqueuePut(endpoint: '/delivery/tasks/1/accept', body: const {});

    expect(await queue.pendingCount(), 1);
    await queue.processQueue();
    expect(api.putCalls, 1);
    expect(await queue.pendingCount(), 0);
  });

  test('failed replay is retained with retry metadata', () async {
    final api = FakeApiService(failCount: 1);
    final queue = OfflineActionQueueService(api: api);
    await queue.enqueuePut(endpoint: '/delivery/location', body: {'latitude': 1, 'longitude': 2});

    await queue.processQueue();
    expect(await queue.pendingCount(), 1);

    final prefs = await SharedPreferences.getInstance();
    final list = jsonDecode(prefs.getString('delivery_offline_action_queue')!) as List<dynamic>;
    expect((list.first['retryCount'] as num).toInt(), 1);
  });

  test('enqueue deduplicates by id and caps queue size', () async {
    final api = FakeApiService();
    final queue = OfflineActionQueueService(api: api);

    await queue.enqueuePut(endpoint: '/delivery/location', body: {'latitude': 1, 'longitude': 2}, id: 'loc-1');
    await queue.enqueuePut(endpoint: '/delivery/location', body: {'latitude': 1, 'longitude': 2}, id: 'loc-1');
    expect(await queue.pendingCount(), 1);

    for (var i = 0; i < 220; i++) {
      await queue.enqueuePut(endpoint: '/delivery/tasks/$i/accept', body: const {}, id: 'task-$i');
    }
    expect(await queue.pendingCount(), 200);
  });

  test('moves action to dead letter after max retries', () async {
    final api = FakeApiService(failCount: 10);
    final queue = OfflineActionQueueService(api: api);
    await queue.enqueuePut(endpoint: '/delivery/tasks/99/accept', body: const {}, id: 'task-99');

    for (var i = 0; i < 6; i++) {
      await queue.processQueue();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('delivery_offline_action_queue');
      if (raw != null && raw.isNotEmpty) {
        final items = jsonDecode(raw) as List<dynamic>;
        for (final item in items) {
          item['nextAttemptAt'] = DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String();
        }
        await prefs.setString('delivery_offline_action_queue', jsonEncode(items));
      }
    }

    expect(await queue.pendingCount(), 0);
    final prefs = await SharedPreferences.getInstance();
    final dead = jsonDecode(prefs.getString('delivery_offline_action_dead_letter_queue')!) as List<dynamic>;
    expect(dead.isNotEmpty, true);
  });
}
