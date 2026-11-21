import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/notification/notification_models.dart';

void main() {
  test('parses a persistent notification feed', () {
    final feed = AppNotificationFeed.fromJson({
      'unreadCount': 1,
      'notifications': [
        {
          'id': 'notice-1',
          'title': 'Booking confirmed',
          'message': 'Your bed is ready.',
          'category': 'BOOKING',
          'actionRoute': '/student/bookings',
          'read': false,
          'createdAt': '2026-11-01T12:00:00Z',
        },
      ],
    });

    expect(feed.unreadCount, 1);
    expect(feed.notifications, hasLength(1));
    expect(feed.notifications.single.category, AppNotificationCategory.booking);
    expect(feed.notifications.single.actionRoute, '/student/bookings');
    expect(feed.notifications.single.read, isFalse);
  });

  test('unknown categories safely fall back to general', () {
    expect(AppNotificationCategory.fromApi('FUTURE_TYPE'),
        AppNotificationCategory.general);
  });

  test('parses discovery campaign notifications', () {
    expect(AppNotificationCategory.fromApi('DISCOVERY'),
        AppNotificationCategory.discovery);
  });
}
