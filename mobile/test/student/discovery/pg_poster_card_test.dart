import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_models.dart';
import 'package:pg_platform_mobile/student/discovery/pg_poster_card.dart';

void main() {
  testWidgets('poster card exposes one complete actionable announcement',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 240,
          height: 300,
          child: PgPosterCard(pg: _verifiedPg, onTap: () => taps++),
        ),
      ),
    );

    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Sunrise Co-Living')),
    );
    expect(semantics.label, contains('Sunrise Co-Living'));
    expect(semantics.label, contains('verified property'));
    expect(semantics.label, contains('3 beds available'));
    expect(semantics.hint, 'View property details');
    expect(semantics.flagsCollection.isButton, isTrue);

    await tester.tap(find.byType(PgPosterCard));
    expect(taps, 1);
  });

  testWidgets('horizontal card stays stable at narrow width and larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: PgHorizontalCard(pg: _verifiedPg, onTap: () {}),
        ),
      ),
    );

    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Sunrise Co-Living')),
    );
    expect(semantics.label, contains('Sunrise Co-Living'));
    expect(semantics.label, contains('₹8,500/month'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading poster has a concise progress announcement',
      (tester) async {
    await tester.pumpWidget(
      _testApp(const SizedBox(
        width: 220,
        height: 280,
        child: PgPosterSkeleton(),
      )),
    );

    expect(find.bySemanticsLabel('Loading property'), findsOneWidget);
  });
}

Widget _testApp(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

final _verifiedPg = PgSearchResult(
  id: 'pg-accessible',
  name: 'Sunrise Co-Living',
  city: 'Hyderabad',
  address: 'Ameerpet',
  description: 'A real test property.',
  genderPreference: GenderPreference.coEd,
  latitude: 17.4375,
  longitude: 78.4483,
  availableBeds: 3,
  minRentPerBed: 8500,
  maxRentPerBed: 11000,
  offersMonthly: true,
  offersDayWise: false,
  stayTypeConfigured: true,
  verified: true,
  verificationStatus: 'VERIFIED',
);
