import '../../shared/api_client.dart';
import 'discovery_models.dart';

/// Talks to the unauthenticated `/public/pgs` endpoints (technical plan §6
/// Phase 9). These don't require a signed-in customer -- guests browse them
/// from `/explore`.
class DiscoveryRepository {
  final ApiClient _client = ApiClient.instance;

  /// [query] is free text (area, PG name, city or pincode) matched word by
  /// word on the server.
  Future<PagedResult<PgSearchResult>> search({
    String? query,
    GenderPreference? genderPreference,
    double? minRent,
    double? maxRent,
    int page = 0,
  }) async {
    // Large pages give the screen's instant local filtering and sorting
    // enough to work with (the server caps size at 50).
    final params = <String, dynamic>{'page': page, 'size': 30};
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();
    if (genderPreference != null) params['genderPreference'] = genderPreference.apiValue;
    if (minRent != null) params['minRent'] = minRent;
    if (maxRent != null) params['maxRent'] = maxRent;

    final response = await _client.get<Map<String, dynamic>>('/public/pgs', queryParameters: params);
    final data = response.data!;
    return PagedResult<PgSearchResult>(
      content: (data['content'] as List<dynamic>).map((e) => PgSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
      page: data['page'] as int,
      totalPages: data['totalPages'] as int,
      totalElements: data['totalElements'] as int,
    );
  }

  Future<PgDetails> getDetails(String pgId, {String? bookingType, DateTime? checkIn, DateTime? checkOut}) async {
    final params = <String, dynamic>{};
    if (bookingType != null) params['bookingType'] = bookingType;
    if (checkIn != null) params['checkIn'] = checkIn.toIso8601String().substring(0, 10);
    if (checkOut != null) params['checkOut'] = checkOut.toIso8601String().substring(0, 10);
    final response = await _client.get<Map<String, dynamic>>('/public/pgs/$pgId', queryParameters: params);
    return PgDetails.fromJson(response.data!);
  }
}
