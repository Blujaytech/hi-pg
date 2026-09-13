import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../owner/fee/fee_models.dart';
import '../../shared/app_states.dart';
import 'student_fee_repository.dart';

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
  late Future<List<Fee>> _future;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees & payments')),
      body: FutureBuilder<List<Fee>>(
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

          final fees = snapshot.data ?? const <Fee>[];
          if (fees.isEmpty) {
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
              itemCount: fees.length + 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return _FeeOverview(fees: fees);
                if (index == 1) return const _PaymentNotice();
                return _FeeCard(fee: fees[index - 2]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _FeeOverview extends StatelessWidget {
  final List<Fee> fees;

  const _FeeOverview({required this.fees});

  @override
  Widget build(BuildContext context) {
    final due = fees.fold<double>(0, (sum, fee) => sum + fee.balance);
    final paid = fees.fold<double>(0, (sum, fee) => sum + fee.amountPaid);

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
                  icon: Icons.receipt_long_outlined,
                  label: 'Fee periods',
                  value: '${fees.length}',
                ),
              ),
            ],
          ),
        ],
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
  const _PaymentNotice();

  @override
  Widget build(BuildContext context) {
    return const AppMessageBanner(
      icon: Icons.info_outline_rounded,
      message:
          'Online payment will be enabled after the payment account is connected. For now, pay the owner directly; recorded payments appear here.',
    );
  }
}

class _FeeCard extends StatelessWidget {
  final Fee fee;

  const _FeeCard({required this.fee});

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(fee.periodYear, fee.periodMonth));
    final dueDate = DateFormat('d MMM yyyy').format(fee.dueDate);
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
                  child: _Amount(label: 'Fee', value: _money.format(fee.amount)),
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
