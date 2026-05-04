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
    // Placeholder for stronger runtime checks.
    return true;
  }
}
