import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/discovery/city_picker_sheet.dart';

void main() {
  testWidgets('shows only curated cities and filters them while typing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCityPicker(
                context,
                current: const LocationChoice.allCities(),
              ),
              child: const Text('Open city picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open city picker'));
    await tester.pumpAndSettle();

    expect(find.text('MAJOR CITIES IN INDIA'), findsOneWidget);
    expect(find.text('CITIES ON HI PG'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Hyd');
    await tester.pump();

    expect(find.text('Hyderabad'), findsOneWidget);
    expect(find.text('Bengaluru'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Odisha');
    await tester.pump();

    expect(find.widgetWithText(ListTile, 'Odisha'), findsNothing);
    expect(find.text('No matching city'), findsOneWidget);
  });
}
