import 'dart:math';

import '../../shared/api_client.dart';
import 'payment_models.dart';

class PaymentRepository {
  final ApiClient _client = ApiClient.instance;

  String _idempotencyKey() => '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<PaymentOrder> createBookingOrder(String bookingId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/bookings/$bookingId/payment-orders',
      data: {'idempotencyKey': _idempotencyKey()},
    );
    return PaymentOrder.fromJson(response.data!);
  }

  Future<PaymentOrder> createFeeOrder(String feeId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/fees/$feeId/payment-orders',
      data: {'idempotencyKey': _idempotencyKey()},
    );
    return PaymentOrder.fromJson(response.data!);
  }

  Future<PaymentOrder> verify(PaymentOrder order, String paymentId, String signature) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/payment-orders/${order.id}/verify',
      data: {'razorpayPaymentId': paymentId, 'razorpaySignature': signature},
    );
    return PaymentOrder.fromJson(response.data!);
  }

  Future<AutoPayMandate> enableAutoPay(int dueDay) async {
    final response = await _client.post<Map<String, dynamic>>('/student/autopay', data: {'dueDay': dueDay});
    return AutoPayMandate.fromJson(response.data!);
  }
}
