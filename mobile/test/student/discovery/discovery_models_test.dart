import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/discovery/discovery_models.dart';

void main() {
  Map<String, dynamic> detailsJson({bool? directPaymentAvailable}) => {
        'id': 'pg-1',
        'name': 'Test PG',
        'address': '1 Test Road',
        'city': 'Hyderabad',
        'genderPreference': 'CO_ED',
        'totalBeds': 1,
        'availableBeds': 1,
        if (directPaymentAvailable != null)
          'directPaymentAvailable': directPaymentAvailable,
        'floors': <dynamic>[],
      };

  test('direct owner payment defaults to unavailable for older APIs', () {
    expect(PgDetails.fromJson(detailsJson()).directPaymentAvailable, isFalse);
  });

  test('direct owner payment is exposed only when the API enables it', () {
    expect(
      PgDetails.fromJson(detailsJson(directPaymentAvailable: true))
          .directPaymentAvailable,
      isTrue,
    );
  });
}
