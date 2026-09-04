import '../../shared/api_client.dart';
import 'complaint_models.dart';

class ComplaintRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Complaint>> listForStudent(String studentId) async {
    final response = await _client.get<List<dynamic>>('/owner/students/$studentId/complaints');
    return response.data!.map((e) => Complaint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Complaint> create({
    required String studentId,
    required ComplaintCategory category,
    required ComplaintPriority priority,
    required String description,
  }) async {
    final response = await _client.post<Map<String, dynamic>>('/owner/students/$studentId/complaints', data: {
      'category': category.apiValue,
      'priority': priority.apiValue,
      'description': description,
    });
    return Complaint.fromJson(response.data!);
  }

  Future<Complaint> updateStatus(String complaintId, ComplaintStatus status, {String? resolutionNotes}) async {
    final response = await _client.patch<Map<String, dynamic>>('/owner/complaints/$complaintId/status', data: {
      'status': status.apiValue,
      'resolutionNotes': resolutionNotes,
    });
    return Complaint.fromJson(response.data!);
  }
}
