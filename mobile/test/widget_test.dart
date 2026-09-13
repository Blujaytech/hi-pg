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
    expect(find.byKey(const Key('owner-entry-button')), findsNothing);

    // The animation runs ~2.8s, then hands off once the session is read.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('launch-animation')), findsNothing);
    expect(find.byKey(const Key('owner-entry-button')), findsOneWidget);
    expect(find.byKey(const Key('student-entry-button')), findsOneWidget);
    expect(find.text("I'm a PG owner"), findsOneWidget);
    expect(find.text('Search for a stay'), findsOneWidget);
  });
}
