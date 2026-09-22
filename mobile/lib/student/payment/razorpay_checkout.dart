import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_models.dart';
import 'payment_repository.dart';

class RazorpayCheckout {
  /// Razorpay's Android activity normally always reports back, but it can be
  /// killed by the OS while it is in the foreground (low memory, the user
  /// swiping the task away, an external-wallet hand-off that never returns).
  /// No event then ever arrives, and an unbounded wait leaves the caller's
  /// pay button spinning for the rest of the session. Capture is confirmed
  /// server-side by the Razorpay webhook regardless, so time out and say so.
  static const _checkoutTimeout = Duration(minutes: 15);

  final PaymentRepository _repository;

  RazorpayCheckout(this._repository);

  Future<void> pay(PaymentOrder order, {required String description}) async {
    final razorpay = Razorpay();
    final completer = Completer<PaymentSuccessResponse>();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      if (!completer.isCompleted) completer.complete(response);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      if (!completer.isCompleted) completer.completeError(Exception(response.message ?? 'Payment failed'));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    try {
      razorpay.open({
        'key': order.razorpayKeyId,
        'order_id': order.razorpayOrderId,
        'amount': (order.amount * 100).round(),
        'currency': order.currency,
        'name': 'Hi PG',
        'description': description,
        'retry': {'enabled': true, 'max_count': 2},
        'theme': {'color': '#171923'},
      });
      final result = await completer.future.timeout(
        _checkoutTimeout,
        onTimeout: () => throw Exception(
            'The payment screen did not report back. If money left your '
            'account, the payment is still verified automatically -- check '
            'this booking again in a few minutes before paying twice.'),
      );
      if (result.paymentId == null || result.signature == null) {
        throw Exception('Razorpay did not return payment verification details');
      }
      await _repository.verify(order, result.paymentId!, result.signature!);
    } finally {
      razorpay.clear();
    }
  }
}
