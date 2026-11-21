import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/student_otp_screen.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/shared/brand/hi_pg_brand.dart';

void main() {
  testWidgets('student login stays light and medium-sized on a compact phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const StudentOtpScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HiPgPlainLogo), findsOneWidget);
    expect(find.byType(HiPgAppIcon), findsNothing);
    expect(find.text("What's your number?"), findsOneWidget);

    final sendButton = find.widgetWithText(FilledButton, 'Send code');
    expect(tester.getSize(sendButton).height, lessThanOrEqualTo(50));
    expect(tester.getSize(find.byType(TextFormField)).height,
        lessThanOrEqualTo(62));
    expect(tester.takeException(), isNull);
  });
}
