import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopAuthProvider extends ChangeNotifier {
  final ShopApiService _api = ShopApiService();
  Map<String, dynamic>? _user;
  int? _shopId;
  bool _isLoading = false;
  bool _isAuthenticated = false;

  Map<String, dynamic>? get user => _user;
  int? get shopId => _shopId;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> init() async {
    await _api.init();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('shop_access_token');
    if (token != null) {
      try {
        final res = await _api.get('/auth/profile');
        _user = res['data'];
        _shopId = _user?['shopId'];
        if (_user?['role'] == 'shop_admin') {
          _isAuthenticated = true;
        } else {
          await _api.clearToken();
        }
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
      final res = await _api.post('/auth/login', body: {'credential': email, 'password': password});
      _user = res['data']['user'];
      if (_user!['role'] != 'shop_admin') throw Exception('Shop admin access only');
      _shopId = _user?['shopId'];
      await _api.setToken(res['data']['accessToken']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shop_refresh_token', res['data']['refreshToken']);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    _shopId = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
