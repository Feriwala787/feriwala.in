import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  TokenStorageService._();
  static final TokenStorageService instance = TokenStorageService._();

  static const _accessTokenKey = 'delivery_access_token';
  static const _refreshTokenKey = 'delivery_refresh_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String?> readAccessToken() => _secureStorage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _secureStorage.read(key: _refreshTokenKey);

  Future<void> writeAccessToken(String token) => _secureStorage.write(key: _accessTokenKey, value: token);
  Future<void> writeRefreshToken(String token) => _secureStorage.write(key: _refreshTokenKey, value: token);

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
