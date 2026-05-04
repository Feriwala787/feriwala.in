import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class OfflineAction {
  final String id;
  final String endpoint;
  final Map<String, dynamic> body;
  final int retryCount;
  final DateTime nextAttemptAt;

  const OfflineAction({
    required this.id,
    required this.endpoint,
    required this.body,
    required this.retryCount,
    required this.nextAttemptAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'body': body,
        'retryCount': retryCount,
        'nextAttemptAt': nextAttemptAt.toIso8601String(),
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
        id: json['id'].toString(),
        endpoint: json['endpoint'].toString(),
        body: Map<String, dynamic>.from(json['body'] as Map? ?? const {}),
        retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
        nextAttemptAt: DateTime.tryParse(json['nextAttemptAt']?.toString() ?? '') ?? DateTime.now(),
      );

  OfflineAction copyWith({int? retryCount, DateTime? nextAttemptAt}) => OfflineAction(
        id: id,
        endpoint: endpoint,
        body: body,
        retryCount: retryCount ?? this.retryCount,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      );
}

class OfflineActionQueueService {
  OfflineActionQueueService({DeliveryApiService? api}) : _api = api ?? DeliveryApiService();
  static final OfflineActionQueueService instance = OfflineActionQueueService();

  static const _storageKey = 'delivery_offline_action_queue';
  final DeliveryApiService _api;
  bool _isProcessing = false;

  Future<List<OfflineAction>> loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => OfflineAction.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> _saveQueue(List<OfflineAction> actions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(actions.map((e) => e.toJson()).toList()));
  }

  Future<void> enqueuePut({
    required String endpoint,
    required Map<String, dynamic> body,
    String? id,
  }) async {
    final actions = await loadQueue();
    final actionId = id ?? '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(99999)}';
    actions.add(OfflineAction(
      id: actionId,
      endpoint: endpoint,
      body: body,
      retryCount: 0,
      nextAttemptAt: DateTime.now(),
    ));
    await _saveQueue(actions);
  }

  Future<int> pendingCount() async => (await loadQueue()).length;

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      var actions = await loadQueue();
      if (actions.isEmpty) return;

      final now = DateTime.now();
      final updated = <OfflineAction>[];

      for (final action in actions) {
        if (action.nextAttemptAt.isAfter(now)) {
          updated.add(action);
          continue;
        }

        try {
          await _api.put(action.endpoint, body: action.body, extraHeaders: {'X-Idempotency-Key': action.id});
        } catch (_) {
          final nextRetry = action.retryCount + 1;
          final backoffSeconds = min(300, pow(2, min(nextRetry, 8)).toInt());
          updated.add(action.copyWith(
            retryCount: nextRetry,
            nextAttemptAt: DateTime.now().add(Duration(seconds: backoffSeconds)),
          ));
        }
      }

      await _saveQueue(updated);
    } finally {
      _isProcessing = false;
    }
  }
}
