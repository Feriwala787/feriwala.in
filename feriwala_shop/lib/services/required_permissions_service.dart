import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class RequiredPermissionsService {
  Future<void> requestStartupPermissions() async {
    await _requestPermission(
      Permission.locationWhenInUse,
      feature: 'store discovery and dispatch routing support',
    );

    await _requestPermission(
      Permission.notification,
      feature: 'new order and delivery assignment alerts',
    );
  }

  Future<void> _requestPermission(Permission permission, {required String feature}) async {
    final status = await permission.status;
    if (status.isGranted) return;

    final result = await permission.request();
    if (result.isGranted) return;
    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }

    debugPrint('[Permissions] $permission denied. $feature may be limited.');
  }
}
