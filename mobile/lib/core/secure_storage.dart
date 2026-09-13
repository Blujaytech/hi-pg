import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper so the rest of the app never touches flutter_secure_storage
/// directly -- swapping storage implementations later touches one file.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _roleKey = 'role';
  static const _fullNameKey = 'full_name';
  static const _userIdKey = 'user_id';

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String fullName,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _roleKey, value: role),
      _storage.write(key: _fullNameKey, value: fullName),
      _storage.write(key: _userIdKey, value: userId),
    ]);
  }

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);
  Future<String?> get role => _storage.read(key: _roleKey);
  Future<String?> get fullName => _storage.read(key: _fullNameKey);
  Future<String?> get userId => _storage.read(key: _userIdKey);

  Future<void> saveRotatedTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _roleKey),
      _storage.delete(key: _fullNameKey),
      _storage.delete(key: _userIdKey),
    ]);
  }
}
