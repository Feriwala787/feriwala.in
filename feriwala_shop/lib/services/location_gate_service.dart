import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Blocks app usage until GPS is enabled AND location permission is granted.
class LocationGateService {
  LocationGateService._();
  static final LocationGateService instance = LocationGateService._();

  Future<bool> isReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  Future<void> ensureLocationReady(BuildContext context) async {
    while (true) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showBlockingDialog(
          context,
          title: 'Turn On Location',
          message: 'Feriwala Shop needs your device GPS to assign nearby delivery agents and manage dispatch.\n\nPlease enable Location in your phone settings.',
          actionLabel: 'Open Location Settings',
          onAction: () async => await Geolocator.openLocationSettings(),
        );
        continue;
      }

      final status = await Permission.locationWhenInUse.status;
      if (status.isGranted) return;

      if (status.isPermanentlyDenied) {
        await _showBlockingDialog(
          context,
          title: 'Location Permission Required',
          message: 'Feriwala Shop needs location access to find nearby delivery agents.\n\nPlease go to App Settings → Permissions → Location → Allow while using app.',
          actionLabel: 'Open App Settings',
          onAction: () async => await openAppSettings(),
        );
        continue;
      }

      final result = await Permission.locationWhenInUse.request();
      if (result.isGranted) return;
    }
  }
}

Future<void> _showBlockingDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Future<void> Function() onAction,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(children: [
          const Icon(Icons.location_off, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ]),
        content: Text(message),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A2E), foregroundColor: Colors.white),
            onPressed: () async {
              await onAction();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );
}
