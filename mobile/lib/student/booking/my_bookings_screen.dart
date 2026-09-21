import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import '../payment/payment_repository.dart';
import '../payment/razorpay_checkout.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _repository = BookingRepository();
  final _paymentRepository = PaymentRepository();
  late final RazorpayCheckout _checkout;
  late Future<List<Booking>> _future;

  @override
  void initState() {
    super.initState();
    _checkout = RazorpayCheckout(_paymentRepository);
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

  Future<void> _submitMoveOutNotice(Booking booking) async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 15)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Planned move-out date',
    );
    if (selected == null) return;
    try {
      final updated = await _repository.submitMoveOutNotice(booking.id, selected);
      if (mounted) {
        _reload();
        final message = updated.noticeShortfallDays > 0
            ? 'Notice submitted. It is ${updated.noticeShortfallDays} day(s) shorter than the PG policy.'
            : 'Move-out notice submitted.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _payBooking(Booking booking) async {
    try {
      final order = await _paymentRepository.createBookingOrder(booking.id);
      await _checkout.pay(order, description: '${booking.bookingType.label} booking at ${booking.pgName}');
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking confirmed.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
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
              .where((booking) => booking.status == BookingStatus.paymentPending
                  || booking.status == BookingStatus.confirmed
                  || booking.status == BookingStatus.checkedIn)
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
                  onCancel: booking.status == BookingStatus.paymentPending
                          || booking.status == BookingStatus.confirmed
                          || booking.status == BookingStatus.checkedIn
                      ? () => _confirmCancel(booking)
                      : null,
                  onNotice: booking.bookingType == BookingType.monthly
                          && (booking.status == BookingStatus.confirmed
                              || booking.status == BookingStatus.checkedIn)
                      ? () => _submitMoveOutNotice(booking)
                      : null,
                  onPay: booking.status == BookingStatus.paymentPending
                      ? () => _payBooking(booking)
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
  final VoidCallback? onNotice;
  final VoidCallback? onPay;

  const _BookingCard({required this.booking, this.onCancel, this.onNotice, this.onPay});

  @override
  Widget build(BuildContext context) {
    final active = booking.status == BookingStatus.paymentPending
        || booking.status == BookingStatus.confirmed
        || booking.status == BookingStatus.checkedIn;
    final typeColor = booking.bookingType == BookingType.monthly
        ? const Color(0xFF7B61FF)
        : const Color(0xFF2F80ED);
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
                  icon: active
                      ? Icons.apartment_rounded
                      : Icons.event_busy_outlined,
                  size: 46,
                  color: typeColor,
                  background: typeColor.withValues(alpha: .10),
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
                        'Room ${booking.roomNumber} · ${booking.bedLabel} · ${booking.bookingType.label}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: booking.status.label,
                  tone: booking.status == BookingStatus.paymentPending
                      ? StatusTone.warning
                      : active ? StatusTone.success : StatusTone.neutral,
                  dot: active,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Total: ₹${booking.totalAmount.toStringAsFixed(0)}'
              '${booking.securityDepositAmount > 0 ? ' (includes ₹${booking.securityDepositAmount.toStringAsFixed(0)} deposit)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (booking.plannedMoveOutDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Move-out notice: ${DateFormat('d MMM yyyy').format(booking.plannedMoveOutDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (onPay != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Complete payment'),
              ),
            ],
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
            if (onNotice != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onNotice,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Submit move-out notice'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
