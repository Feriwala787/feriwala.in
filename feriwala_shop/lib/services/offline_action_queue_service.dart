import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineActionQueueService {
  static const _key = 'shop_offline_action_queue';

  Future<void> enqueue({required String endpoint, required Map<String, dynamic> body}) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_key) ?? [];
    rows.add(jsonEncode({'endpoint': endpoint, 'body': body, 'at': DateTime.now().toIso8601String()}));
    await prefs.setStringList(_key, rows);
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }

  Future<int> processQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_key) ?? [];
    int success = 0;
    final remaining = <String>[];

    for (final row in rows) {
      try {
        final data = jsonDecode(row) as Map<String, dynamic>;
        await ShopApiService().put(data['endpoint'], body: (data['body'] as Map).cast<String, dynamic>());
        success++;
      } catch (_) {
        remaining.add(row);
      }
    }

    await prefs.setStringList(_key, remaining);
    return success;
  }
}
