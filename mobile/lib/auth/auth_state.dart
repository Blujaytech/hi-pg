import 'package:flutter/foundation.dart';

import '../core/secure_storage.dart';
import '../shared/api_client.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'google_student_sign_in.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide auth state (who's logged in, as what role). Registered once at
/// the root (see main.dart) via ChangeNotifierProvider; screens read it with
/// context.watch/read<AuthState>() rather than each holding their own copy.
class AuthState extends ChangeNotifier {
  AuthState() {
    // The shared client clears the session when a refresh token is rejected;
    // without this hook the router would keep the user on signed-in screens
    // that can no longer load anything.
    ApiClient.instance.onSessionExpired = _onSessionExpired;
  }

  final AuthRepository _repository = AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  UserRole? role;
  String? fullName;
  String? userId;
  String? _refreshToken;

  Future<void> bootstrap() async {
    try {
      final token = await SecureStorage.instance.accessToken;
      final roleStr = await SecureStorage.instance.role;
      if (token != null && roleStr != null) {
        role = roleFromString(roleStr);
        fullName = await SecureStorage.instance.fullName;
        userId = await SecureStorage.instance.userId;
        _refreshToken = await SecureStorage.instance.refreshToken;
        status = AuthStatus.authenticated;
      } else {
        status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      // An unreadable keystore (e.g. restored from another device's backup)
      // must not strand the app on the launch screen, which waits for this
      // status. Treat it as signed out; the next login overwrites storage.
      role = null;
      fullName = null;
      userId = null;
      _refreshToken = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _persist(AuthSession session) async {
    await SecureStorage.instance.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      role: session.role == UserRole.owner ? 'OWNER' : 'STUDENT',
      fullName: session.fullName,
      userId: session.userId,
    );
    role = session.role;
    fullName = session.fullName;
    userId = session.userId;
    _refreshToken = session.refreshToken;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> ownerSignup(
      {required String fullName,
      required String email,
      required String password,
      String? phone}) async {
    final session = await _repository.ownerSignup(
        fullName: fullName, email: email, password: password, phone: phone);
    await _persist(session);
  }

  Future<void> ownerLogin(
      {required String email, required String password}) async {
    final session =
        await _repository.ownerLogin(email: email, password: password);
    await _persist(session);
  }

  Future<void> requestStudentOtp({required String phone}) =>
      _repository.requestStudentOtp(phone: phone);

  Future<void> verifyStudentOtp(
      {required String phone, required String code, String? fullName}) async {
    final session = await _repository.verifyStudentOtp(
        phone: phone, code: code, fullName: fullName);
    await _persist(session);
  }

  Future<void> googleStudentLogin() async {
    final idToken = await GoogleStudentSignIn.instance.authenticate();
    final session = await _repository.googleStudentLogin(idToken: idToken);
    if (session.role != UserRole.student) {
      throw const GoogleStudentSignInFailure(
          'Google sign-in did not create a customer session.');
    }
    await _persist(session);
  }

  /// The stored session is already gone by the time this runs -- only the
  /// in-memory copy has to catch up so the router redirects to sign-in.
  Future<void> _onSessionExpired() async {
    if (status == AuthStatus.unauthenticated) return;
    _clearSession();
  }

  void _clearSession() {
    role = null;
    fullName = null;
    userId = null;
    _refreshToken = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    // ApiClient rotates the refresh token on every silent refresh, so the
    // copy captured at sign-in can be stale -- read the live one back so the
    // server-side revoke actually revokes something.
    final refreshToken =
        await SecureStorage.instance.refreshToken ?? _refreshToken;
    if (refreshToken != null) {
      try {
        await _repository.logout(refreshToken: refreshToken);
      } catch (_) {
        // best-effort server-side revoke; local session is cleared regardless
      }
    }
    await SecureStorage.instance.clear();
    _clearSession();
  }
}
