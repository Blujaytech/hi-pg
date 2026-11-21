import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/main.dart';

void main() {
  testWidgets('plays the launch animation then shows the two role choices',
      (WidgetTester tester) async {
    // No stored session: the launch screen should hand off to the welcome
    // screen. Without a mock the keystore read never completes in a test.
    FlutterSecureStorage.setMockInitialValues({});
    // MainActivity reports the Android system splash as already gone.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('hipg/launch'),
      (_) async => null,
    );

    await tester.pumpWidget(const PgPlatformApp());
    await tester.pump();

    expect(find.byKey(const Key('launch-animation')), findsOneWidget);
    expect(find.byKey(const Key('launch-room-background')), findsOneWidget);
    final launchImage = tester.widget<Image>(
      find.byKey(const Key('launch-room-background')),
    );
    expect(
      launchImage.image,
      const AssetImage('assets/branding/hi_pg_splash_room.png'),
    );
    expect(launchImage.fit, BoxFit.cover);
    expect(find.byKey(const Key('launch-logo')), findsOneWidget);
    expect(find.byKey(const Key('launch-headline')), findsOneWidget);
    expect(find.byKey(const Key('launch-home-underline')), findsOneWidget);
    expect(find.byKey(const Key('launch-feature-location')), findsOneWidget);
    expect(find.byKey(const Key('launch-feature-bed')), findsOneWidget);
    expect(find.byKey(const Key('launch-feature-shield')), findsOneWidget);
    expect(find.byKey(const Key('launch-top-wave')), findsOneWidget);
    expect(find.byKey(const Key('launch-bottom-wave')), findsOneWidget);
    expect(find.byKey(const Key('owner-entry-button')), findsNothing);

    // The animation runs 4s, then hands off once the session is read.
    await tester.pump(const Duration(milliseconds: 4100));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('launch-animation')), findsNothing);
    expect(find.byKey(const Key('owner-entry-button')), findsOneWidget);
    expect(find.byKey(const Key('student-entry-button')), findsOneWidget);
    expect(find.text("I'm a PG owner"), findsOneWidget);
    expect(find.text('Search for a stay'), findsOneWidget);

    await tester.tap(find.byKey(const Key('student-entry-button')));
    await tester.pumpAndSettle();

    expect(find.text("What's your number?"), findsOneWidget);
    expect(find.text('Search for a stay'), findsNothing);
  });

  testWidgets('uses the reduced-motion launch frame before navigation',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('hipg/launch'),
      (_) async => null,
    );

    await tester.pumpWidget(const PgPlatformApp());
    await tester.pump();

    expect(find.byKey(const Key('launch-animation')), findsOneWidget);
    expect(find.byKey(const Key('launch-room-background')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('launch-animation')), findsNothing);
    expect(find.byKey(const Key('student-entry-button')), findsOneWidget);
  });

  testWidgets('fits the layered splash on a compact portrait screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    FlutterSecureStorage.setMockInitialValues({});
    final nativeHandoff = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('hipg/launch'),
      (_) => nativeHandoff.future,
    );

    await tester.pumpWidget(const PgPlatformApp());
    await tester.pump();

    expect(find.byKey(const Key('launch-animation')), findsOneWidget);
    expect(find.byKey(const Key('launch-headline')), findsOneWidget);
    expect(tester.takeException(), isNull);

    nativeHandoff.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
