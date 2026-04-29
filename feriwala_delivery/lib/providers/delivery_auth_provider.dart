import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryAuthProvider extends ChangeNotifier {
  final DeliveryApiService _api = DeliveryApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isOnline = false;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    await _api.init();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('delivery_access_token');
    if (token != null) {
      try {
        final res = await _api.get('/auth/profile');
        _user = res['data'];
        if (_user?['role'] == 'delivery_agent') {
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
      if (_user!['role'] != 'delivery_agent') throw Exception('Delivery agent access only');
      await _api.setToken(res['data']['accessToken']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('delivery_refresh_token', res['data']['refreshToken']);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleOnline() async {
    try {
      final res = await _api.put('/delivery/online');
      _isOnline = res['data']?['isOnline'] == true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to toggle online: $e');
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    _isAuthenticated = false;
    _isOnline = false;
    notifyListeners();
  }
}
