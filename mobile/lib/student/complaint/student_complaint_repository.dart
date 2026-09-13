import '../../owner/complaint/complaint_models.dart';
import '../../shared/api_client.dart';

class StudentComplaintRepository {
  final _client = ApiClient.instance;

  Future<List<Complaint>> listMine() async {
    final response = await _client.get<List<dynamic>>('/student/complaints');
    return (response.data ?? const <dynamic>[])
        .map((item) => Complaint.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Complaint> create({
    required ComplaintCategory category,
    required ComplaintPriority priority,
    required String description,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/student/complaints',
      data: {
        'category': category.apiValue,
        'priority': priority.apiValue,
        'description': description,
      },
    );
    return Complaint.fromJson(response.data!);
  }
}
