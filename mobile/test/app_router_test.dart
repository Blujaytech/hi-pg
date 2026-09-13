import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/app_router.dart';
import 'package:pg_platform_mobile/auth/auth_models.dart';
import 'package:pg_platform_mobile/auth/auth_state.dart';

void main() {
  String? guest(String location) => routeRedirect(
      status: AuthStatus.unauthenticated, role: null, location: location);
  String? customer(String location, {String? from}) => routeRedirect(
      status: AuthStatus.authenticated,
      role: UserRole.student,
      location: location,
      from: from);
  String? owner(String location) => routeRedirect(
      status: AuthStatus.authenticated,
      role: UserRole.owner,
      location: location);

  test('guests can browse PGs without signing in', () {
    expect(guest('/explore'), isNull);
    expect(guest('/explore/pgs/pg-1'), isNull);
  });

  test('guests are sent to the welcome screen for signed-in areas', () {
    expect(guest('/student'), '/');
    expect(guest('/student/bookings'), '/');
    expect(guest('/owner'), '/');
  });

  test('signing in to book returns the customer to the PG they were viewing',
      () {
    expect(customer('/student/login', from: '/explore/pgs/pg-1'),
        '/explore/pgs/pg-1');
    expect(customer('/student/login'), '/student');
  });

  test('only explore pages are accepted as a return target', () {
    expect(customer('/student/login', from: '/owner'), '/student');
    expect(customer('/student/login', from: 'https://example.com'), '/student');
    expect(customer('/student/login', from: '/explorer'), '/student');
  });

  test('each role stays in its own area', () {
    expect(owner('/student/bookings'), '/owner');
    expect(customer('/owner'), '/student');
    expect(customer('/explore/pgs/pg-1'), isNull);
  });
}
