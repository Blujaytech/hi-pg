import '../owner/onboarding/owner_kyc_models.dart';
import '../shared/api_client.dart';

class AdminKycRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<OwnerKycSubmission>> listAll() async {
    final response = await _client.get<List<dynamic>>('/admin/kyc');
    return response.data!
        .map(
            (item) => OwnerKycSubmission.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OwnerKycSubmission> review({
    required String submissionId,
    required OwnerKycStatus status,
    required int platformCommissionBps,
    String? razorpayLinkedAccountId,
    String? reviewNote,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/kyc/$submissionId',
      data: {
        'status': status.apiValue,
        'platformCommissionBps': platformCommissionBps,
        if ((razorpayLinkedAccountId ?? '').trim().isNotEmpty)
          'razorpayLinkedAccountId': razorpayLinkedAccountId!.trim(),
        if ((reviewNote ?? '').trim().isNotEmpty)
          'reviewNote': reviewNote!.trim(),
      },
    );
    return OwnerKycSubmission.fromJson(response.data!);
  }

  Future<String> documentUrl(String documentId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/kyc/documents/$documentId/download-url',
    );
    return response.data!['url'] as String;
  }
}
