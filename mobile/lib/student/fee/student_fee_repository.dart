import '../../owner/fee/fee_models.dart';
import '../../shared/api_client.dart';

/// Self-service: a logged-in student viewing their own fees. Reuses the
/// same `Fee`/`Payment` models as the owner side (../../owner/fee/fee_models.dart)
/// since the backend returns the identical FeeResponse shape either way --
/// only the endpoint (and its authorization path) differs. See
/// StudentFeeController and docs/api.md.
class StudentFeeRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Fee>> listMine() async {
    final response = await _client.get<List<dynamic>>('/student/fees');
    return response.data!.map((e) => Fee.fromJson(e as Map<String, dynamic>)).toList();
  }
}
