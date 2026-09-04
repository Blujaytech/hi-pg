import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';

/// Phase 14 -- subscribes to the authenticated per-user event stream
/// (`/me/events/stream`) and surfaces each one as a SnackBar while this
/// widget is mounted. Wrap any screen that should show live activity
/// (booking confirmed, payment received, complaint resolved, ...) in this;
/// see PgListScreen (owner) and StudentHomeScreen for the two places it's
/// used today. Purely additive to push/email (NotificationService sends
/// all three) -- this is just the "app is open right now" channel.
class LiveEventsListener extends StatefulWidget {
  final Widget child;

  const LiveEventsListener({super.key, required this.child});

  @override
  State<LiveEventsListener> createState() => _LiveEventsListenerState();
}

class _LiveEventsListenerState extends State<LiveEventsListener> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ApiClient.instance.sseStream('/me/events/stream').listen(
      (event) {
        if (!mounted) return;
        final title = event['title'] as String? ?? 'Notification';
        final message = event['message'] as String? ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $message'),
            duration: const Duration(seconds: 4),
          ),
        );
      },
      onError: (_) {
        // Silently drop -- this is a nice-to-have live channel, not load-bearing
        // (push/email already carry the same notification, see NotificationService).
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
