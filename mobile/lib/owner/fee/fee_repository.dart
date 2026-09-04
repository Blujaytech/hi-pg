import '../../shared/api_client.dart';
import 'fee_models.dart';

class FeeRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Fee>> listForStudent(String studentId) async {
    final response = await _client.get<List<dynamic>>('/owner/students/$studentId/fees');
    return response.data!.map((e) => Fee.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Fee> create({
    required String studentId,
    required int periodMonth,
    required int periodYear,
    required double amount,
    required DateTime dueDate,
    String? notes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/students/$studentId/fees', data: {
      'periodMonth': periodMonth,
      'periodYear': periodYear,
      'amount': amount,
      'dueDate': dueDate.toIso8601String().substring(0, 10),
      'notes': notes,
    });
    return Fee.fromJson(response.data!);
  }

  Future<Fee> recordPayment({
    required String feeId,
    required double amountPaid,
    required DateTime paidOn,
    required PaymentMethod method,
    String? reference,
    String? note,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/fees/$feeId/payments', data: {
      'amountPaid': amountPaid,
      'paidOn': paidOn.toIso8601String().substring(0, 10),
      'method': method.apiValue,
      'reference': reference,
      'note': note,
    });
    return Fee.fromJson(response.data!);
  }
}
