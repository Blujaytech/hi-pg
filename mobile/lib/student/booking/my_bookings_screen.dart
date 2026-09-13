import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'booking_models.dart';
import 'booking_repository.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _repository = BookingRepository();
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listMine();
  }

  void _reload() => setState(() => _future = _repository.listMine());

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder renders the error state.
    }
  }

  Future<void> _confirmCancel(Booking booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.event_busy_rounded, color: AppColors.danger),
        ),
        title: const Text('Cancel this booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${booking.pgName} · Room ${booking.roomNumber}, ${booking.bedLabel}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: reasonController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Tell the property owner why',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();
    try {
      await _repository.cancel(
        booking.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully')),
      );
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(label: 'Loading your stays...');
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Check your connection and try again.';
            return AppErrorView(message: message, onRetry: _reload);
          }

          final bookings = snapshot.data ?? const <Booking>[];
          if (bookings.isEmpty) {
            return AppEmptyView(
              icon: Icons.bed_outlined,
              title: 'No bookings yet',
              message:
                  'Explore verified PG listings, compare rooms, and choose an available bed.',
              actionLabel: 'Explore PGs',
              onAction: () => context.go('/student/search'),
            );
          }

          final activeCount = bookings
              .where((booking) => booking.status == BookingStatus.confirmed)
              .length;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              itemCount: bookings.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _BookingOverview(
                    total: bookings.length,
                    active: activeCount,
                  );
                }
                final booking = bookings[index - 1];
                return _BookingCard(
                  booking: booking,
                  onCancel: booking.status == BookingStatus.confirmed
                      ? () => _confirmCancel(booking)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _BookingOverview extends StatelessWidget {
  final int total;
  final int active;

  const _BookingOverview({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const IconTile(
            icon: Icons.home_work_rounded,
            size: 48,
            color: AppColors.ink,
            background: Colors.white,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$active active ${active == 1 ? 'stay' : 'stays'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total booking${total == 1 ? '' : 's'} in your history',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onCancel;

  const _BookingCard({required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final confirmed = booking.status == BookingStatus.confirmed;
    final date = DateFormat('d MMM yyyy').format(booking.moveInDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(
                  icon: confirmed
                      ? Icons.apartment_rounded
                      : Icons.event_busy_outlined,
                  size: 46,
                  dark: confirmed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.pgName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Room ${booking.roomNumber} · ${booking.bedLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: booking.status.label,
                  tone: confirmed ? StatusTone.success : StatusTone.neutral,
                  dot: confirmed,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.ink, size: 17),
                  const SizedBox(width: 9),
                  Text('Move-in', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text(date,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (booking.cancellationReason != null) ...[
              const SizedBox(height: 12),
              Text(
                'Cancellation reason: ${booking.cancellationReason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.dangerSoft, width: 1.4),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel booking'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
