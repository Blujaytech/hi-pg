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

  Future<String> authenticate() => _authenticate(allowNetworkRetry: true);

  Future<String> _authenticate({required bool allowNetworkRetry}) async {
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
      if (allowNetworkRetry && _isTransientNetworkFailure(error)) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return _authenticate(allowNetworkRetry: false);
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const GoogleStudentSignInFailure(
            'Google sign-in is unavailable in this app version. '
            'Please update the app or continue with your mobile number.');
      }
      if (error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleStudentSignInFailure(
            'Google sign-in is unavailable on this device. '
            'Please update Google Play services or continue with your mobile number.');
      }
      if (_isTransientNetworkFailure(error)) {
        throw const GoogleStudentSignInFailure(
            'Google could not connect. Switch between Wi-Fi and mobile data, '
            'then try again.');
      }
      throw GoogleStudentSignInFailure(
          error.description ?? 'Google sign-in could not be completed.');
    }
  }

  bool _isTransientNetworkFailure(GoogleSignInException error) {
    if (error.code == GoogleSignInExceptionCode.interrupted) return true;
    if (error.code != GoogleSignInExceptionCode.unknownError) return false;
    final description = (error.description ?? '').toLowerCase();
    return description.contains('network') ||
        description.contains('connection') ||
        description.contains('temporar') ||
        description.contains('timeout');
  }
}
