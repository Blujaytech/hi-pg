import '../../shared/api_client.dart';
import 'discovery_models.dart';

/// Talks to the unauthenticated `/public/pgs` endpoints (technical plan §6
/// Phase 9). These don't require a logged-in student -- the Student app
/// just happens to be where a logged-in student reaches them from.
class DiscoveryRepository {
  final ApiClient _client = ApiClient.instance;

  Future<PagedResult<PgSearchResult>> search({
    String? city,
    GenderPreference? genderPreference,
    double? minRent,
    double? maxRent,
    int page = 0,
  }) async {
    final query = <String, dynamic>{'page': page, 'size': 12};
    if (city != null && city.trim().isNotEmpty) query['city'] = city.trim();
    if (genderPreference != null) query['genderPreference'] = genderPreference.apiValue;
    if (minRent != null) query['minRent'] = minRent;
    if (maxRent != null) query['maxRent'] = maxRent;

    final response = await _client.get<Map<String, dynamic>>('/public/pgs', queryParameters: query);
    final data = response.data!;
    return PagedResult<PgSearchResult>(
      content: (data['content'] as List<dynamic>).map((e) => PgSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
      page: data['page'] as int,
      totalPages: data['totalPages'] as int,
      totalElements: data['totalElements'] as int,
    );
  }

  Future<PgDetails> getDetails(String pgId) async {
    final response = await _client.get<Map<String, dynamic>>('/public/pgs/$pgId');
    return PgDetails.fromJson(response.data!);
  }
}
