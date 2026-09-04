import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/role_select_screen.dart';

void main() {
  testWidgets('RoleSelectScreen shows both entry points', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleSelectScreen()));

    expect(find.text("I'm a PG Owner"), findsOneWidget);
    expect(find.text("I'm a Student"), findsOneWidget);
  });
}
