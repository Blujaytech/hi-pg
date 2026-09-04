import '../../shared/api_client.dart';
import 'bed_models.dart';

class BedRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Bed>> listForRoom(String roomId) async {
    final response = await _client.get<List<dynamic>>('/owner/rooms/$roomId/beds');
    return response.data!.map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Bed> updateStatus(String bedId, BedStatus status) async {
    final response = await _client.patch<Map<String, dynamic>>('/owner/beds/$bedId/status', data: {
      'status': status.apiValue,
    });
    return Bed.fromJson(response.data!);
  }
}
