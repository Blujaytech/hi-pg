import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_models.dart';
import 'auth/auth_state.dart';
import 'auth/owner_login_screen.dart';
import 'auth/owner_signup_screen.dart';
import 'auth/role_select_screen.dart';
import 'auth/student_otp_screen.dart';
import 'owner/complaint/complaint_list_screen.dart';
import 'owner/dashboard/dashboard_screen.dart';
import 'owner/expense/expense_list_screen.dart';
import 'owner/fee/fee_list_screen.dart';
import 'owner/receipt/receipt_list_screen.dart';
import 'owner/report/report_screen.dart';
import 'owner/floor/floor_list_screen.dart';
import 'owner/floor/floor_models.dart';
import 'owner/pg/pg_list_screen.dart';
import 'owner/pg/pg_models.dart';
import 'owner/room/room_list_screen.dart';
import 'owner/student/student_list_screen.dart';
import 'student/discovery/pg_details_screen.dart';
import 'student/booking/my_bookings_screen.dart';
import 'student/fee/my_fees_screen.dart';
import 'student/discovery/pg_search_screen.dart';
import 'student/student_home_screen.dart';

/// Route gating: an unauthenticated user can only reach the auth routes; an
/// authenticated Owner/Student is bounced to their home if they land on an
/// auth route or the other role's routes. See technical plan §3 ("two app
/// modes gated by role after login").
GoRouter buildRouter(AuthState authState) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    redirect: (context, state) {
      final loggedIn = authState.status == AuthStatus.authenticated;
      final loggingIn = state.matchedLocation == '/' ||
          state.matchedLocation.startsWith('/owner/login') ||
          state.matchedLocation.startsWith('/owner/signup') ||
          state.matchedLocation.startsWith('/student/login');

      if (!loggedIn) {
        return loggingIn ? null : '/';
      }

      if (loggedIn && loggingIn) {
        return authState.role == UserRole.owner ? '/owner' : '/student';
      }

      final isOwnerRoute = state.matchedLocation.startsWith('/owner');
      final isStudentRoute = state.matchedLocation.startsWith('/student');
      if (authState.role == UserRole.owner && isStudentRoute) return '/owner';
      if (authState.role == UserRole.student && isOwnerRoute) return '/student';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const RoleSelectScreen()),
      GoRoute(path: '/owner/login', builder: (context, state) => const OwnerLoginScreen()),
      GoRoute(path: '/owner/signup', builder: (context, state) => const OwnerSignupScreen()),
      GoRoute(path: '/student/login', builder: (context, state) => const StudentOtpScreen()),
      GoRoute(path: '/owner', builder: (context, state) => const PgListScreen()),
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
      GoRoute(path: '/owner/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/owner/reports', builder: (context, state) => const ReportScreen()),
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
      GoRoute(path: '/student', builder: (context, state) => const StudentHomeScreen()),
      GoRoute(path: '/student/search', builder: (context, state) => const PgSearchScreen()),
      GoRoute(
        path: '/student/pgs/:pgId',
        builder: (context, state) => PgDetailsScreen(pgId: state.pathParameters['pgId']!),
      ),
      GoRoute(path: '/student/bookings', builder: (context, state) => const MyBookingsScreen()),
      GoRoute(path: '/student/fees', builder: (context, state) => const MyFeesScreen()),
    ],
  );
}
