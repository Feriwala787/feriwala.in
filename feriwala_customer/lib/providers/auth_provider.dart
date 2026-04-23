import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> init() async {
    await _api.init();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      try {
        final res = await _api.get('/auth/profile');
        _user = res['data'];
        _isAuthenticated = true;
      } catch (e) {
        await _api.clearToken();
      }
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.post('/auth/login', body: {
        'credential': email,
        'password': password,
      });
      _user = res['data']['user'];
      await _api.setToken(res['data']['accessToken']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', res['data']['refreshToken']);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String name, String email, String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.post('/auth/register', body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': 'customer',
      });
      _user = res['data']['user'];
      await _api.setToken(res['data']['accessToken']);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _api.clearToken();
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
