import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/student/discovery/location_lookup.dart';

void main() {
  test('nearest listed city chooses the expected service city', () {
    expect(nearestListedCity(17.44, 78.39), 'Hyderabad');
    expect(nearestListedCity(12.97, 77.59), 'Bengaluru');
    expect(nearestListedCity(18.52, 73.85), 'Pune');
  });
}
