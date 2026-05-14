import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
  }

  Map<String, String> _headers({Map<String, String>? extra}) => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        ...?extra,
      };

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint')
        .replace(queryParameters: queryParams);
    return _requestWithAutoRefresh(
        () => http.get(uri, headers: _headers()).timeout(const Duration(seconds: 15)));
  }

  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    return _requestWithAutoRefresh(() => http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: _headers(extra: headers),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20)));
  }

  Future<Map<String, dynamic>> put(String endpoint,
      {Map<String, dynamic>? body}) async {
    return _requestWithAutoRefresh(() => http.put(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15)));
  }


  Future<bool> refreshAccessToken() async => _tryRefreshToken();

  Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['data']?['accessToken'];
      final newRefreshToken = data['data']?['refreshToken'];
      if (accessToken == null) return false;

      await setToken(accessToken.toString());
      if (newRefreshToken != null) {
        await prefs.setString('refresh_token', newRefreshToken.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _requestWithAutoRefresh(
      Future<http.Response> Function() requestFn) async {
    http.Response response;
    try {
      response = await requestFn();
    } catch (e) {
      // Network error — rethrow as-is, don't treat as auth failure
      rethrow;
    }
    if (response.statusCode != 401) return _handleResponse(response);

    // Token expired — try refresh
    final refreshed = await _tryRefreshToken();
    if (!refreshed) return _handleResponse(response);

    // Retry with new token
    final retryResponse = await requestFn();
    return _handleResponse(retryResponse);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Server returned an invalid response', response.statusCode);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      // Extract the most specific error message available
      final message = data['message']
          ?? (data['errors'] as List?)?.map((e) => e['msg'] ?? e['message'] ?? e.toString()).join(', ')
          ?? 'Something went wrong';
      throw ApiException(message.toString(), response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
