import '../../shared/api_client.dart';
import 'pg_models.dart';

abstract interface class PgDataSource {
  Future<List<Pg>> list();

  Future<Pg> create({
    required String name,
    required String address,
    required String city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? description,
    required GenderPreference genderPreference,
  });

  Future<Pg> update(Pg pg);

  Future<void> delete(String pgId);
}

class PgRepository implements PgDataSource {
  final ApiClient _client = ApiClient.instance;

  @override
  Future<List<Pg>> list() async {
    final response = await _client.get<List<dynamic>>('/owner/pgs');
    return response.data!
        .map((e) => Pg.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Pg> create({
    required String name,
    required String address,
    required String city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    String? description,
    required GenderPreference genderPreference,
  }) async {
    final response =
        await _client.post<Map<String, dynamic>>('/owner/pgs', data: {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'genderPreference': genderPreference.apiValue,
    });
    return Pg.fromJson(response.data!);
  }

  @override
  Future<Pg> update(Pg pg) async {
    final response =
        await _client.put<Map<String, dynamic>>('/owner/pgs/${pg.id}', data: {
      'name': pg.name,
      'address': pg.address,
      'city': pg.city,
      'state': pg.state,
      'pincode': pg.pincode,
      'latitude': pg.latitude,
      'longitude': pg.longitude,
      'description': pg.description,
      'genderPreference': pg.genderPreference.apiValue,
      'status': pg.status.apiValue,
    });
    return Pg.fromJson(response.data!);
  }

  @override
  Future<void> delete(String pgId) => _client.delete<void>('/owner/pgs/$pgId');
}
