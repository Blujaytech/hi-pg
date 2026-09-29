import '../../shared/api_client.dart';

class PgClaimSuggestion {
  final String pgId;
  final String name;
  final String address;
  final String city;
  final String claimStatus;
  final String verificationStatus;
  final int interestCount;
  final bool alreadyClaimedByYou;

  const PgClaimSuggestion({
    required this.pgId,
    required this.name,
    required this.address,
    required this.city,
    required this.claimStatus,
    required this.verificationStatus,
    required this.interestCount,
    required this.alreadyClaimedByYou,
  });

  factory PgClaimSuggestion.fromJson(Map<String, dynamic> json) =>
      PgClaimSuggestion(
        pgId: json['pgId'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        city: json['city'] as String,
        claimStatus: json['claimStatus'] as String,
        verificationStatus: json['verificationStatus'] as String,
        interestCount: json['interestCount'] as int? ?? 0,
        alreadyClaimedByYou: json['alreadyClaimedByYou'] as bool? ?? false,
      );
}

class PgClaimRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<PgClaimSuggestion>> suggestions() async {
    final response =
        await _client.get<List<dynamic>>('/owner/claims/suggestions');
    return response.data!
        .map((item) => PgClaimSuggestion.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PgClaimSuggestion> claim(String pgId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/owner/claims/$pgId',
    );
    return PgClaimSuggestion.fromJson(response.data!);
  }
}
