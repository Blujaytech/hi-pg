import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_models.dart';
import 'payment_repository.dart';

class RazorpayCheckout {
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
      final result = await completer.future;
      if (result.paymentId == null || result.signature == null) {
        throw Exception('Razorpay did not return payment verification details');
      }
      await _repository.verify(order, result.paymentId!, result.signature!);
    } finally {
      razorpay.clear();
    }
  }
}
