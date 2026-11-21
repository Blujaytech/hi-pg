enum AppNotificationCategory {
  general,
  booking,
  payment,
  complaint,
  property,
  discovery,
  account,
  support;

  static AppNotificationCategory fromApi(String? value) => switch (value) {
        'BOOKING' => booking,
        'PAYMENT' => payment,
        'COMPLAINT' => complaint,
        'PROPERTY' => property,
        'DISCOVERY' => discovery,
        'ACCOUNT' => account,
        'SUPPORT' => support,
        _ => general,
      };

  String get apiValue => name.toUpperCase();
}

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final AppNotificationCategory category;
  final String? actionRoute;
  final bool read;
  final DateTime createdAt;

  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.actionRoute,
    required this.read,
    required this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) =>
      AppNotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        category: AppNotificationCategory.fromApi(json['category'] as String?),
        actionRoute: json['actionRoute'] as String?,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  AppNotificationItem copyWith({bool? read}) => AppNotificationItem(
        id: id,
        title: title,
        message: message,
        category: category,
        actionRoute: actionRoute,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}

class AppNotificationFeed {
  final List<AppNotificationItem> notifications;
  final int unreadCount;

  const AppNotificationFeed({
    required this.notifications,
    required this.unreadCount,
  });

  factory AppNotificationFeed.fromJson(Map<String, dynamic> json) =>
      AppNotificationFeed(
        notifications: (json['notifications'] as List<dynamic>? ?? const [])
            .map((item) =>
                AppNotificationItem.fromJson(item as Map<String, dynamic>))
            .toList(),
        unreadCount: json['unreadCount'] as int? ?? 0,
      );
}
