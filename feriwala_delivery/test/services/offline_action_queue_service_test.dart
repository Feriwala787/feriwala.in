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
}
