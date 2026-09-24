import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin/admin_dashboard_screen.dart';
import 'auth/auth_models.dart';
import 'auth/auth_state.dart';
import 'auth/owner_login_screen.dart';
import 'auth/owner_signup_screen.dart';
import 'auth/role_select_screen.dart';
import 'auth/splash_screen.dart';
import 'auth/student_otp_screen.dart';
import 'owner/complaint/complaint_list_screen.dart';
import 'owner/dashboard/dashboard_screen.dart';
import 'owner/direct_payment/direct_payment_requests_screen.dart';
import 'owner/direct_payment/direct_payment_settings_screen.dart';
import 'owner/expense/expense_list_screen.dart';
import 'owner/fee/fee_list_screen.dart';
import 'owner/floor/floor_list_screen.dart';
import 'owner/floor/floor_models.dart';
import 'owner/onboarding/owner_kyc_screen.dart';
import 'owner/pg/pg_list_screen.dart';
import 'owner/pg/pg_models.dart';
import 'owner/receipt/receipt_list_screen.dart';
import 'owner/report/report_screen.dart';
import 'owner/room/room_list_screen.dart';
import 'owner/calendar/booking_calendar_screen.dart';
import 'owner/room/room_models.dart';
import 'owner/student/student_list_screen.dart';
import 'shared/account/account_screen.dart';
import 'shared/app_shell.dart';
import 'student/booking/my_bookings_screen.dart';
import 'student/booking/booking_models.dart';
import 'student/complaint/my_complaints_screen.dart';
import 'student/discovery/pg_details_screen.dart';
import 'student/discovery/pg_search_screen.dart';
import 'student/fee/my_fees_screen.dart';
import 'student/payment/direct_owner_payment_screen.dart';
import 'student/profile/customer_profile_screen.dart';
import 'student/student_home_screen.dart';

const _ownerTabs = [
  AppTab(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home'),
  AppTab(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Insights'),
  AppTab(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart_rounded,
      label: 'Reports'),
  AppTab(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Account'),
];

const _studentTabs = [
  AppTab(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home'),
  AppTab(
      icon: Icons.search_rounded,
      selectedIcon: Icons.manage_search_rounded,
      label: 'Explore'),
  AppTab(
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available_rounded,
      label: 'Bookings'),
  AppTab(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Account'),
];

/// Cross-fade used wherever the app changes "mode" (splash -> welcome,
/// sign-in -> home) rather than drilling into detail.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

bool _isExplore(String location) =>
    location == '/explore' || location.startsWith('/explore/');

/// Route gating, as a pure function so it can be unit tested.
///
/// Browsing PGs (`/explore/...`) is open to everyone -- a guest is only asked
/// to sign in when they try to book a bed, and [from] brings them back to
/// that PG afterwards. Otherwise an unauthenticated user can only reach the
/// auth routes, and an authenticated Owner/Customer is bounced to their home
/// if they land on an auth route or the other role's routes (technical plan
/// §3, "two app modes gated by role after login"). `/splash` is exempt: it
/// waits for the session to restore and routes itself.
@visibleForTesting
String? routeRedirect({
  required AuthStatus status,
  required UserRole? role,
  required String location,
  String? from,
}) {
  if (location == '/splash' || _isExplore(location)) return null;

  final loggedIn = status == AuthStatus.authenticated;
  final loggingIn = location == '/' ||
      location.startsWith('/owner/login') ||
      location.startsWith('/owner/signup') ||
      location.startsWith('/student/login');

  if (!loggedIn) {
    return loggingIn ? null : '/';
  }

  if (loggingIn) {
    // Only in-app explore pages are accepted as a return target.
    if (from != null && _isExplore(from)) return from;
    return switch (role) {
      UserRole.admin => '/admin',
      UserRole.owner => '/owner',
      _ => '/student',
    };
  }

  final isOwnerRoute = location.startsWith('/owner');
  final isStudentRoute = location.startsWith('/student');
  final isAdminRoute = location.startsWith('/admin');
  if (role == UserRole.owner && isStudentRoute) return '/owner';
  if (role == UserRole.owner && isAdminRoute) return '/owner';
  if (role == UserRole.student && (isOwnerRoute || isAdminRoute)) {
    return '/student';
  }
  if (role == UserRole.admin && isStudentRoute) return '/admin';

  return null;
}

GoRouter buildRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authState,
    redirect: (context, state) => routeRedirect(
      status: authState.status,
      role: authState.role,
      location: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    ),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SplashScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _fadePage(state, const RoleSelectScreen()),
      ),
      GoRoute(
          path: '/owner/login',
          builder: (context, state) => const OwnerLoginScreen()),
      GoRoute(
          path: '/owner/signup',
          builder: (context, state) => const OwnerSignupScreen()),
      GoRoute(
          path: '/student/login',
          builder: (context, state) => StudentOtpScreen(
                returnTo: state.uri.queryParameters['from'] != null &&
                        _isExplore(state.uri.queryParameters['from']!)
                    ? state.uri.queryParameters['from']
                    : null,
              )),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Public PG browsing: no account needed until a bed is booked.
      GoRoute(
        path: '/explore',
        builder: (context, state) => const PgSearchScreen(),
        routes: [
          GoRoute(
            path: 'pgs/:pgId',
            builder: (context, state) =>
                PgDetailsScreen(pgId: state.pathParameters['pgId']!),
          ),
        ],
      ),

      // Owner mode: bottom tabs.
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => _fadePage(
          state,
          AppShell(navigationShell: shell, tabs: _ownerTabs),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/owner',
                builder: (context, state) => const PgListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/owner/dashboard',
                builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/owner/reports',
                builder: (context, state) => const ReportScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/owner/account',
                builder: (context, state) => const AccountScreen()),
          ]),
        ],
      ),
      // Owner detail screens, pushed above the tab bar.
      GoRoute(
        path: '/owner/pgs/:pgId/floors',
        builder: (context, state) => FloorListScreen(
          pgId: state.pathParameters['pgId']!,
          pg: state.extra as Pg?,
        ),
      ),
      GoRoute(
        path: '/owner/floors/:floorId/rooms',
        builder: (context, state) => RoomListScreen(
          floorId: state.pathParameters['floorId']!,
          floor: state.extra as Floor?,
        ),
      ),
      GoRoute(
        path: '/owner/rooms/:roomId/calendar',
        builder: (context, state) => BookingCalendarScreen(
          roomId: state.pathParameters['roomId']!,
          room: state.extra as Room?,
        ),
      ),
      GoRoute(
        path: '/owner/pgs/:pgId/students',
        builder: (context, state) => StudentListScreen(
          pgId: state.pathParameters['pgId']!,
          pg: state.extra as Pg?,
        ),
      ),
      GoRoute(
        path: '/owner/pgs/:pgId/expenses',
        builder: (context, state) => ExpenseListScreen(
          pgId: state.pathParameters['pgId']!,
          pg: state.extra as Pg?,
        ),
      ),
      GoRoute(
        path: '/owner/pgs/:pgId/complaints',
        builder: (context, state) => ComplaintListScreen(
          pgId: state.pathParameters['pgId']!,
          studentName: (state.extra as Pg?)?.name,
        ),
      ),
      GoRoute(
        path: '/owner/students/:studentId/fees',
        builder: (context, state) => FeeListScreen(
          studentId: state.pathParameters['studentId']!,
          studentName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/owner/students/:studentId/complaints',
        builder: (context, state) => ComplaintListScreen(
          studentId: state.pathParameters['studentId']!,
          studentName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/owner/students/:studentId/receipts',
        builder: (context, state) => ReceiptListScreen(
          studentId: state.pathParameters['studentId']!,
          studentName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/owner/payment-requests',
        builder: (context, state) => const DirectPaymentRequestsScreen(),
      ),
      GoRoute(
        path: '/owner/pgs/:pgId/payment-requests',
        builder: (context, state) => DirectPaymentRequestsScreen(
          pgId: state.pathParameters['pgId']!,
          pg: state.extra as Pg?,
        ),
      ),
      GoRoute(
        path: '/owner/pgs/:pgId/direct-payment-settings',
        builder: (context, state) => DirectPaymentSettingsScreen(
          pgId: state.pathParameters['pgId']!,
          pg: state.extra as Pg?,
        ),
      ),
      GoRoute(
        path: '/owner/pgs/:pgId/kyc',
        builder: (context, state) => OwnerKycScreen(
          pgId: state.pathParameters['pgId']!,
          pg: state.extra as Pg?,
        ),
      ),

      // Student mode: bottom tabs.
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => _fadePage(
          state,
          AppShell(navigationShell: shell, tabs: _studentTabs),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/student',
                builder: (context, state) => const StudentHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/student/search',
                builder: (context, state) => const PgSearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/student/bookings',
                builder: (context, state) => const MyBookingsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/student/account',
                builder: (context, state) => const AccountScreen()),
          ]),
        ],
      ),
      // Student detail screens, pushed above the tab bar.
      GoRoute(
        path: '/student/pgs/:pgId',
        builder: (context, state) =>
            PgDetailsScreen(pgId: state.pathParameters['pgId']!),
      ),
      GoRoute(
          path: '/student/fees',
          builder: (context, state) => const MyFeesScreen()),
      GoRoute(
          path: '/student/complaints',
          builder: (context, state) => const MyComplaintsScreen()),
      GoRoute(
        path: '/student/profile',
        builder: (context, state) {
          final requiredFor = state.uri.queryParameters['requiredFor'];
          return CustomerProfileScreen(
            requiredFor: requiredFor == 'MONTHLY'
                ? BookingType.monthly
                : requiredFor == 'DAY_WISE'
                    ? BookingType.dayWise
                    : null,
          );
        },
      ),
      GoRoute(
        path: '/student/bookings/:bookingId/direct-payment',
        builder: (context, state) => DirectOwnerPaymentScreen(
          bookingId: state.pathParameters['bookingId']!,
          selectBeforeLoad: state.uri.queryParameters['select'] == 'true',
        ),
      ),
    ],
  );
}
