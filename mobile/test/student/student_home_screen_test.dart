import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/auth_state.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_models.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_repository.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_models.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_repository.dart';
import 'package:pg_platform_mobile/student/student_home_screen.dart';
import 'package:provider/provider.dart';

class _FakeDiscoveryRepository extends DiscoveryRepository {
  @override
  Future<PagedResult<PgSearchResult>> search({
    String? query,
    String? city,
    GenderPreference? genderPreference,
    double? minRent,
    double? maxRent,
    int page = 0,
  }) async =>
      PagedResult(
        content: const [],
        page: 0,
        totalPages: 0,
        totalElements: 0,
      );
}

class _FakeProfileRepository extends CustomerProfileRepository {
  @override
  Future<CustomerProfile> getMine() async => const CustomerProfile(
        id: 'student-1',
        fullName: 'Chaitanya',
        occupation: 'Student',
        phone: '9999999999',
        phoneVerified: true,
        permanentAddress: null,
        identityType: null,
        identityLast4: null,
        termsAcceptedVersion: null,
        privacyAcceptedVersion: null,
        aadhaarConsentVersion: null,
        updatedAt: null,
      );
}

void main() {
  testWidgets('premium student home fits a compact phone', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'discovery_location_kind': 'dismissed',
    });
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthState(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: StudentHomeScreen(
            discovery: _FakeDiscoveryRepository(),
            profileRepository: _FakeProfileRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byKey(const Key('student-home-hero')), findsOneWidget);
    expect(find.byKey(const Key('student-home-search')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Everything for your stay'), findsOneWidget);
    expect(find.text('Find Your PG. Feel at Home.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('student-home-trust-strip')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('student-home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('student-home-trust-strip')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('student-home-scroll')),
      const Offset(0, -1500),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('student-home-brand-story')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
