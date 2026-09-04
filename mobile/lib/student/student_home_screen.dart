import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../shared/live_events/live_events_listener.dart';

/// Phase 9: student discovery landed as its own screen (PgSearchScreen);
/// this home screen is now just a launcher for it plus logout, until
/// booking/complaints/profile (Phase 11+) give it more to show.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveEventsListener(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('PG Platform'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment, size: 64),
              const SizedBox(height: 16),
              const Text(
                "You're signed in as a student. Complaints filing isn't built yet "
                '(see PG_PLATFORM_TECHNICAL_PLAN.md §6, Phase 11+ for what remains).',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/student/search'),
                icon: const Icon(Icons.search),
                label: const Text('Find a PG'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/student/bookings'),
                icon: const Icon(Icons.event_note),
                label: const Text('My Bookings'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/student/fees'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('My Fees'),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
