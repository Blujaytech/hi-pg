import '../../shared/api_client.dart';
import 'report_models.dart';

/// Owner-wide reports (across every PG the owner has). Per-PG variants exist
/// on the same backend endpoints under `/owner/pgs/{pgId}/reports/...` but
/// aren't wired into the UI yet -- add a per-PG report screen if the
/// owner-wide view isn't granular enough once there are many PGs.
class ReportRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<MonthlyFinancialSummary>> revenue({int months = 6}) async {
    final response = await _client.get<List<dynamic>>('/owner/reports/revenue', queryParameters: {'months': months});
    return response.data!.map((e) => MonthlyFinancialSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<OccupancyReport>> occupancy() async {
    final response = await _client.get<List<dynamic>>('/owner/reports/occupancy');
    return response.data!.map((e) => OccupancyReport.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<OutstandingDue>> outstandingDues() async {
    final response = await _client.get<List<dynamic>>('/owner/reports/outstanding-dues');
    return response.data!.map((e) => OutstandingDue.fromJson(e as Map<String, dynamic>)).toList();
  }
}
