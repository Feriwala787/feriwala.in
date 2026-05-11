import 'dart:convert';
import 'package:http/http.dart' as http;

/// Appwrite SMS OTP service for phone verification.
/// Uses Appwrite Phone auth to send and verify OTP codes.
class AppwriteOtpService {
  AppwriteOtpService._();
  static final AppwriteOtpService instance = AppwriteOtpService._();

  // Appwrite project config — replace with your actual values
  static const String _endpoint = 'https://cloud.appwrite.io/v1';
  static const String _projectId = '6839e88b001e3fa498c0';

  String? _userId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': _projectId,
      };

  /// Send OTP to phone number. Returns true if sent successfully.
  /// [phone] must be in E.164 format e.g. +919876543210
  Future<bool> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$_endpoint/account/tokens/phone'),
        headers: _headers,
        body: jsonEncode({
          'userId': 'unique()',
          'phone': phone,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _userId = data['userId'] ?? data['\$id'];
        return true;
      }

      // If user already exists in Appwrite, try creating session directly
      if (response.statusCode == 409) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _userId = data['userId'] ?? data['message']?.toString().split(':').last.trim();
        // Retry with existing userId
        final retryResponse = await http.post(
          Uri.parse('$_endpoint/account/tokens/phone'),
          headers: _headers,
          body: jsonEncode({
            'userId': _userId,
            'phone': phone,
          }),
        );
        if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
          final retryData = jsonDecode(retryResponse.body) as Map<String, dynamic>;
          _userId = retryData['userId'] ?? retryData['\$id'];
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify OTP code. Returns true if verification successful.
  Future<bool> verifyOtp(String otp) async {
    if (_userId == null) return false;
    try {
      final response = await http.put(
        Uri.parse('$_endpoint/account/sessions/phone'),
        headers: _headers,
        body: jsonEncode({
          'userId': _userId,
          'secret': otp,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
