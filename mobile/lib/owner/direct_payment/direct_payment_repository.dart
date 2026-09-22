import '../../shared/api_client.dart';
import '../../shared/direct_payment/direct_payment_models.dart';

class OwnerDirectPaymentRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<DirectPaymentRequest>> list({
    DirectPaymentRequestStatus status = DirectPaymentRequestStatus.pending,
    String? pgId,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/owner/direct-payment-requests',
      queryParameters: {
        'status': status.apiValue,
        if (pgId != null) 'pgId': pgId,
      },
    );
    return response.data!
        .map((json) =>
            DirectPaymentRequest.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<DirectPaymentRequest> approve({
    required String requestId,
    required double amountReceived,
    String? note,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/owner/direct-payment-requests/$requestId/approve',
      data: {
        'amountReceived': amountReceived,
        'idempotencyKey': 'approve-$requestId',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return DirectPaymentRequest.fromJson(response.data!);
  }

  Future<DirectPaymentRequest> reject({
    required String requestId,
    required String reason,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/owner/direct-payment-requests/$requestId/reject',
      data: {
        'reason': reason.trim(),
        'idempotencyKey': 'reject-$requestId',
      },
    );
    return DirectPaymentRequest.fromJson(response.data!);
  }

  Future<DirectPaymentSettings> getSettings(String pgId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/owner/pgs/$pgId/direct-payment-settings',
    );
    return DirectPaymentSettings.fromJson(response.data!);
  }

  Future<DirectPaymentSettings> saveSettings({
    required String pgId,
    required bool enabled,
    required String beneficiaryName,
    required String upiId,
    required String mobileNumber,
  }) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/owner/pgs/$pgId/direct-payment-settings',
      data: {
        'enabled': enabled,
        'beneficiaryName': beneficiaryName.trim(),
        'upiId': upiId.trim(),
        'mobileNumber': mobileNumber.trim(),
      },
    );
    return DirectPaymentSettings.fromJson(response.data!);
  }
}
