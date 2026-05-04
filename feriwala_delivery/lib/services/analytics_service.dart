import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _eventsKey = 'delivery_analytics_events';
  final DeliveryApiService _api = DeliveryApiService();

  Future<void> track(String name, {Map<String, dynamic>? props}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);
    final events = raw == null || raw.isEmpty ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
    events.add({
      'name': name,
      'timestamp': DateTime.now().toIso8601String(),
      'props': props ?? const {},
    });
    if (events.length > 300) {
      events.removeRange(0, events.length - 300);
    }
    await prefs.setString(_eventsKey, jsonEncode(events));
  }

  Future<void> exportPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);
    if (raw == null || raw.isEmpty) return;

    final events = jsonDecode(raw) as List<dynamic>;
    if (events.isEmpty) return;

    await _api.post('/delivery/telemetry/events', body: {'events': events});
    await prefs.remove(_eventsKey);
  }
}
