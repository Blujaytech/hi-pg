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

  test('verification and booking flags are read defensively', () {
    final old = PgDetails.fromJson(detailsJson());
    expect(old.verified, isFalse);
    expect(old.verificationStatus, 'UNVERIFIED');
    expect(old.bookingEnabled, isFalse);

    final verified = PgDetails.fromJson({
      ...detailsJson(),
      'verified': true,
      'verificationStatus': 'VERIFIED',
      'bookingEnabled': true,
    });
    expect(verified.verified, isTrue);
    expect(verified.verificationStatus, 'VERIFIED');
    expect(verified.bookingEnabled, isTrue);
  });

  test('legacy cover photos with no id do not break PG details', () {
    final details = PgDetails.fromJson({
      ...detailsJson(),
      'photos': [
        {
          'id': null,
          'url': 'https://example.com/cover.jpg',
          'cover': true,
          'displayOrder': 0,
        },
      ],
    });

    expect(details.photos, hasLength(1));
    expect(details.photos.single.id, 'https://example.com/cover.jpg');
    expect(details.photos.single.cover, isTrue);
  });

  Map<String, dynamic> roomJson({List<dynamic>? beds}) => {
        'roomId': 'room-1',
        'roomNumber': '101',
        'roomType': 'NON_AC',
        'sharingCount': 3,
        'rentPerBed': 7000,
        'availableBeds': 1,
        'availableBedOptions': [
          {'id': 'b3', 'label': 'Bed 3', 'bookingMode': 'MONTHLY'},
        ],
        if (beds != null) 'beds': beds,
      };

  test('a room lists every bed, taken ones included, from the API', () {
    final room = RoomAvailability.fromJson(roomJson(beds: [
      {'id': 'b10', 'label': 'Bed 10', 'available': false},
      {'id': 'b3', 'label': 'Bed 3', 'available': true},
      {'id': 'b1', 'label': 'Bed 1', 'available': false},
    ]));
    expect(room.beds.map((b) => b.label), ['Bed 1', 'Bed 3', 'Bed 10']);
    expect(room.beds.map((b) => b.available), [false, true, false]);
    expect(room.beds[1].option?.id, 'b3');
  });

  test('older APIs without beds still show the taken beds, inferred', () {
    final room = RoomAvailability.fromJson(roomJson());
    expect(room.beds.map((b) => b.label), ['Bed 1', 'Bed 2', 'Bed 3']);
    expect(room.beds.map((b) => b.available), [false, false, true]);
  });

  test('search results read stay types, and treat them as unknown when absent',
      () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
          'id': 'pg-1',
          'name': 'Test PG',
          'city': 'Hyderabad',
          'address': 'Ameerpet',
          'genderPreference': 'MALE',
          'availableBeds': 2,
          ...extra,
        };
    final both = PgSearchResult.fromJson(json(
        {'offersMonthly': true, 'offersDayWise': true, 'minDayWiseRate': 450}));
    expect(both.offersMonthly, isTrue);
    expect(both.offersDayWise, isTrue);
    expect(both.minDayWiseRate, 450);
    final old = PgSearchResult.fromJson(json({}));
    expect(old.offersMonthly, isNull);
    expect(old.offersDayWise, isNull);
  });
}
