import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import 'report_models.dart';
import 'report_repository.dart';

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
          bottom: const TabBar(tabs: [
            Tab(text: 'Revenue'),
            Tab(text: 'Occupancy'),
            Tab(text: 'Outstanding'),
          ]),
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

class _RevenueTab extends StatefulWidget {
  final ReportRepository repository;
  const _RevenueTab({required this.repository});

  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  late Future<List<MonthlyFinancialSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.revenue(months: 6);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MonthlyFinancialSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(_errorMessage(snapshot.error, 'Failed to load revenue report')));
        }
        final months = snapshot.data!;
        final maxCollected = months.map((m) => m.collected).fold(0.0, (a, b) => a > b ? a : b);
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = widget.repository.revenue(months: 6)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: months.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = months[index];
              final barWidth = maxCollected == 0 ? 0.0 : (m.collected / maxCollected);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: barWidth, minHeight: 8),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Collected: ₹${m.collected.toStringAsFixed(0)}'),
                          Text('Expenses: ₹${m.expenses.toStringAsFixed(0)}'),
                          Text('Net: ₹${m.net.toStringAsFixed(0)}',
                              style: TextStyle(color: m.net >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _OccupancyTab extends StatefulWidget {
  final ReportRepository repository;
  const _OccupancyTab({required this.repository});

  @override
  State<_OccupancyTab> createState() => _OccupancyTabState();
}

class _OccupancyTabState extends State<_OccupancyTab> {
  late Future<List<OccupancyReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.occupancy();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OccupancyReport>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(_errorMessage(snapshot.error, 'Failed to load occupancy report')));
        }
        final pgs = snapshot.data!;
        if (pgs.isEmpty) {
          return const Center(child: Text('No PGs yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = widget.repository.occupancy()),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pgs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pg = pgs[index];
              return Card(
                child: ListTile(
                  title: Text(pg.pgName),
                  subtitle: Text('${pg.occupiedBeds} occupied • ${pg.availableBeds} available • ${pg.maintenanceBeds} maintenance • ${pg.totalBeds} total beds'),
                  trailing: Text('${pg.occupancyPercentage.toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _OutstandingDuesTab extends StatefulWidget {
  final ReportRepository repository;
  const _OutstandingDuesTab({required this.repository});

  @override
  State<_OutstandingDuesTab> createState() => _OutstandingDuesTabState();
}

class _OutstandingDuesTabState extends State<_OutstandingDuesTab> {
  late Future<List<OutstandingDue>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.outstandingDues();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OutstandingDue>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(_errorMessage(snapshot.error, 'Failed to load outstanding dues')));
        }
        final dues = snapshot.data!;
        if (dues.isEmpty) {
          return const Center(child: Text('No outstanding dues. Everyone is paid up.'));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = widget.repository.outstandingDues()),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: dues.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final d = dues[index];
              return Card(
                child: ListTile(
                  leading: Icon(d.overdue ? Icons.warning_amber_outlined : Icons.schedule,
                      color: d.overdue ? Colors.red.shade700 : null),
                  title: Text('${d.studentName} — ${d.pgName}'),
                  subtitle: Text('${d.periodMonth}/${d.periodYear} • due ${d.dueDate.toIso8601String().substring(0, 10)}${d.overdue ? ' (overdue)' : ''}'),
                  trailing: Text('₹${d.balance.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String _errorMessage(Object? error, String fallback) => error is ApiException ? error.message : fallback;
