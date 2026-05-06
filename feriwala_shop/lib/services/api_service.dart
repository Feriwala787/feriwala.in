import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopApiService {
  static final ShopApiService _instance = ShopApiService._internal();
  factory ShopApiService() => _instance;
  ShopApiService._internal();

  static const String baseUrl = 'https://api.feriwala.in/api';
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('shop_access_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_access_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shop_access_token');
    await prefs.remove('shop_refresh_token');
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('shop_refresh_token');
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
        await prefs.setString('shop_refresh_token', newRefreshToken.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _requestWithAutoRefresh(
      Future<http.Response> Function() requestFn) async {
    final response = await _requestWithRetry(requestFn);
    if (response.statusCode != 401) return _handleResponse(response);

    final refreshed = await _tryRefreshToken();
    if (!refreshed) return _handleResponse(response);

    final retryResponse = await _requestWithRetry(requestFn);
    return _handleResponse(retryResponse);
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() requestFn, {
    int maxAttempts = 3,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await requestFn();
        if (response.statusCode >= 500 && attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 250 * (1 << (attempt - 1))));
          continue;
        }
        return response;
      } catch (_) {
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(milliseconds: 250 * (1 << (attempt - 1))));
      }
    }
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

  Future<Map<String, dynamic>> delete(String endpoint) async {
    return _requestWithAutoRefresh(
        () => http.delete(Uri.parse('$baseUrl$endpoint'), headers: _headers));
  }

  Future<Map<String, dynamic>> uploadFiles(
    String endpoint, {
    required List<File> files,
    Map<String, String> fields = const {},
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    fields.forEach((k, v) => request.fields[k] = v);
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      request.files.add(http.MultipartFile.fromBytes('images', bytes, filename: file.path.split('/').last, contentType: MediaType('image', ext == 'png' ? 'png' : 'jpeg')));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    throw Exception(data['message'] ?? 'Request failed');
  }
}
