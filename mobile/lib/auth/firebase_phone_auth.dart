import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Phone verification is performed by Firebase on the device. The resulting
/// Firebase ID token is then exchanged for the application's normal backend
/// session; Firebase never decides owner/student/admin authorization.
class FirebasePhoneAuth {
  FirebasePhoneAuth._();

  static final FirebasePhoneAuth instance = FirebasePhoneAuth._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  PhoneAuthCredential? _automaticCredential;

  Future<void> sendCode({
    required String phone,
    bool forceResend = false,
  }) async {
    final completer = Completer<void>();
    _verificationId = null;
    _automaticCredential = null;

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizeIndianPhone(phone),
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResend ? _resendToken : null,
      verificationCompleted: (credential) {
        // Android may resolve the SMS automatically. Keep the credential so
        // the normal Verify button can finish the same backend exchange.
        _automaticCredential = credential;
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(FirebasePhoneAuthFailure.from(error));
        }
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId ??= verificationId;
      },
    );

    return completer.future;
  }

  Future<String> verifyCode(String code) async {
    final credential = _automaticCredential ??
        (_verificationId == null
            ? null
            : PhoneAuthProvider.credential(
                verificationId: _verificationId!,
                smsCode: code,
              ));
    if (credential == null) {
      throw const FirebasePhoneAuthFailure(
          'Request a new verification code and try again.');
    }

    try {
      final result = await _auth.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw const FirebasePhoneAuthFailure(
            'Phone verification completed but no secure token was returned.');
      }
      return idToken;
    } on FirebaseAuthException catch (error) {
      throw FirebasePhoneAuthFailure.from(error);
    }
  }

  Future<void> signOut() => _auth.signOut();
}

String normalizeIndianPhone(String input) {
  var value = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
  if (value.startsWith('+')) return value;
  value = value.replaceAll(RegExp(r'\D'), '');
  if (value.length == 10) return '+91$value';
  if (value.length == 12 && value.startsWith('91')) return '+$value';
  return '+$value';
}

class FirebasePhoneAuthFailure implements Exception {
  const FirebasePhoneAuthFailure(this.message);

  factory FirebasePhoneAuthFailure.from(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-phone-number' => 'Enter a valid 10-digit mobile number.',
      'invalid-verification-code' => 'The verification code is incorrect.',
      'session-expired' => 'This code has expired. Request a new code.',
      'too-many-requests' =>
        'Too many attempts. Please wait before requesting another code.',
      'quota-exceeded' =>
        'The SMS limit has been reached. Please try again later.',
      'network-request-failed' =>
        'Could not contact Firebase. Check your internet connection.',
      _ => error.message ?? 'Phone verification could not be completed.',
    };
    return FirebasePhoneAuthFailure(message);
  }

  final String message;

  @override
  String toString() => message;
}
