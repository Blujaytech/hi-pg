import 'package:flutter/foundation.dart';

import '../core/secure_storage.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide auth state (who's logged in, as what role). Registered once at
/// the root (see main.dart) via ChangeNotifierProvider; screens read it with
/// context.watch/read<AuthState>() rather than each holding their own copy.
class AuthState extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  UserRole? role;
  String? fullName;
  String? userId;
  String? _refreshToken;

  Future<void> bootstrap() async {
    final token = await SecureStorage.instance.accessToken;
    final roleStr = await SecureStorage.instance.role;
    if (token != null && roleStr != null) {
      role = roleFromString(roleStr);
      status = AuthStatus.authenticated;
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _persist(AuthSession session) async {
    await SecureStorage.instance.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      role: session.role == UserRole.owner ? 'OWNER' : 'STUDENT',
    );
    role = session.role;
    fullName = session.fullName;
    userId = session.userId;
    _refreshToken = session.refreshToken;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> ownerSignup({required String fullName, required String email, required String password, String? phone}) async {
    final session = await _repository.ownerSignup(fullName: fullName, email: email, password: password, phone: phone);
    await _persist(session);
  }

  Future<void> ownerLogin({required String email, required String password}) async {
    final session = await _repository.ownerLogin(email: email, password: password);
    await _persist(session);
  }

  Future<void> requestStudentOtp({required String phone}) => _repository.requestStudentOtp(phone: phone);

  Future<void> verifyStudentOtp({required String phone, required String code, String? fullName}) async {
    final session = await _repository.verifyStudentOtp(phone: phone, code: code, fullName: fullName);
    await _persist(session);
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await _repository.logout(refreshToken: _refreshToken!);
      } catch (_) {
        // best-effort server-side revoke; local session is cleared regardless
      }
    }
    await SecureStorage.instance.clear();
    role = null;
    fullName = null;
    userId = null;
    _refreshToken = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
