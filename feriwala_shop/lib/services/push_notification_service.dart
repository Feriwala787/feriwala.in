// Push notifications via backend polling - no Firebase dependency
import 'api_service.dart';

class PushNotificationService {
  Future<void> initForShopUser({required int shopId, required String role}) async {
    try {
      await ShopApiService().post('/notifications/register-token', body: {
        'shopId': shopId,
        'role': role,
        'token': 'polling',
      });
    } catch (_) {}
  }
}
