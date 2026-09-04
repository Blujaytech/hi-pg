enum FeeStatus { pending, partiallyPaid, paid }

extension FeeStatusX on FeeStatus {
  String get label => switch (this) {
        FeeStatus.pending => 'Pending',
        FeeStatus.partiallyPaid => 'Partially paid',
        FeeStatus.paid => 'Paid',
      };

  static FeeStatus fromApi(String value) => switch (value) {
        'PARTIALLY_PAID' => FeeStatus.partiallyPaid,
        'PAID' => FeeStatus.paid,
        _ => FeeStatus.pending,
      };
}

enum PaymentMethod { cash, upi, bankTransfer, card, other }

extension PaymentMethodX on PaymentMethod {
  String get apiValue => switch (this) {
        PaymentMethod.cash => 'CASH',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.bankTransfer => 'BANK_TRANSFER',
        PaymentMethod.card => 'CARD',
        PaymentMethod.other => 'OTHER',
      };

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.bankTransfer => 'Bank transfer',
        PaymentMethod.card => 'Card',
        PaymentMethod.other => 'Other',
      };
}

class Payment {
  final String id;
  final double amountPaid;
  final DateTime paidOn;
  final PaymentMethod method;
  final String? reference;

  Payment({required this.id, required this.amountPaid, required this.paidOn, required this.method, this.reference});

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        amountPaid: (json['amountPaid'] as num).toDouble(),
        paidOn: DateTime.parse(json['paidOn'] as String),
        method: PaymentMethod.values.firstWhere((m) => m.apiValue == json['method'], orElse: () => PaymentMethod.other),
        reference: json['reference'] as String?,
      );
}

class Fee {
  final String id;
  final String studentId;
  final String studentName;
  final int periodMonth;
  final int periodYear;
  final double amount;
  final double amountPaid;
  final double balance;
  final DateTime dueDate;
  final FeeStatus status;
  final bool overdue;
  final String? notes;
  final List<Payment> payments;

  Fee({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.periodMonth,
    required this.periodYear,
    required this.amount,
    required this.amountPaid,
    required this.balance,
    required this.dueDate,
    required this.status,
    required this.overdue,
    this.notes,
    required this.payments,
  });

  factory Fee.fromJson(Map<String, dynamic> json) => Fee(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        periodMonth: json['periodMonth'] as int,
        periodYear: json['periodYear'] as int,
        amount: (json['amount'] as num).toDouble(),
        amountPaid: (json['amountPaid'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: FeeStatusX.fromApi(json['status'] as String),
        overdue: json['overdue'] as bool,
        notes: json['notes'] as String?,
        payments: (json['payments'] as List<dynamic>? ?? []).map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
