import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class RequiredPermissionsService {
  Future<void> requestStartupPermissions() async {
    await _requestPermission(
      Permission.locationWhenInUse,
      feature: 'live order tracking and nearby shop discovery',
    );

    await _requestPermission(
      Permission.notification,
      feature: 'order status notifications',
    );
  }

  Future<void> _requestPermission(Permission permission, {required String feature}) async {
    final status = await permission.status;
    if (status.isGranted) return;

    final result = await permission.request();
    if (result.isGranted) return;

    debugPrint('[Permissions] $permission denied. $feature may be limited.');
  }
}
