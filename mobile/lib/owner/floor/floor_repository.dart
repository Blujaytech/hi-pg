import '../../shared/api_client.dart';
import 'floor_models.dart';

class FloorRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Floor>> listForPg(String pgId) async {
    final response = await _client.get<List<dynamic>>('/owner/pgs/$pgId/floors');
    return response.data!.map((e) => Floor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Floor> create({required String pgId, required String name, required int floorNumber}) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/pgs/$pgId/floors', data: {
      'name': name,
      'floorNumber': floorNumber,
    });
    return Floor.fromJson(response.data!);
  }

  Future<void> delete(String floorId) => _client.delete<void>('/owner/floors/$floorId');
}
