import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class PushNotificationService {
  Future<void> initForShopUser({required int shopId, required String role}) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) {
      await ShopApiService().post('/notifications/register-token', body: {
        'shopId': shopId,
        'role': role,
        'token': token,
      });
    }

    await messaging.subscribeToTopic('shop_$shopId');
    await messaging.subscribeToTopic('role_$role');
  }
}
