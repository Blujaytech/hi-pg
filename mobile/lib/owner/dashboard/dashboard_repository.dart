import '../../shared/api_client.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  final ApiClient _client = ApiClient.instance;

  Future<DashboardSummary> forOwner() async {
    final response = await _client.get<Map<String, dynamic>>('/owner/dashboard');
    return DashboardSummary.fromJson(response.data!);
  }

  Future<DashboardSummary> forPg(String pgId) async {
    final response = await _client.get<Map<String, dynamic>>('/owner/pgs/$pgId/dashboard');
    return DashboardSummary.fromJson(response.data!);
  }
}
