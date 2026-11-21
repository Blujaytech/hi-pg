import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import 'notification_models.dart';
import 'notification_repository.dart';

class NotificationInboxScreen extends StatefulWidget {
  final NotificationRepository? repository;

  const NotificationInboxScreen({super.key, this.repository});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  late final NotificationRepository _repository =
      widget.repository ?? NotificationRepository();
  AppNotificationFeed? _feed;
  String? _error;
  bool _loading = true;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feed = await _repository.list();
      if (mounted) setState(() => _feed = feed);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Notifications could not be loaded.';

  Future<void> _open(AppNotificationItem item) async {
    if (!item.read) {
      try {
        final updated = await _repository.markRead(item.id);
        if (mounted && _feed != null) {
          setState(() {
            _feed = AppNotificationFeed(
              notifications: [
                for (final notification in _feed!.notifications)
                  if (notification.id == item.id) updated else notification,
              ],
              unreadCount: (_feed!.unreadCount - 1).clamp(0, 1 << 31),
            );
          });
        }
      } catch (_) {
        // Opening the related screen is still useful when the read receipt fails.
      }
    }
    if (!mounted) return;
    final route = item.actionRoute;
    if (route != null && route.isNotEmpty && route != '/notifications') {
      context.push(route);
    }
  }

  Future<void> _markAllRead() async {
    if (_feed == null || _feed!.unreadCount == 0 || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _repository.markAllRead();
      if (mounted) {
        setState(() {
          _feed = AppNotificationFeed(
            notifications: _feed!.notifications
                .map((notification) => notification.copyWith(read: true))
                .toList(),
            unreadCount: 0,
          );
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(
          title: 'Notifications',
          subtitle: 'Bookings, payments and important updates',
        ),
        actions: [
          if ((_feed?.unreadCount ?? 0) > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: Text(_markingAll ? 'Marking…' : 'Read all'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _feed == null) {
      return const AppLoadingView(label: 'Loading your updates…');
    }
    if (_error != null && _feed == null) {
      return AppErrorView(message: _error!, onRetry: _load);
    }
    final notifications = _feed?.notifications ?? const <AppNotificationItem>[];
    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            AppEmptyView(
              icon: Icons.notifications_none_rounded,
              title: 'You are all caught up',
              message: 'Important HiPG updates will stay available here.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _NotificationCard(item: notifications[index], onTap: _open),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationItem item;
  final ValueChanged<AppNotificationItem> onTap;

  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.category) {
      AppNotificationCategory.booking => (
          Icons.event_available_rounded,
          AppColors.brand
        ),
      AppNotificationCategory.payment => (
          Icons.payments_outlined,
          AppColors.success
        ),
      AppNotificationCategory.complaint => (
          Icons.report_problem_outlined,
          AppColors.warning
        ),
      AppNotificationCategory.property => (
          Icons.apartment_rounded,
          AppColors.brand
        ),
      AppNotificationCategory.discovery => (
          Icons.travel_explore_rounded,
          AppColors.brand
        ),
      AppNotificationCategory.account => (
          Icons.manage_accounts_outlined,
          AppColors.ink
        ),
      AppNotificationCategory.support => (
          Icons.support_agent_rounded,
          AppColors.brand
        ),
      _ => (Icons.notifications_rounded, AppColors.ink),
    };
    return Material(
      color: item.read ? AppColors.surface : AppColors.brandSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onTap(item),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: item.read
                                      ? FontWeight.w700
                                      : FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(item.message,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 9),
                    Text(
                      DateFormat('d MMM, h:mm a').format(item.createdAt),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (item.actionRoute != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 11),
                  child:
                      Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
