import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'report_models.dart';
import 'report_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Phase 8: owner-wide reports across every PG. Everything here is computed
/// by the backend at request time from Fee/Payment/Expense/Bed rows -- there
/// is no caching on either side, so a pull-to-refresh always reflects the
/// latest data.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _repository = ReportRepository();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Revenue'),
              Tab(text: 'Occupancy'),
              Tab(text: 'Dues'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _RevenueTab(repository: _repository),
          _OccupancyTab(repository: _repository),
          _OutstandingDuesTab(repository: _repository),
        ]),
      ),
    );
  }
}

/// Shared loading / error / pull-to-refresh plumbing for one report tab.
class _ReportTab<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final String errorFallback;
  final Widget empty;
  final Widget Function(BuildContext, List<T>) header;
  final Widget Function(BuildContext, T) item;

  const _ReportTab({
    super.key,
    required this.load,
    required this.errorFallback,
    required this.empty,
    required this.header,
    required this.item,
  });

  @override
  State<_ReportTab<T>> createState() => _ReportTabState<T>();
}

class _ReportTabState<T> extends State<_ReportTab<T>>
    with AutomaticKeepAliveClientMixin {
  late Future<List<T>> _future = widget.load();

  @override
  bool get wantKeepAlive => true;

  void _reload() => setState(() => _future = widget.load());

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
    super.build(context);
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingView();
        }
        if (snapshot.hasError) {
          final message = snapshot.error is ApiException
              ? (snapshot.error as ApiException).message
              : widget.errorFallback;
          return AppErrorView(message: message, onRetry: _reload);
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) return widget.empty;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => index == 0
                ? widget.header(context, rows)
                : widget.item(context, rows[index - 1]),
          ),
        );
      },
    );
  }
}

class _RevenueTab extends StatelessWidget {
  final ReportRepository repository;

  const _RevenueTab({required this.repository});

  @override
  Widget build(BuildContext context) {
    return _ReportTab<MonthlyFinancialSummary>(
      load: () => repository.revenue(months: 6),
      errorFallback: 'The revenue report could not be loaded.',
      empty: const AppEmptyView(
        icon: Icons.bar_chart_rounded,
        title: 'No revenue yet',
        message: 'Recorded payments and expenses will appear here by month.',
      ),
      header: (context, months) {
        final collected = months.fold<double>(0, (s, m) => s + m.collected);
        final net = months.fold<double>(0, (s, m) => s + m.net);
        return _SummaryBand(items: [
          ('Collected · ${months.length} mo', _money.format(collected)),
          ('Net', _money.format(net)),
        ]);
      },
      item: (context, month) => _RevenueRow(month: month),
    );
  }
}

class _RevenueRow extends StatelessWidget {
  final MonthlyFinancialSummary month;

  const _RevenueRow({required this.month});

  @override
  Widget build(BuildContext context) {
    final total = month.collected + month.expenses;
    final collectedShare = total <= 0 ? 0.0 : month.collected / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(month.label,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Text(
                  '${month.net >= 0 ? '+' : ''}${_money.format(month.net)}',
                  style: TextStyle(
                    color: month.net >= 0 ? AppColors.success : AppColors.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (collectedShare > 0)
                      Expanded(
                        flex: (collectedShare * 1000).round(),
                        child: const ColoredBox(color: AppColors.ink),
                      ),
                    if (collectedShare < 1)
                      Expanded(
                        flex: ((1 - collectedShare) * 1000).round(),
                        child: const ColoredBox(color: AppColors.line),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Legend(
                    color: AppColors.ink,
                    label: 'Collected ${_money.format(month.collected)}'),
                const SizedBox(width: 14),
                _Legend(
                    color: AppColors.line,
                    label: 'Expenses ${_money.format(month.expenses)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OccupancyTab extends StatelessWidget {
  final ReportRepository repository;

  const _OccupancyTab({required this.repository});

  @override
  Widget build(BuildContext context) {
    return _ReportTab<OccupancyReport>(
      load: repository.occupancy,
      errorFallback: 'The occupancy report could not be loaded.',
      empty: const AppEmptyView(
        icon: Icons.apartment_rounded,
        title: 'No properties yet',
        message: 'Add a property and its beds to see occupancy here.',
      ),
      header: (context, pgs) {
        final total = pgs.fold<int>(0, (s, p) => s + p.totalBeds);
        final occupied = pgs.fold<int>(0, (s, p) => s + p.occupiedBeds);
        return _SummaryBand(items: [
          ('Beds occupied', '$occupied / $total'),
          (
            'Overall',
            total == 0 ? '0%' : '${(occupied * 100 / total).round()}%'
          ),
        ]);
      },
      item: (context, pg) => _OccupancyRow(pg: pg),
    );
  }
}

class _OccupancyRow extends StatelessWidget {
  final OccupancyReport pg;

  const _OccupancyRow({required this.pg});

  @override
  Widget build(BuildContext context) {
    final segments = [
      (pg.occupiedBeds, AppColors.ink),
      (pg.maintenanceBeds, AppColors.warning),
      (pg.availableBeds, AppColors.line),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.apartment_rounded, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pg.pgName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${pg.totalBeds} beds',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  '${pg.occupancyPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final (count, color) in segments)
                      if (count > 0)
                        Expanded(flex: count, child: ColoredBox(color: color)),
                    if (pg.totalBeds == 0)
                      const Expanded(child: ColoredBox(color: AppColors.fill)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Legend(
                    color: AppColors.ink, label: '${pg.occupiedBeds} occupied'),
                _Legend(
                    color: AppColors.warning,
                    label: '${pg.maintenanceBeds} maintenance'),
                _Legend(
                    color: AppColors.line,
                    label: '${pg.availableBeds} available'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutstandingDuesTab extends StatelessWidget {
  final ReportRepository repository;

  const _OutstandingDuesTab({required this.repository});

  @override
  Widget build(BuildContext context) {
    return _ReportTab<OutstandingDue>(
      load: repository.outstandingDues,
      errorFallback: 'Outstanding dues could not be loaded.',
      empty: const AppEmptyView(
        icon: Icons.verified_rounded,
        title: 'All paid up',
        message: 'No outstanding dues. Everyone is paid up.',
      ),
      header: (context, dues) {
        final total = dues.fold<double>(0, (s, d) => s + d.balance);
        final overdue = dues.where((d) => d.overdue).length;
        return _SummaryBand(items: [
          ('Outstanding', _money.format(total)),
          ('Overdue', '$overdue of ${dues.length}'),
        ]);
      },
      item: (context, due) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: due.overdue ? AppColors.dangerSoft : AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  due.studentName.isNotEmpty
                      ? due.studentName.characters.first.toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: due.overdue ? AppColors.danger : AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(due.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${due.pgName} · ${DateFormat('MMM yyyy').format(DateTime(due.periodYear, due.periodMonth))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    StatusPill(
                      label: due.overdue
                          ? 'Overdue since ${DateFormat('d MMM').format(due.dueDate)}'
                          : 'Due ${DateFormat('d MMM').format(due.dueDate)}',
                      tone: due.overdue
                          ? StatusTone.danger
                          : StatusTone.neutral,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money.format(due.balance),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: due.overdue ? AppColors.danger : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBand extends StatelessWidget {
  final List<(String, String)> items;

  const _SummaryBand({required this.items});

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
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white.withValues(alpha: .14),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i].$1,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .62),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(items[i].$2,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
