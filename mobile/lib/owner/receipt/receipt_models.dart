import '../fee/fee_models.dart';

class Receipt {
  final String id;
  final String receiptNumber;
  final String studentId;
  final String studentName;
  final String pgName;
  final int feePeriodMonth;
  final int feePeriodYear;
  final double amount;
  final DateTime paidOn;
  final PaymentMethod method;

  Receipt({
    required this.id,
    required this.receiptNumber,
    required this.studentId,
    required this.studentName,
    required this.pgName,
    required this.feePeriodMonth,
    required this.feePeriodYear,
    required this.amount,
    required this.paidOn,
    required this.method,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: json['id'] as String,
        receiptNumber: json['receiptNumber'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        pgName: json['pgName'] as String,
        feePeriodMonth: json['feePeriodMonth'] as int,
        feePeriodYear: json['feePeriodYear'] as int,
        amount: (json['amount'] as num).toDouble(),
        paidOn: DateTime.parse(json['paidOn'] as String),
        method: PaymentMethod.values.firstWhere((m) => m.apiValue == json['method'], orElse: () => PaymentMethod.other),
      );
}
