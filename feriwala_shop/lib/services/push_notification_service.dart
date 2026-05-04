import 'api_service.dart';

class PushNotificationService {
  Future<void> initForShopUser({required int shopId, required String role}) async {
    // Push notifications via backend polling — Firebase SDK not required
    // Token registration is handled server-side when user logs in
    try {
      await ShopApiService().post('/notifications/register-token', body: {
        'shopId': shopId,
        'role': role,
        'token': 'polling',
      });
    } catch (_) {}
  }
}
