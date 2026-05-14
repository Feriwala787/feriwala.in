import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopAuthProvider extends ChangeNotifier {
  final ShopApiService _api = ShopApiService();
  Map<String, dynamic>? _user;
  int? _shopId;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _shopLocationNeeded = false;
  final PushNotificationService _pushService = PushNotificationService();

  Map<String, dynamic>? get user => _user;
  int? get shopId => _shopId;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get shopLocationNeeded => _shopLocationNeeded;

  Future<void> _checkShopLocation() async {
    if (_shopId == null) return;
    try {
      final res = await _api.get('/shops/my/shop');
      final shop = res['data'];
      final lat = double.tryParse(shop['latitude']?.toString() ?? '0') ?? 0;
      final lng = double.tryParse(shop['longitude']?.toString() ?? '0') ?? 0;
      _shopLocationNeeded = (lat == 0 && lng == 0);
    } catch (_) {
      _shopLocationNeeded = false;
    }
  }

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
          if (_shopId != null) {
            _pushService.initForShopUser(shopId: _shopId!, role: _user?['role'] ?? 'shop_admin');
            await _checkShopLocation();
          }
        } else {
          await _api.clearToken();
        }
      } catch (e) {
        // Only clear session on definitive auth failure, not network errors
        if (e.toString().contains('401') || e.toString().contains('Invalid token') || e.toString().contains('Token expired')) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            try {
              final res = await _api.get('/auth/profile');
              _user = res['data'];
              _shopId = _user?['shopId'];
              if (_user?['role'] == 'shop_admin') {
                _isAuthenticated = true;
                if (_shopId != null) {
                  _pushService.initForShopUser(shopId: _shopId!, role: _user?['role'] ?? 'shop_admin');
                  await _checkShopLocation();
                }
              } else {
                await _api.clearToken();
              }
            } catch (_) {
              // Keep authenticated — profile will load on next app open
              _isAuthenticated = true;
            }
          } else {
            // Refresh failed but could be network — keep session alive
            _isAuthenticated = true;
          }
        }
        // For network errors, keep tokens — user stays logged in
      }
    }
    notifyListeners();
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('shop_refresh_token');
      if (refreshToken == null) return false;
      // Use the API service's internal refresh
      final res = await _api.post('/auth/refresh', body: {'refreshToken': refreshToken});
      final accessToken = res['data']?['accessToken'];
      final newRefreshToken = res['data']?['refreshToken'];
      if (accessToken == null) return false;
      await _api.setToken(accessToken.toString());
      if (newRefreshToken != null) {
        await prefs.setString('shop_refresh_token', newRefreshToken.toString());
      }
      return true;
    } catch (_) {
      return false;
    }
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
      if (_shopId != null) {
        _pushService.initForShopUser(shopId: _shopId!, role: _user?['role'] ?? 'shop_admin');
        await _checkShopLocation();
      }
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
    _shopLocationNeeded = false;
    notifyListeners();
  }
}
