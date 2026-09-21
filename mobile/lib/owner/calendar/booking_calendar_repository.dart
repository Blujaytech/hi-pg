import '../../shared/api_client.dart';
import 'booking_calendar_models.dart';

class BookingCalendarRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<BookingCalendarEntry>> list(String roomId, DateTime from, DateTime to) async {
    final response = await _client.get<List<dynamic>>('/owner/rooms/$roomId/calendar', queryParameters: {
      'from': from.toIso8601String().substring(0, 10),
      'to': to.toIso8601String().substring(0, 10),
    });
    return response.data!.map((entry) => BookingCalendarEntry.fromJson(entry as Map<String, dynamic>)).toList();
  }
}
