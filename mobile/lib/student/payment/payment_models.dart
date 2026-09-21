class PaymentOrder {
  final String id;
  final String? feeId;
  final String? bookingId;
  final double amount;
  final String currency;
  final String status;
  final String razorpayOrderId;
  final String razorpayKeyId;

  PaymentOrder({required this.id, required this.feeId, required this.bookingId,
    required this.amount, required this.currency, required this.status,
    required this.razorpayOrderId, required this.razorpayKeyId});

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
    id: json['id'] as String,
    feeId: json['feeId'] as String?,
    bookingId: json['bookingId'] as String?,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'INR',
    status: json['status'] as String,
    razorpayOrderId: json['razorpayOrderId'] as String,
    razorpayKeyId: json['razorpayKeyId'] as String,
  );
}

class AutoPayMandate {
  final String id;
  final double amount;
  final int dueDay;
  final String status;
  final DateTime? nextChargeDate;
  final String? subscriptionId;
  final String? authorizationUrl;

  AutoPayMandate({required this.id, required this.amount, required this.dueDay,
    required this.status, required this.nextChargeDate, required this.subscriptionId,
    required this.authorizationUrl});

  factory AutoPayMandate.fromJson(Map<String, dynamic> json) => AutoPayMandate(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    dueDay: json['dueDay'] as int,
    status: json['status'] as String,
    nextChargeDate: json['nextChargeDate'] == null ? null : DateTime.parse(json['nextChargeDate'] as String),
    subscriptionId: json['razorpaySubscriptionId'] as String?,
    authorizationUrl: json['authorizationUrl'] as String?,
  );
}
