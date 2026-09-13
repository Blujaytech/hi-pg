import 'package:google_sign_in/google_sign_in.dart';

import '../core/env.dart';

class GoogleStudentSignInCanceled implements Exception {
  const GoogleStudentSignInCanceled();
}

class GoogleStudentSignInFailure implements Exception {
  final String message;

  const GoogleStudentSignInFailure(this.message);

  @override
  String toString() => message;
}

/// Obtains a Google ID token for the backend. The app never trusts profile
/// fields from this SDK; the Spring API verifies the token and reads them.
class GoogleStudentSignIn {
  GoogleStudentSignIn._();

  static final instance = GoogleStudentSignIn._();

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() async {
    if (Env.googleOAuthWebClientId.isEmpty) {
      throw const GoogleStudentSignInFailure(
          'Google sign-in is not configured in this app build.');
    }

    try {
      await (_initialization ??= _signIn.initialize(
        serverClientId: Env.googleOAuthWebClientId,
      ));
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  /// Forgets the account chosen last time, so the next [authenticate] shows
  /// Google's account picker instead of reusing it.
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _signIn.signOut();
    } catch (_) {
      // Nothing to forget; the picker will still appear.
    }
  }

  Future<String> authenticate() async {
    try {
      await _ensureInitialized();
      if (!_signIn.supportsAuthenticate()) {
        throw const GoogleStudentSignInFailure(
            'Google sign-in is not supported on this device.');
      }

      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleStudentSignInFailure(
            'Google did not return a secure identity token. Please try again.');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleStudentSignInCanceled();
      }
      throw GoogleStudentSignInFailure(
          error.description ?? 'Google sign-in could not be completed.');
    }
  }
}
