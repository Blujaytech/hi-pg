import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/owner/room/room_list_screen.dart';
import 'package:pg_platform_mobile/owner/room/room_models.dart';

/// The create-room dialog used to parse every number with
/// `tryParse(...) ?? <default>`, so an owner who left a field blank silently
/// created a bookable room priced at Rs 0 (and beds to go with it).
void main() {
  String? validate({
    String roomNumber = '101',
    String sharing = '2',
    String rent = '6500',
    String dayRate = '',
    String deposit = '0',
    String notice = '15',
    RoomBookingMode bookingMode = RoomBookingMode.monthly,
  }) =>
      validateRoomForm(
        roomNumber: roomNumber,
        sharing: sharing,
        rent: rent,
        dayRate: dayRate,
        deposit: deposit,
        notice: notice,
        bookingMode: bookingMode,
      );

  test('a fully filled monthly room passes', () {
    expect(validate(), isNull);
    expect(validate(roomNumber: '  G-1 ', deposit: '5000'), isNull);
  });

  test('a blank or zero rent is refused instead of becoming Rs 0', () {
    expect(validate(rent: ''), 'Enter the monthly rent per bed.');
    expect(validate(rent: '   '), 'Enter the monthly rent per bed.');
    expect(validate(rent: '0'), 'Enter the monthly rent per bed.');
    expect(validate(rent: 'abc'), 'Enter the monthly rent per bed.');
    expect(validate(rent: '-500'), 'Enter the monthly rent per bed.');
  });

  test('a blank room number is refused before the request is sent', () {
    expect(validate(roomNumber: ''), 'Enter a room number.');
    expect(validate(roomNumber: '   '), 'Enter a room number.');
  });

  test('the bed count must be a sane whole number', () {
    expect(validate(sharing: ''), isNotNull);
    expect(validate(sharing: '0'), isNotNull);
    expect(validate(sharing: '2.5'), isNotNull);
    expect(validate(sharing: '51'), 'A room cannot have more than 50 beds.');
    expect(validate(sharing: '50'), isNull);
  });

  test('a day-wise capable room needs a day rate', () {
    expect(validate(bookingMode: RoomBookingMode.dayWise, dayRate: ''),
        'Enter the day-wise rate per bed for this booking mode.');
    expect(validate(bookingMode: RoomBookingMode.dayWise, dayRate: '0'),
        isNotNull);
    expect(
        validate(bookingMode: RoomBookingMode.dayWise, dayRate: '800'), isNull);
    // ...but a monthly-only room does not.
    expect(validate(bookingMode: RoomBookingMode.monthly, dayRate: ''), isNull);
  });

  test('deposit and notice period reject junk rather than defaulting', () {
    expect(validate(deposit: ''), isNotNull);
    expect(validate(deposit: '-1'), isNotNull);
    expect(validate(notice: ''), isNotNull);
    expect(validate(notice: '-5'), isNotNull);
    expect(validate(deposit: '0', notice: '0'), isNull);
  });
}
