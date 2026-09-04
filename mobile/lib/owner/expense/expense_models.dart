enum ExpenseCategory { maintenance, utilities, salary, supplies, other }

extension ExpenseCategoryX on ExpenseCategory {
  String get apiValue => switch (this) {
        ExpenseCategory.maintenance => 'MAINTENANCE',
        ExpenseCategory.utilities => 'UTILITIES',
        ExpenseCategory.salary => 'SALARY',
        ExpenseCategory.supplies => 'SUPPLIES',
        ExpenseCategory.other => 'OTHER',
      };

  String get label => switch (this) {
        ExpenseCategory.maintenance => 'Maintenance',
        ExpenseCategory.utilities => 'Utilities',
        ExpenseCategory.salary => 'Salary',
        ExpenseCategory.supplies => 'Supplies',
        ExpenseCategory.other => 'Other',
      };

  static ExpenseCategory fromApi(String value) => ExpenseCategory.values.firstWhere(
        (c) => c.apiValue == value,
        orElse: () => ExpenseCategory.other,
      );
}

class Expense {
  final String id;
  final String pgId;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final DateTime expenseDate;

  Expense({
    required this.id,
    required this.pgId,
    required this.category,
    required this.description,
    required this.amount,
    required this.expenseDate,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        pgId: json['pgId'] as String,
        category: ExpenseCategoryX.fromApi(json['category'] as String),
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        expenseDate: DateTime.parse(json['expenseDate'] as String),
      );
}
