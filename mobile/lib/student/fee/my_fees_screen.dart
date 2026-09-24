import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../owner/fee/fee_models.dart';
import '../../shared/app_states.dart';
import 'student_fee_repository.dart';
import '../payment/payment_repository.dart';
import '../payment/razorpay_checkout.dart';
import '../booking/booking_models.dart';
import '../booking/booking_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

class MyFeesScreen extends StatefulWidget {
  const MyFeesScreen({super.key});

  @override
  State<MyFeesScreen> createState() => _MyFeesScreenState();
}

class _MyFeesScreenState extends State<MyFeesScreen> {
  final _repository = StudentFeeRepository();
  final _paymentRepository = PaymentRepository();
  final _bookingRepository = BookingRepository();
  late final RazorpayCheckout _checkout;
  late Future<_PaymentViewData> _future;

  /// The fee whose checkout is currently open, if any. "Pay now" is a money
  /// action, so every pay button is disabled while one is in flight -- a
  /// double tap would otherwise open two Razorpay checkouts for the same rent.
  String? _payingFeeId;
  bool _enablingAutoPay = false;

  @override
  void initState() {
    super.initState();
    _checkout = RazorpayCheckout(_paymentRepository);
    _future = _load();
  }

  Future<_PaymentViewData> _load() async {
    List<Fee> fees;
    try {
      fees = await _repository.listMine();
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      fees = const [];
    }
    final bookings = await _bookingRepository.listMine();
    return _PaymentViewData(fees: fees, bookings: bookings);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder renders the error state.
    }
  }

  Future<void> _payFee(Fee fee) async {
    if (_payingFeeId != null) return;
    setState(() => _payingFeeId = fee.id);
    try {
      final order = await _paymentRepository.createFeeOrder(fee.id);
      await _checkout.pay(order,
          description:
              'Rent for ${DateFormat('MMMM yyyy').format(DateTime(fee.periodYear, fee.periodMonth))}');
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment received successfully.')));
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
      if (mounted) setState(() => _payingFeeId = null);
    }
  }

  Future<void> _enableAutoPay() async {
    if (_enablingAutoPay) return;
    var dueDay = 10;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
                title: const Text('Enable monthly AutoPay'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'You authorize Razorpay to debit rent automatically each month. No owner approval is required for each debit.'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: dueDay,
                        decoration: const InputDecoration(
                            labelText: 'Monthly debit day'),
                        items: [1, 5, 10, 15, 20, 25, 28]
                            .map((day) => DropdownMenuItem(
                                value: day, child: Text('Day $day')))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => dueDay = value);
                        },
                      ),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Authorize')),
                ],
              )),
    );
    if (accepted != true || !mounted) return;
    setState(() => _enablingAutoPay = true);
    try {
      final mandate = await _paymentRepository.enableAutoPay(dueDay);
      final url = mandate.authorizationUrl;
      if (url == null ||
          !await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the Razorpay authorization page');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _enablingAutoPay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees & payments')),
      body: FutureBuilder<_PaymentViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(label: 'Loading fee records...');
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiException
                ? error.message
                : 'Check your connection and try again.';
            if (error is ApiException && error.statusCode == 404) {
              return AppEmptyView(
                icon: Icons.receipt_long_outlined,
                title: 'No fee profile yet',
                message:
                    'Your fee records become available after you book a bed.',
                actionLabel: 'Refresh',
                actionIcon: Icons.refresh_rounded,
                onAction: _reload,
              );
            }
            return AppErrorView(message: message, onRetry: _reload);
          }

          final data = snapshot.data ?? const _PaymentViewData();
          final fees = data.fees;
          final bookings = data.bookings;
          if (fees.isEmpty && bookings.isEmpty) {
            return const AppEmptyView(
              icon: Icons.check_circle_outline_rounded,
              title: 'No fees recorded',
              message:
                  'There are no rent charges on your account at the moment.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              itemCount: fees.length + bookings.length + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _PaymentOverview(fees: fees, bookings: bookings);
                }
                if (index == 1) {
                  return _PaymentNotice(
                    onEnableAutoPay: _enablingAutoPay ? null : _enableAutoPay,
                  );
                }
                final bookingIndex = index - 2;
                if (bookingIndex < bookings.length) {
                  return _BookingPaymentCard(booking: bookings[bookingIndex]);
                }
                final fee = fees[bookingIndex - bookings.length];
                return _FeeCard(
                  fee: fee,
                  onPay: _payingFeeId == null ? () => _payFee(fee) : null,
                  paying: _payingFeeId == fee.id,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PaymentViewData {
  final List<Fee> fees;
  final List<Booking> bookings;

  const _PaymentViewData({this.fees = const [], this.bookings = const []});
}

class _PaymentOverview extends StatelessWidget {
  final List<Fee> fees;
  final List<Booking> bookings;

  const _PaymentOverview({required this.fees, required this.bookings});

  @override
  Widget build(BuildContext context) {
    final unpaidBookings = bookings.where((booking) =>
        booking.status == BookingStatus.paymentPending ||
        booking.status == BookingStatus.directPaymentReview);
    final paidBookings = bookings.where((booking) =>
        booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.checkedIn ||
        booking.status == BookingStatus.completed);
    final due = fees.fold<double>(0, (sum, fee) => sum + fee.balance) +
        unpaidBookings.fold<double>(
            0, (sum, booking) => sum + booking.totalAmount);
    final paid = fees.fold<double>(0, (sum, fee) => sum + fee.amountPaid) +
        paidBookings.fold<double>(
            0, (sum, booking) => sum + booking.totalAmount);
    final deposits = paidBookings.fold<double>(
        0, (sum, booking) => sum + booking.securityDepositAmount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding balance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .62),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _money.format(due),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  icon: Icons.task_alt_rounded,
                  label: 'Total paid',
                  value: _money.format(paid),
                ),
              ),
              Container(
                height: 36,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white.withValues(alpha: .14),
              ),
              Expanded(
                child: _SummaryValue(
                  icon: Icons.savings_outlined,
                  label: 'Deposit paid',
                  value: _money.format(deposits),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingPaymentCard extends StatelessWidget {
  final Booking booking;

  const _BookingPaymentCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final paid = booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.checkedIn ||
        booking.status == BookingStatus.completed;
    final awaitingVerification =
        booking.status == BookingStatus.directPaymentReview;
    final inactive = booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.expired;
    final pending =
        booking.status == BookingStatus.paymentPending || awaitingVerification
            ? booking.totalAmount
            : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.bed_outlined, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.pgName,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Room ${booking.roomNumber} · ${booking.bedLabel}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(
                  label: awaitingVerification
                      ? 'Verifying'
                      : paid
                          ? 'Paid'
                          : booking.status.label,
                  tone: paid
                      ? StatusTone.success
                      : awaitingVerification
                          ? StatusTone.warning
                          : StatusTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _Amount(
                        label: 'Rent',
                        value: _money.format(booking.rentAmount))),
                Expanded(
                    child: _Amount(
                        label: 'Deposit',
                        value: _money.format(booking.securityDepositAmount))),
                Expanded(
                    child: _Amount(
                        label: 'Total',
                        value: _money.format(booking.totalAmount))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    pending > 0 ? AppColors.warningSoft : AppColors.successSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                awaitingVerification
                    ? '${_money.format(pending)} sent · owner verification pending'
                    : pending > 0
                        ? 'Pending amount: ${_money.format(pending)}'
                        : inactive
                            ? 'No amount due · ${booking.status.label.toLowerCase()}'
                            : 'Paid amount: ${_money.format(booking.totalAmount)}',
                style: TextStyle(
                  color: pending > 0
                      ? AppColors.warning
                      : inactive
                          ? AppColors.muted
                          : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: .8), size: 19),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .62),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentNotice extends StatelessWidget {
  final VoidCallback? onEnableAutoPay;
  const _PaymentNotice({required this.onEnableAutoPay});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.autorenew_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          const Expanded(
              child: Text(
                  'Pay by UPI, card or netbanking, or authorize automatic monthly rent.')),
          TextButton(onPressed: onEnableAutoPay, child: const Text('AutoPay')),
        ]),
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  final Fee fee;
  final VoidCallback? onPay;
  final bool paying;

  const _FeeCard({required this.fee, required this.onPay, this.paying = false});

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(fee.periodYear, fee.periodMonth));
    final dueDate = DateFormat('d MMM yyyy').format(fee.effectiveDueDate);
    final progress =
        fee.amount <= 0 ? 0.0 : (fee.amountPaid / fee.amount).clamp(0.0, 1.0);
    final (label, tone) = fee.overdue
        ? ('Overdue', StatusTone.danger)
        : switch (fee.status) {
            FeeStatus.paid => (fee.status.label, StatusTone.success),
            FeeStatus.partiallyPaid => (fee.status.label, StatusTone.dark),
            FeeStatus.pending => (fee.status.label, StatusTone.warning),
          };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.calendar_month_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(month,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Due $dueDate',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(label: label, tone: tone),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child:
                      _Amount(label: 'Fee', value: _money.format(fee.amount)),
                ),
                Expanded(
                  child: _Amount(
                    label: 'Paid',
                    value: _money.format(fee.amountPaid),
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _Amount(
                    label: 'Balance',
                    value: _money.format(fee.balance),
                    color: fee.balance > 0 ? AppColors.warning : AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                color: AppColors.success,
              ),
            ),
            if (fee.notes != null && fee.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(fee.notes!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (fee.status != FeeStatus.paid) ...[
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPay,
                    icon: paying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(paying ? 'Opening checkout...' : 'Pay now'),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Amount({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
        ),
      ],
    );
  }
}
