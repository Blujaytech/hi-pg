import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/role_select_screen.dart';

void main() {
  testWidgets('RoleSelectScreen shows both entry points', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleSelectScreen()));

    // Let the one-shot entrance animation finish.
    await tester.pumpAndSettle();

    expect(find.text("I'm a PG owner"), findsOneWidget);
    expect(find.text('Search for a stay'), findsOneWidget);
  });
}
