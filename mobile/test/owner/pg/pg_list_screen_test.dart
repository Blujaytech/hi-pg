import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/auth/auth_state.dart';
import 'package:pg_platform_mobile/owner/pg/pg_list_screen.dart';
import 'package:pg_platform_mobile/owner/pg/pg_models.dart';
import 'package:pg_platform_mobile/owner/pg/pg_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('property actions do not overflow on a phone-width screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authState = AuthState()..fullName = 'Nazeer';
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: authState,
        child: MaterialApp(
          home: PgListScreen(repository: _SinglePgRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a newly created PG visible when reconciliation is stale',
      (tester) async {
    final repository = _StaleAfterCreatePgRepository();
    final authState = AuthState()..fullName = 'Nazeer';

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthState>.value(
        value: authState,
        child: MaterialApp(
          home: PgListScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add your first property'), findsOneWidget);
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Haven PG');
    await tester.enterText(fields.at(1), '12 Market Road');
    await tester.enterText(fields.at(2), 'Hyderabad');
    await tester.tap(find.text('Create property'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(find.text('Test Haven PG'), findsOneWidget);
    expect(find.text('1 property'), findsOneWidget);
  });
}

class _SinglePgRepository extends _StaleAfterCreatePgRepository {
  @override
  Future<List<Pg>> list() async => [
        Pg(
          id: 'phone-width-pg',
          name: 'Long Property Name',
          address: '123 Long Market Road',
          city: 'Hyderabad',
          genderPreference: GenderPreference.coEd,
          status: PgStatus.active,
        ),
      ];
}

class _StaleAfterCreatePgRepository implements PgDataSource {
  int createCalls = 0;

  @override
  Future<List<Pg>> list() async => const [];

  @override
  Future<Pg> create({
    required String name,
    required String address,
    required String city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? description,
    required GenderPreference genderPreference,
  }) async {
    createCalls++;
    return Pg(
      id: 'pg-created-by-server',
      name: name,
      address: address,
      city: city,
      genderPreference: genderPreference,
      status: PgStatus.active,
    );
  }

  @override
  Future<void> delete(String pgId) async {}

  @override
  Future<Pg> update(Pg pg) async => pg;
}
