import 'payment_models.dart';
import 'payment_repository.dart';

class RazorpayCheckout {
  RazorpayCheckout(PaymentRepository repository);

  Future<void> pay(PaymentOrder order, {required String description}) async {
    throw Exception('Online payments are not available yet.');
  }
}
