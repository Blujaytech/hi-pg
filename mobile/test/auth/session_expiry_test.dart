import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/app_router.dart';
import 'package:pg_platform_mobile/auth/auth_models.dart';
import 'package:pg_platform_mobile/auth/auth_state.dart';
import 'package:pg_platform_mobile/shared/api_client.dart';

/// Regression cover for the session-expiry hole: ApiClient clears the stored
/// tokens when a refresh token is rejected, but nothing told AuthState, so the
/// router kept the user on signed-in screens where every request 401s and the
/// only way back to sign-in was killing the app.
void main() {
  test('a rejected refresh token hands the app back to the sign-in flow',
      () async {
    final auth = AuthState();
    var notified = 0;
    auth.addListener(() => notified++);

    // The router keeps signed-in routes reachable until this fires.
    expect(
      routeRedirect(
          status: AuthStatus.authenticated,
          role: UserRole.student,
          location: '/student/bookings'),
      isNull,
    );

    final expired = ApiClient.instance.onSessionExpired;
    expect(expired, isNotNull,
        reason: 'AuthState must register for ApiClient session expiry');
    await expired!();

    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.role, isNull);
    expect(auth.userId, isNull);
    expect(notified, greaterThan(0),
        reason: 'GoRouter refreshes off this notification');

    // ...and now the same route is gated again.
    expect(
      routeRedirect(
          status: auth.status, role: auth.role, location: '/student/bookings'),
      '/',
    );
  });
}
