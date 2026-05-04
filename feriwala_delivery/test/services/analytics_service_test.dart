import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feriwala_delivery/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('track persists events', () async {
    await AnalyticsService.instance.track('task_accept_success', props: {'taskId': 10});

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('delivery_analytics_events');
    expect(raw, isNotNull);

    final events = jsonDecode(raw!) as List<dynamic>;
    expect(events.length, 1);
    expect(events.first['name'], 'task_accept_success');
    expect(events.first['props']['taskId'], 10);
  });

  test('track keeps only latest 300 events', () async {
    for (var i = 0; i < 305; i++) {
      await AnalyticsService.instance.track('event_$i');
    }

    final prefs = await SharedPreferences.getInstance();
    final events = jsonDecode(prefs.getString('delivery_analytics_events')!) as List<dynamic>;

    expect(events.length, 300);
    expect(events.first['name'], 'event_5');
    expect(events.last['name'], 'event_304');
  });
}
