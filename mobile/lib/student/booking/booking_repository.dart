import '../../shared/api_client.dart';
import 'booking_models.dart';

/// Phase 11 -- the authenticated counterpart to discovery: a logged-in
/// Student user books a specific bed. See docs/decisions.md ADR-0017 for
/// the backend's concurrency guarantee (at most one CONFIRMED booking per
/// bed, enforced with a Postgres row lock, not just a client-side check).
class BookingRepository {
  final ApiClient _client = ApiClient.instance;

  Future<Booking> book({required String bedId, required DateTime moveInDate}) async {
    final response = await _client.post<Map<String, dynamic>>('/student/bookings', data: {
      'bedId': bedId,
      'moveInDate': moveInDate.toIso8601String().substring(0, 10),
    });
    return Booking.fromJson(response.data!);
  }

  Future<List<Booking>> listMine() async {
    final response = await _client.get<List<dynamic>>('/student/bookings');
    return response.data!.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Booking> cancel(String bookingId, {String? reason}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/bookings/$bookingId/cancel${reason != null ? '?reason=${Uri.encodeQueryComponent(reason)}' : ''}',
    );
    return Booking.fromJson(response.data!);
  }
}
