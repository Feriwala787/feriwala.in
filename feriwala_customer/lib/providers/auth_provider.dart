import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  Timer? _sessionRefreshTimer;
  final SocketService _socketService = SocketService();

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> _clearSession() async {
    _sessionRefreshTimer?.cancel();
    _socketService.dispose();
    await _api.clearToken();
    _user = null;
    _isAuthenticated = false;
  }

  void _connectSocketIfPossible() {
    final customerId = _user?['_id']?.toString();
    if (customerId == null || customerId.isEmpty) return;
    _socketService.connect();
    _socketService.joinCustomerRoom(customerId);
  }

  void _startSessionRefresh() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (_isAuthenticated) {
        final refreshed = await _api.refreshAccessToken();
        if (!refreshed) {
          await _clearSession();
          notifyListeners();
        }
      }
    });
  }

  Future<void> init() async {
    await _api.init();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      try {
        final res = await _api.get('/auth/profile');
        _user = res['data'];
        _isAuthenticated = true;
        _startSessionRefresh();
        _connectSocketIfPossible();
      } catch (e) {
        if (e is ApiException && e.statusCode == 401) {
          await _clearSession();
        }
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
      _startSessionRefresh();
      _connectSocketIfPossible();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', res['data']['refreshToken']);
      _isAuthenticated = true;
      _startSessionRefresh();
      _connectSocketIfPossible();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _clearSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }
}
