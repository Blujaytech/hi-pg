import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/owner/dashboard/dashboard_models.dart';
import 'package:pg_platform_mobile/owner/dashboard/dashboard_repository.dart';
import 'package:pg_platform_mobile/owner/dashboard/dashboard_screen.dart';
import 'package:pg_platform_mobile/owner/direct_payment/direct_payment_repository.dart';
import 'package:pg_platform_mobile/shared/direct_payment/direct_payment_models.dart';

void main() {
  testWidgets('premium owner dashboard fits a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          repository: _DashboardRepository(),
          directPaymentRepository: _PaymentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HI PG OWNER'), findsOneWidget);
    expect(find.text('Portfolio pulse'), findsOneWidget);
    expect(find.text('82%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DashboardRepository extends DashboardRepository {
  @override
  Future<DashboardSummary> forOwner() async => DashboardSummary(
        totalPgs: 4,
        totalFloors: 10,
        totalRooms: 30,
        totalBeds: 100,
        occupiedBeds: 82,
        availableBeds: 18,
        maintenanceBeds: 0,
        occupancyPercentage: 82,
        totalActiveStudents: 80,
        totalPendingDues: 18000,
        collectedThisMonth: 420000,
        expensesThisMonth: 96000,
        netThisMonth: 324000,
        openComplaints: 2,
      );
}

class _PaymentRepository extends OwnerDirectPaymentRepository {
  @override
  Future<List<DirectPaymentRequest>> list({
    DirectPaymentRequestStatus status = DirectPaymentRequestStatus.pending,
    String? pgId,
  }) async =>
      const [];
}
