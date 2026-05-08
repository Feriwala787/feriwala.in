import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class RequiredPermissionsService {
  Future<void> requestStartupPermissions() async {
    // Location is handled by LocationGateService (blocking gate with GPS check).
    await _requestPermission(
      Permission.notification,
      feature: 'new task alerts and delivery updates',
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
