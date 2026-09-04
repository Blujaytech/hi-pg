class MonthlyFinancialSummary {
  final int year;
  final int month;
  final double collected;
  final double expenses;
  final double net;

  MonthlyFinancialSummary({
    required this.year,
    required this.month,
    required this.collected,
    required this.expenses,
    required this.net,
  });

  factory MonthlyFinancialSummary.fromJson(Map<String, dynamic> json) => MonthlyFinancialSummary(
        year: json['year'] as int,
        month: json['month'] as int,
        collected: (json['collected'] as num).toDouble(),
        expenses: (json['expenses'] as num).toDouble(),
        net: (json['net'] as num).toDouble(),
      );

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String get label => '${_monthNames[month - 1]} $year';
}

class OccupancyReport {
  final String pgId;
  final String pgName;
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int maintenanceBeds;
  final double occupancyPercentage;

  OccupancyReport({
    required this.pgId,
    required this.pgName,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.maintenanceBeds,
    required this.occupancyPercentage,
  });

  factory OccupancyReport.fromJson(Map<String, dynamic> json) => OccupancyReport(
        pgId: json['pgId'] as String,
        pgName: json['pgName'] as String,
        totalBeds: json['totalBeds'] as int,
        occupiedBeds: json['occupiedBeds'] as int,
        availableBeds: json['availableBeds'] as int,
        maintenanceBeds: json['maintenanceBeds'] as int,
        occupancyPercentage: (json['occupancyPercentage'] as num).toDouble(),
      );
}

class OutstandingDue {
  final String feeId;
  final String studentId;
  final String studentName;
  final String pgId;
  final String pgName;
  final int periodMonth;
  final int periodYear;
  final double amount;
  final double amountPaid;
  final double balance;
  final DateTime dueDate;
  final bool overdue;

  OutstandingDue({
    required this.feeId,
    required this.studentId,
    required this.studentName,
    required this.pgId,
    required this.pgName,
    required this.periodMonth,
    required this.periodYear,
    required this.amount,
    required this.amountPaid,
    required this.balance,
    required this.dueDate,
    required this.overdue,
  });

  factory OutstandingDue.fromJson(Map<String, dynamic> json) => OutstandingDue(
        feeId: json['feeId'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        pgId: json['pgId'] as String,
        pgName: json['pgName'] as String,
        periodMonth: json['periodMonth'] as int,
        periodYear: json['periodYear'] as int,
        amount: (json['amount'] as num).toDouble(),
        amountPaid: (json['amountPaid'] as num).toDouble(),
        balance: (json['balance'] as num).toDouble(),
        dueDate: DateTime.parse(json['dueDate'] as String),
        overdue: json['overdue'] as bool,
      );
}
