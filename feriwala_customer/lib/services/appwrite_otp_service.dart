import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// SMS OTP service that routes through our backend.
/// Backend uses Appwrite server API key to send/verify OTP.
class AppwriteOtpService {
  AppwriteOtpService._();
  static final AppwriteOtpService instance = AppwriteOtpService._();

  String? _userId;
  String? get lastUserId => _userId;

  /// Send OTP to phone number via our backend.
  /// [phone] must be in E.164 format e.g. +919876543210
  Future<bool> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _userId = data['data']?['userId'];
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify OTP code via our backend.
  Future<bool> verifyOtp(String otp) async {
    if (_userId == null) return false;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId, 'otp': otp}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
