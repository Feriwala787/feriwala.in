import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_storage_service.dart';

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
    final token = await TokenStorageService.instance.readAccessToken();
    if (token != null) {
      try {
        final res = await _api.get('/auth/profile');
        _user = res['data'];
        if (_user?['role'] == 'delivery_agent') {
          _isAuthenticated = true;
          // Restore online status from profile
          try {
            final profileRes = await _api.get('/delivery/my-profile');
            _isOnline = profileRes['data']?['isOnline'] == true;
          } catch (_) {}
        } else {
          await _api.clearToken();
        }
      } catch (e) {
        // Only clear tokens on auth errors, not network/server errors
        final msg = e.toString();
        if (msg.contains('Invalid') || msg.contains('expired') || msg.contains('401') || msg.contains('403')) {
          await _api.clearToken();
        } else {
          // Keep tokens — transient error, stay logged in
          _isAuthenticated = true;
        }
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
      await TokenStorageService.instance.writeRefreshToken(res['data']['refreshToken']);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleOnline() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.put('/delivery/online');
      _isOnline = res['data']?['isOnline'] == true;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
