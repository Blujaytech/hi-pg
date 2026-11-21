import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/auth_models.dart';
import 'package:pg_platform_mobile/auth/auth_state.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/shared/account/account_screen.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_models.dart';
import 'package:pg_platform_mobile/student/profile/customer_profile_repository.dart';
import 'package:provider/provider.dart';

class _FakeProfileRepository extends CustomerProfileRepository {
  @override
  Future<CustomerProfile> getMine() async => const CustomerProfile(
        id: 'student-1',
        fullName: 'Nazeer Basha Shaik',
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
  testWidgets('branded student account page fits a compact phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthState()
      ..role = UserRole.student
      ..fullName = 'Nazeer Basha Shaik';

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AccountScreen(
            profileRepository: _FakeProfileRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('account-profile-card')), findsOneWidget);
    expect(find.text('YOUR HI PG ACCOUNT'), findsOneWidget);
    expect(find.text('Hi PG resident'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('account-scroll')),
      const Offset(0, -1300),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Find Your PG. Feel at Home.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
