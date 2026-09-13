import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Owner "Insights" tab (technical plan §6 Phase 3, enriched in Phase 5):
/// portfolio occupancy, this month's money and open work, all from the
/// backend summary.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository();
  late Future<DashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.forOwner();
  }

  void _reload() => setState(() => _future = _repository.forOwner());

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
      appBar: AppBar(title: const Text('Insights')),
      body: FutureBuilder<DashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(label: 'Crunching your numbers...');
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Your insights could not be loaded.';
            return AppErrorView(message: message, onRetry: _reload);
          }
          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _OccupancyHero(summary: summary),
                const SizedBox(height: 28),
                const SectionHeader(title: 'This month'),
                const SizedBox(height: 12),
                _MetricGrid(children: [
                  _MetricTile(
                    icon: Icons.call_received_rounded,
                    label: 'Collected',
                    value: _money.format(summary.collectedThisMonth),
                    tone: StatusTone.success,
                  ),
                  _MetricTile(
                    icon: Icons.call_made_rounded,
                    label: 'Expenses',
                    value: _money.format(summary.expensesThisMonth),
                  ),
                  _MetricTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Net',
                    value: _money.format(summary.netThisMonth),
                    tone: summary.netThisMonth < 0
                        ? StatusTone.danger
                        : StatusTone.dark,
                  ),
                  _MetricTile(
                    icon: Icons.schedule_rounded,
                    label: 'Pending dues',
                    value: _money.format(summary.totalPendingDues),
                    tone: summary.totalPendingDues > 0
                        ? StatusTone.warning
                        : StatusTone.neutral,
                  ),
                ]),
                const SizedBox(height: 28),
                const SectionHeader(title: 'Portfolio'),
                const SizedBox(height: 12),
                _MetricGrid(children: [
                  _MetricTile(
                    icon: Icons.apartment_rounded,
                    label: 'Properties',
                    value: '${summary.totalPgs}',
                  ),
                  _MetricTile(
                    icon: Icons.bed_outlined,
                    label: 'Total beds',
                    value: '${summary.totalBeds}',
                  ),
                  _MetricTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Active customers',
                    value: '${summary.totalActiveStudents}',
                  ),
                  _MetricTile(
                    icon: Icons.report_problem_outlined,
                    label: 'Open complaints',
                    value: '${summary.openComplaints}',
                    tone: summary.openComplaints > 0
                        ? StatusTone.danger
                        : StatusTone.neutral,
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OccupancyHero extends StatelessWidget {
  final DashboardSummary summary;

  const _OccupancyHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final percent = summary.occupancyPercentage;
    final properties = summary.totalPgs;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Occupancy',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$properties ${properties == 1 ? 'property' : 'properties'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.occupiedBeds} of ${summary.totalBeds} beds occupied',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: .14),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroStat(label: 'Available', value: summary.availableBeds),
              _divider(),
              _HeroStat(label: 'Occupied', value: summary.occupiedBeds),
              _divider(),
              _HeroStat(label: 'Customers', value: summary.totalActiveStudents),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: .14),
      );
}

class _HeroStat extends StatelessWidget {
  final String label;
  final int value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _MetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final StatusTone tone;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.tone = StatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final (iconColor, iconBackground, valueColor) = switch (tone) {
      StatusTone.neutral => (AppColors.ink, AppColors.fill, AppColors.ink),
      StatusTone.dark => (Colors.white, AppColors.ink, AppColors.ink),
      StatusTone.success =>
        (AppColors.success, AppColors.successSoft, AppColors.ink),
      StatusTone.warning =>
        (AppColors.warning, AppColors.warningSoft, AppColors.warning),
      StatusTone.danger =>
        (AppColors.danger, AppColors.dangerSoft, AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: icon,
            size: 38,
            color: iconColor,
            background: iconBackground,
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
