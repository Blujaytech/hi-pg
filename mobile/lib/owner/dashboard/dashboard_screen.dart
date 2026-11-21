import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../../shared/direct_payment/direct_payment_models.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';
import '../direct_payment/direct_payment_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Owner dashboard (technical plan §6 Phase 3, enriched in Phase 5):
/// portfolio occupancy, this month's money and open work, all from the
/// backend summary.
class DashboardScreen extends StatefulWidget {
  /// Injectable for tests; default to the live API.
  final DashboardRepository? repository;
  final OwnerDirectPaymentRepository? directPaymentRepository;

  const DashboardScreen({
    super.key,
    this.repository,
    this.directPaymentRepository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repository =
      widget.repository ?? DashboardRepository();
  late final OwnerDirectPaymentRepository _directPaymentRepository =
      widget.directPaymentRepository ?? OwnerDirectPaymentRepository();
  late Future<DashboardSummary> _future;
  late Future<int> _pendingDirectPayments;

  @override
  void initState() {
    super.initState();
    _future = _repository.forOwner();
    _pendingDirectPayments = _loadPendingDirectPayments();
  }

  Future<int> _loadPendingDirectPayments() async {
    final results = await Future.wait([
      _directPaymentRepository.list(),
      _directPaymentRepository.list(
          status: DirectPaymentRequestStatus.reviewOverdue),
    ]);
    return results[0].length + results[1].length;
  }

  void _reload() => setState(() {
        _future = _repository.forOwner();
        _pendingDirectPayments = _loadPendingDirectPayments();
      });

  Future<void> _refresh() async {
    _reload();
    try {
      await Future.wait([_future, _pendingDirectPayments]);
    } catch (_) {
      // The FutureBuilder renders the error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _OwnerDashboardHeader(onRefresh: _refresh),
          Expanded(
            child: FutureBuilder<DashboardSummary>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingView(
                      label: 'Preparing your portfolio...');
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
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                    children: [
                      _DashboardReveal(
                        delay: 0,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Portfolio pulse',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Live occupancy and today\'s priorities.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const StatusPill(
                              label: 'LIVE',
                              tone: StatusTone.success,
                              dot: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DashboardReveal(
                        delay: 70,
                        child: _OccupancyHero(summary: summary),
                      ),
                      const SizedBox(height: 16),
                      _DashboardReveal(
                        delay: 120,
                        child: _DashboardQuickActions(
                          onProperties: () => context.go('/owner'),
                          onCustomers: () => context.go('/owner/customers'),
                          onFinance: () => context.go('/owner/reports'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DashboardReveal(
                        delay: 170,
                        child: FutureBuilder<int>(
                          future: _pendingDirectPayments,
                          builder: (context, pendingSnapshot) =>
                              _DirectPaymentReviewCard(
                            pending: pendingSnapshot.data,
                            loading: pendingSnapshot.connectionState ==
                                ConnectionState.waiting,
                            onTap: () =>
                                context.push('/owner/payment-requests'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(title: 'This month'),
                      const SizedBox(height: 12),
                      _DashboardReveal(
                        delay: 220,
                        child: _MetricGrid(children: [
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
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(title: 'Portfolio'),
                      const SizedBox(height: 12),
                      _DashboardReveal(
                        delay: 270,
                        child: _MetricGrid(children: [
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
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerDashboardHeader extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _OwnerDashboardHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292B3B), Color(0xFF3D4054)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'HI PG OWNER',
                            style: TextStyle(
                              color: Color(0xFFFFA8B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.live,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Live operations',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .68),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'Good business starts\nwith a clear view.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Refresh dashboard',
                onPressed: onRefresh,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .10),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardReveal extends StatelessWidget {
  final int delay;
  final Widget child;

  const _DashboardReveal({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 460 + delay),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _DashboardQuickActions extends StatelessWidget {
  final VoidCallback onProperties;
  final VoidCallback onCustomers;
  final VoidCallback onFinance;

  const _DashboardQuickActions({
    required this.onProperties,
    required this.onCustomers,
    required this.onFinance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Quick actions',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DashboardAction(
                    icon: Icons.apartment_rounded,
                    label: 'Properties',
                    onTap: onProperties,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DashboardAction(
                    icon: Icons.people_rounded,
                    label: 'Customers',
                    onTap: onCustomers,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DashboardAction(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Finance',
                    onTap: onFinance,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F7FA),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.brand, size: 19),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectPaymentReviewCard extends StatelessWidget {
  final int? pending;
  final bool loading;
  final VoidCallback onTap;

  const _DirectPaymentReviewCard({
    required this.pending,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = pending ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              IconTile(
                icon: Icons.verified_user_outlined,
                size: 46,
                color: count > 0 ? AppColors.warning : AppColors.success,
                background:
                    count > 0 ? AppColors.warningSoft : AppColors.successSoft,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Direct payment reviews',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      loading
                          ? 'Checking for new requests...'
                          : count == 0
                              ? 'No payments awaiting verification'
                              : '$count ${count == 1 ? 'payment needs' : 'payments need'} verification',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!loading && count > 0)
                StatusPill(label: '$count pending', tone: StatusTone.warning)
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.subtle),
            ],
          ),
        ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF333545), Color(0xFF252736)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'OCCUPANCY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(14),
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
              color: Colors.white.withValues(alpha: .78),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              color: AppColors.successBright,
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
              color: Colors.white.withValues(alpha: .72),
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
      StatusTone.dark => (
          AppColors.brandText,
          AppColors.brandSoft,
          AppColors.ink
        ),
      StatusTone.success => (
          AppColors.success,
          AppColors.successSoft,
          AppColors.ink
        ),
      StatusTone.warning => (
          AppColors.warning,
          AppColors.warningSoft,
          AppColors.warning
        ),
      StatusTone.danger => (
          AppColors.danger,
          AppColors.dangerSoft,
          AppColors.danger
        ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F3)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(
                icon: icon,
                size: 32,
                color: iconColor,
                background: iconBackground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}
