import '../../shared/api_client.dart';
import 'receipt_models.dart';

class ReceiptRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Receipt>> listForStudent(String studentId) async {
    final response = await _client.get<List<dynamic>>('/owner/students/$studentId/receipts');
    return response.data!.map((e) => Receipt.fromJson(e as Map<String, dynamic>)).toList();
  }
}
