import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/owner/pg/pg_models.dart';
import 'package:pg_platform_mobile/owner/pg/pg_repository.dart';
import 'package:pg_platform_mobile/owner/student/owner_customers_screen.dart';
import 'package:pg_platform_mobile/owner/student/student_models.dart';

void main() {
  testWidgets('summarizes customers across owned properties', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: OwnerCustomersScreen(
        pgRepository: _PortfolioPgRepository(),
        loadStudents: _loadStudents,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 active customers'), findsOneWidget);
    expect(
        find.text('3 customer records across your properties'), findsOneWidget);
    expect(find.text('1 direct payment needs review'), findsOneWidget);
    expect(find.text('Lake View PG'), findsOneWidget);
    expect(find.text('Metro Homes'), findsOneWidget);
  });

  testWidgets('searches by customer name and keeps the matching property',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: OwnerCustomersScreen(
        pgRepository: _PortfolioPgRepository(),
        loadStudents: _loadStudents,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Asha');
    await tester.pump();

    expect(find.text('Lake View PG'), findsOneWidget);
    expect(find.text('Metro Homes'), findsNothing);
  });
}

Future<List<Student>> _loadStudents(String pgId) async {
  if (pgId == 'pg-1') {
    return [
      _student(id: 'student-1', pgId: pgId, name: 'Asha Rao'),
      _student(
        id: 'student-2',
        pgId: pgId,
        name: 'Meera Shah',
        status: StudentStatus.movedOut,
      ),
    ];
  }
  return [
    _student(
      id: 'student-3',
      pgId: pgId,
      name: 'Ravi Kumar',
      bedLabel: null,
      bookingStatus: 'DIRECT_PAYMENT_REVIEW',
    ),
  ];
}

Student _student({
  required String id,
  required String pgId,
  required String name,
  StudentStatus status = StudentStatus.active,
  String? bedLabel = 'Bed 1',
  String? bookingStatus,
}) {
  return Student(
    id: id,
    pgId: pgId,
    bedLabel: bedLabel,
    roomNumber: bedLabel == null ? null : '101',
    bookingStatus: bookingStatus,
    fullName: name,
    phone: '9876543210',
    dateOfJoining: DateTime(2026, 1, 1),
    status: status,
  );
}

class _PortfolioPgRepository implements PgDataSource {
  @override
  Future<List<Pg>> list() async => [
        Pg(
          id: 'pg-1',
          name: 'Lake View PG',
          address: 'Madhapur',
          city: 'Hyderabad',
          genderPreference: GenderPreference.female,
          status: PgStatus.active,
        ),
        Pg(
          id: 'pg-2',
          name: 'Metro Homes',
          address: 'Indiranagar',
          city: 'Bengaluru',
          genderPreference: GenderPreference.coEd,
          status: PgStatus.active,
        ),
      ];

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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String pgId) => throw UnimplementedError();

  @override
  Future<Pg> update(Pg pg) => throw UnimplementedError();
}
