import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/admin/admin_dashboard_screen.dart';
import 'package:pg_platform_mobile/admin/admin_kyc_repository.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/owner/onboarding/owner_kyc_models.dart';

void main() {
  testWidgets('keeps compact admin navigation and shows KYC queue counts',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Owner verification queue'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Verified (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a navigation rail and switches sections on wide screens',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(find.text('PG listings'));
    await tester.pumpAndSettle();

    expect(find.text('Listings placeholder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app() => MaterialApp(
      theme: AppTheme.light(),
      home: AdminDashboardScreen(
        kycRepository: _KycRepository(),
        listingsPanel: const Center(child: Text('Listings placeholder')),
        supportPanel: const Center(child: Text('Support placeholder')),
      ),
    );

class _KycRepository extends AdminKycRepository {
  @override
  Future<List<OwnerKycSubmission>> listAll() async => [
        _submission('pending', OwnerKycStatus.submitted),
        _submission('verified', OwnerKycStatus.verified),
      ];
}

OwnerKycSubmission _submission(String id, OwnerKycStatus status) =>
    OwnerKycSubmission(
      id: id,
      pgId: 'pg-$id',
      pgName: '${status.apiValue} Stay',
      ownerName: 'Test Owner',
      verifiedPhone: '9000000000',
      legalName: 'Test Owner',
      status: status,
      reviewNote: null,
      submittedAt: DateTime(2026, 10, 23),
      documents: const [],
    );
