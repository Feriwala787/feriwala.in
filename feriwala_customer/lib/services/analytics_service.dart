import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  void track(String event, {Map<String, dynamic>? props}) {
    debugPrint('[analytics] $event ${props ?? {}}');
  }
}
