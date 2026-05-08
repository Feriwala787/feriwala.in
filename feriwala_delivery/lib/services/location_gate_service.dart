import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Blocks app usage until GPS is enabled AND location permission is granted.
/// Call [ensureLocationReady] at startup and on app resume.
class LocationGateService {
  LocationGateService._();
  static final LocationGateService instance = LocationGateService._();

  /// Returns true only when GPS is on AND permission is granted (always).
  Future<bool> isReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Shows a blocking dialog loop until GPS is on AND permission granted.
  /// Must be called with a valid [BuildContext] (after MaterialApp is built).
  Future<void> ensureLocationReady(BuildContext context) async {
    while (true) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showBlockingDialog(
          context,
          title: 'Turn On Location',
          message: 'Feriwala Delivery needs your device GPS to be ON at all times to track deliveries and receive tasks.\n\nPlease enable Location in your phone settings.',
          actionLabel: 'Open Location Settings',
          onAction: () async => await Geolocator.openLocationSettings(),
        );
        continue;
      }

      final status = await Permission.locationAlways.status;
      if (status.isGranted) return;

      if (status.isPermanentlyDenied) {
        await _showBlockingDialog(
          context,
          title: 'Location Permission Required',
          message: 'Feriwala Delivery requires "Allow all the time" location access to track your position during deliveries.\n\nPlease go to App Settings → Permissions → Location → Allow all the time.',
          actionLabel: 'Open App Settings',
          onAction: () async => await openAppSettings(),
        );
        continue;
      }

      // Not yet requested or denied — request it
      final result = await Permission.locationAlways.request();
      if (result.isGranted) return;
      // If denied, loop back to show dialog
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white),
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
