import 'dart:math';

import '../../shared/api_client.dart';
import '../../shared/direct_payment/direct_payment_models.dart';

class DirectPaymentRepository {
  final ApiClient _client = ApiClient.instance;

  Future<DirectPaymentDetails> details(String bookingId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/student/bookings/$bookingId/direct-payment-details',
    );
    return DirectPaymentDetails.fromJson(response.data!);
  }

  Future<DirectPaymentDetails> selectDirectPayment(String bookingId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/bookings/$bookingId/direct-payment-details',
    );
    return DirectPaymentDetails.fromJson(response.data!);
  }

  Future<DirectPaymentRequest> currentRequest(String bookingId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/student/bookings/$bookingId/direct-payment-request',
    );
    return DirectPaymentRequest.fromJson(response.data!);
  }

  Future<DirectPaymentRequest> informOwner({
    required String bookingId,
    required String transactionReference,
    required String idempotencyKey,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/bookings/$bookingId/direct-payment-requests',
      data: {
        'idempotencyKey': idempotencyKey,
        'transactionReference': transactionReference.trim(),
        'paymentConfirmed': true,
      },
    );
    return DirectPaymentRequest.fromJson(response.data!);
  }

  static String newIdempotencyKey() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
}
