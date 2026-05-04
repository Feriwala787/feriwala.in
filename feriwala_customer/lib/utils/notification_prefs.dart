import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefs {
  static const _orderUpdatesKey = 'notif_order_updates';
  static const _returnUpdatesKey = 'notif_return_updates';
  static const _promoKey = 'notif_promotions';

  static Future<Map<String, bool>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'orderUpdates': prefs.getBool(_orderUpdatesKey) ?? true,
      'returnUpdates': prefs.getBool(_returnUpdatesKey) ?? true,
      'promotions': prefs.getBool(_promoKey) ?? false,
    };
  }

  static Future<void> save({required bool orderUpdates, required bool returnUpdates, required bool promotions}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orderUpdatesKey, orderUpdates);
    await prefs.setBool(_returnUpdatesKey, returnUpdates);
    await prefs.setBool(_promoKey, promotions);
  }
}
