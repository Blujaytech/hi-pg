import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/discovery/property_location.dart';

void main() {
  test('uses the exact Google Maps search query as the destination', () {
    final destination = propertyDestination(
      locationUrl:
          'https://www.google.com/maps/search/?api=1&query=Test+PG%2C+Kondapur%2C+Hyderabad',
      name: 'Ignored PG',
      address: 'Ignored address',
      city: 'Hyderabad',
    );

    expect(destination, 'Test PG, Kondapur, Hyderabad');
    expect(propertyDirectionsUri(destination).queryParameters['destination'],
        destination);
  });

  test('falls back to full property details when no map URL exists', () {
    expect(
      propertyDestination(
        name: 'Test PG',
        address: '1 Test Road',
        city: 'Chennai',
        state: 'Tamil Nadu',
        pincode: '600001',
      ),
      'Test PG, 1 Test Road, Chennai, Tamil Nadu, 600001',
    );
  });
}
