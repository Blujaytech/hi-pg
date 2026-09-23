import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import '../payment/payment_repository.dart';
import '../payment/direct_payment_repository.dart';
import '../payment/payment_choice_sheet.dart';
import '../payment/razorpay_checkout.dart';
import '../discovery/discovery_repository.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _repository = BookingRepository();
  final _paymentRepository = PaymentRepository();
  final _directPaymentRepository = DirectPaymentRepository();
  final _discoveryRepository = DiscoveryRepository();
  late final RazorpayCheckout _checkout;
  late Future<List<Booking>> _future;

  /// The booking whose payment flow is open, if any. Money actions get a
  /// single-flight guard: "Complete payment" goes straight to
  /// createBookingOrder when a channel is already chosen, with no modal in
  /// between, so an unguarded double tap opens two Razorpay checkouts.
  String? _payingBookingId;
  String? _cancellingBookingId;

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
    if (_cancellingBookingId != null) return;
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
    setState(() => _cancellingBookingId = booking.id);
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
    } finally {
      if (mounted) setState(() => _cancellingBookingId = null);
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
      final updated =
          await _repository.submitMoveOutNotice(booking.id, selected);
      if (mounted) {
        _reload();
        final message = updated.noticeShortfallDays > 0
            ? 'Notice submitted. It is ${updated.noticeShortfallDays} day(s) shorter than the PG policy.'
            : 'Move-out notice submitted.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _completePayment(Booking booking) async {
    if (_payingBookingId != null) return;
    setState(() => _payingBookingId = booking.id);
    try {
      if (booking.status == BookingStatus.directPaymentReview ||
          booking.paymentChannel == BookingPaymentChannel.directUpi) {
        await context
            .push<bool>('/student/bookings/${booking.id}/direct-payment');
        if (mounted) _reload();
        return;
      }

      var choice = BookingPaymentChoice.online;
      if (booking.paymentChannel == BookingPaymentChannel.unselected) {
        final pg = await _discoveryRepository.getDetails(booking.pgId);
        if (!mounted) return;
        final selected = await showBookingPaymentChoice(
          context,
          propertyName: booking.pgName,
          directOwnerAvailable: pg.directPaymentAvailable,
        );
        if (selected == null || !mounted) return;
        choice = selected;
      }

      if (choice == BookingPaymentChoice.directOwner) {
        await _directPaymentRepository.selectDirectPayment(booking.id);
        if (!mounted) return;
        await context
            .push<bool>('/student/bookings/${booking.id}/direct-payment');
        if (mounted) _reload();
        return;
      }

      final order = await _paymentRepository.createBookingOrder(booking.id);
      await _checkout.pay(order,
          description:
              '${booking.bookingType.label} booking at ${booking.pgName}');
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking confirmed.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _payingBookingId = null);
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
              .where((booking) =>
                  booking.status == BookingStatus.paymentPending ||
                  booking.status == BookingStatus.directPaymentReview ||
                  booking.status == BookingStatus.confirmed ||
                  booking.status == BookingStatus.checkedIn)
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
                final busy =
                    _payingBookingId != null || _cancellingBookingId != null;
                return _BookingCard(
                  booking: booking,
                  paying: _payingBookingId == booking.id,
                  cancelling: _cancellingBookingId == booking.id,
                  onCancel: !busy &&
                          (booking.status == BookingStatus.paymentPending ||
                              booking.status == BookingStatus.confirmed ||
                              booking.status == BookingStatus.checkedIn)
                      ? () => _confirmCancel(booking)
                      : null,
                  onNotice: booking.bookingType == BookingType.monthly &&
                          (booking.status == BookingStatus.confirmed ||
                              booking.status == BookingStatus.checkedIn)
                      ? () => _submitMoveOutNotice(booking)
                      : null,
                  onPay: !busy &&
                          (booking.status == BookingStatus.paymentPending ||
                              booking.status ==
                                  BookingStatus.directPaymentReview)
                      ? () => _completePayment(booking)
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

/// BookingService holds a bed for ten minutes (PAYMENT_HOLD_MINUTES) and then
/// expires it. The deadline was already on the model but never shown, so a
/// customer had no way to know the bed they are paying for is about to be
/// released.
class _HoldCountdown extends StatefulWidget {
  final DateTime expiresAt;

  const _HoldCountdown({required this.expiresAt});

  @override
  State<_HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<_HoldCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // paymentExpiresAt arrives as an instant; compare in the same zone rather
    // than mixing a UTC deadline with a local now.
    final remaining = widget.expiresAt.difference(DateTime.now());
    final expired = remaining.isNegative;
    final minutes = remaining.inMinutes.clamp(0, 59);
    final seconds = (remaining.inSeconds % 60).clamp(0, 59);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: expired ? AppColors.dangerSoft : AppColors.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(expired ? Icons.timer_off_outlined : Icons.timer_outlined,
              size: 17, color: expired ? AppColors.danger : AppColors.ink),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              expired
                  ? 'This bed hold has expired. Refresh to see the current status.'
                  : 'Bed held for ${minutes.toString().padLeft(2, '0')}:'
                      '${seconds.toString().padLeft(2, '0')} more',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: expired ? AppColors.danger : AppColors.ink,
              ),
            ),
          ),
        ],
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
  final bool paying;
  final bool cancelling;

  const _BookingCard(
      {required this.booking,
      this.onCancel,
      this.onNotice,
      this.onPay,
      this.paying = false,
      this.cancelling = false});

  @override
  Widget build(BuildContext context) {
    final active = booking.status == BookingStatus.paymentPending ||
        booking.status == BookingStatus.directPaymentReview ||
        booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.checkedIn;
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
                  tone: booking.status == BookingStatus.paymentPending ||
                          booking.status == BookingStatus.directPaymentReview
                      ? StatusTone.warning
                      : active
                          ? StatusTone.success
                          : StatusTone.neutral,
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
            if (booking.status == BookingStatus.paymentPending &&
                booking.paymentExpiresAt != null)
              _HoldCountdown(expiresAt: booking.paymentExpiresAt!),
            if (onPay != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onPay,
                icon: paying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  paying
                      ? 'Opening checkout...'
                      : booking.status == BookingStatus.directPaymentReview ||
                              booking.paymentChannel ==
                                  BookingPaymentChannel.directUpi
                          ? 'View owner verification'
                          : 'Complete payment',
                ),
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
                  side:
                      const BorderSide(color: AppColors.dangerSoft, width: 1.4),
                ),
                icon: cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.danger),
                      )
                    : const Icon(Icons.close_rounded, size: 18),
                label: Text(cancelling ? 'Cancelling...' : 'Cancel booking'),
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
