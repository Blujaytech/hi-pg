import '../../shared/api_client.dart';
import 'pg_models.dart';

class PgRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Pg>> list() async {
    final response = await _client.get<List<dynamic>>('/owner/pgs');
    return response.data!.map((e) => Pg.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Pg> create({
    required String name,
    required String address,
    required String city,
    String? state,
    String? pincode,
    String? description,
    required GenderPreference genderPreference,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/pgs', data: {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'description': description,
      'genderPreference': genderPreference.apiValue,
    });
    return Pg.fromJson(response.data!);
  }

  Future<Pg> update(Pg pg) async {
    final response = await _client.put<Map<String, dynamic>>('/owner/pgs/${pg.id}', data: {
      'name': pg.name,
      'address': pg.address,
      'city': pg.city,
      'state': pg.state,
      'pincode': pg.pincode,
      'description': pg.description,
      'genderPreference': pg.genderPreference.apiValue,
      'status': pg.status.apiValue,
    });
    return Pg.fromJson(response.data!);
  }

  Future<void> delete(String pgId) => _client.delete<void>('/owner/pgs/$pgId');
}
