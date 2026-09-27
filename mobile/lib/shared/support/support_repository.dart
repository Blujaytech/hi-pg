import '../api_client.dart';
import 'support_models.dart';

class SupportRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<SupportTicket>> listMine() async {
    final response = await _client.get<List<dynamic>>('/support/tickets');
    return (response.data ?? const <dynamic>[])
        .map((item) => SupportTicket.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicket> create({
    required SupportCategory category,
    required String subject,
    required String description,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/support/tickets',
      data: {
        'category': category.apiValue,
        'subject': subject.trim(),
        'description': description.trim(),
      },
    );
    return SupportTicket.fromJson(response.data!);
  }
}

class AdminSupportRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<SupportTicket>> listAll() async {
    final response = await _client.get<List<dynamic>>('/admin/support/tickets');
    return (response.data ?? const <dynamic>[])
        .map((item) => SupportTicket.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicket> respond({
    required String ticketId,
    required SupportStatus status,
    required String responseText,
  }) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/admin/support/tickets/$ticketId',
      data: {
        'status': status.apiValue,
        'response': responseText.trim(),
      },
    );
    return SupportTicket.fromJson(response.data!);
  }
}
