import 'package:flutter/foundation.dart';

/// Production security posture gate.
///
/// Extend this service with platform checks (root/jailbreak, debugger attach,
/// certificate-pinning validation state) and block sensitive flows if needed.
class SecurityPostureService {
  SecurityPostureService._();
  static final SecurityPostureService instance = SecurityPostureService._();

  bool get allowSensitiveNetworkCalls {
    // In debug/profile we keep this permissive for developer workflow.
    if (!kReleaseMode) return true;
    const blockOnEmulator = bool.fromEnvironment('SECURITY_BLOCK_EMULATOR', defaultValue: false);
    const pinningHealthy = bool.fromEnvironment('TLS_PINNING_HEALTHY', defaultValue: true);
    if (!pinningHealthy) return false;
    if (blockOnEmulator) {
      // Emulator detection can be implemented per-platform in native layers and
      // passed via dart-define. For now this flag allows policy enforcement.
      return false;
    }
    return true;
  }
}
