import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryApiService {
  static final DeliveryApiService _instance = DeliveryApiService._internal();
  factory DeliveryApiService() => _instance;
  DeliveryApiService._internal();

  static const String baseUrl = 'https://api.feriwala.in/api';
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('delivery_access_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('delivery_access_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('delivery_access_token');
    await prefs.remove('delivery_refresh_token');
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('delivery_refresh_token');
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
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
        await prefs.setString('delivery_refresh_token', newRefreshToken.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _requestWithAutoRefresh(
      Future<http.Response> Function() requestFn) async {
    final response = await requestFn();
    if (response.statusCode != 401) return _handleResponse(response);

    final refreshed = await _tryRefreshToken();
    if (!refreshed) return _handleResponse(response);

    final retryResponse = await requestFn();
    return _handleResponse(retryResponse);
  }

  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    return _requestWithAutoRefresh(() => http.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body}) async {
    return _requestWithAutoRefresh(() => http.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers,
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> put(String endpoint,
      {Map<String, dynamic>? body}) async {
    return _requestWithAutoRefresh(() => http.put(
          Uri.parse('$baseUrl$endpoint'),
          headers: _headers,
          body: jsonEncode(body),
        ));
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw Exception(data['message'] ?? 'Request failed');
  }
}
