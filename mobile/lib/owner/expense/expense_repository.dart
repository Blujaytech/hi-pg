import '../../shared/api_client.dart';
import 'expense_models.dart';

class ExpenseRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Expense>> listForPg(String pgId) async {
    final response = await _client.get<List<dynamic>>('/owner/pgs/$pgId/expenses');
    return response.data!.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Expense> create({
    required String pgId,
    required ExpenseCategory category,
    required String description,
    required double amount,
    required DateTime expenseDate,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/pgs/$pgId/expenses', data: {
      'category': category.apiValue,
      'description': description,
      'amount': amount,
      'expenseDate': expenseDate.toIso8601String().substring(0, 10),
    });
    return Expense.fromJson(response.data!);
  }

  Future<void> delete(String expenseId) => _client.delete<void>('/owner/expenses/$expenseId');
}
