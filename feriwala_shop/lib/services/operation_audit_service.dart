import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OperationAuditService {
  static const _key = 'shop_operation_audit_log';

  Future<void> log({required String action, required String status, String? detail}) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_key) ?? [];
    rows.insert(0, jsonEncode({
      'action': action,
      'status': status,
      'detail': detail,
      'at': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_key, rows.take(200).toList());
  }

  Future<List<Map<String, dynamic>>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }
}
