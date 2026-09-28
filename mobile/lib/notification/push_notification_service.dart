import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../shared/api_client.dart';

/// Registers this installation with the backend after an app session exists.
/// Notification messages are displayed by Android while the app is in the
/// background; foreground screens continue to receive the existing live SSE
/// event as well, avoiding duplicate banners.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  StreamSubscription<String>? _refreshSubscription;
  String? _registeredToken;

  Future<void> activate() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) await _register(token);

    await _refreshSubscription?.cancel();
    _refreshSubscription = messaging.onTokenRefresh.listen(
      (token) async {
        try {
          await _register(token);
        } catch (_) {
          // Token refresh retries on the next app start. It must never sign
          // the user out or interrupt a booking/payment flow.
        }
      },
    );
  }

  Future<void> deactivate() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    final token = _registeredToken;
    _registeredToken = null;
    if (token == null) return;
    try {
      await ApiClient.instance
          .delete<void>('/me/device-tokens/${Uri.encodeComponent(token)}');
    } catch (_) {
      // Best effort. Registering the same token on the next account safely
      // reassigns it server-side.
    }
  }

  Future<void> _register(String token) async {
    await ApiClient.instance.post<void>(
      '/me/device-tokens',
      data: {'token': token, 'platform': 'ANDROID'},
    );
    _registeredToken = token;
  }
}
