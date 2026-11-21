import '../shared/api_client.dart';
import 'notification_models.dart';

class NotificationRepository {
  final ApiClient _client;

  NotificationRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  Future<AppNotificationFeed> list({int limit = 50}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/me/notifications',
      queryParameters: {'limit': limit},
    );
    return AppNotificationFeed.fromJson(response.data!);
  }

  Future<AppNotificationItem> markRead(String id) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/me/notifications/$id/read',
    );
    return AppNotificationItem.fromJson(response.data!);
  }

  Future<void> markAllRead() async {
    await _client.patch<void>('/me/notifications/read-all');
  }
}
