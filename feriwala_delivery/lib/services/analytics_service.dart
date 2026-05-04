import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _eventsKey = 'delivery_analytics_events';

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
}
