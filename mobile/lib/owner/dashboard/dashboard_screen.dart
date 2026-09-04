import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

/// Deliberately thin (technical plan §6 Phase 3): counts + occupancy % only,
/// grows richer once fees/payments exist (Phase 5).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<DashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Failed to load dashboard';
            return Center(child: Text(message));
          }
          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _StatCard(label: 'PGs', value: '${summary.totalPgs}', icon: Icons.apartment),
                _StatCard(label: 'Occupancy', value: '${summary.occupancyPercentage.toStringAsFixed(1)}%', icon: Icons.pie_chart_outline),
                _StatCard(label: 'Total Beds', value: '${summary.totalBeds}', icon: Icons.bed_outlined),
                _StatCard(label: 'Occupied', value: '${summary.occupiedBeds}', icon: Icons.event_seat),
                _StatCard(label: 'Available', value: '${summary.availableBeds}', icon: Icons.check_circle_outline),
                _StatCard(label: 'Active Students', value: '${summary.totalActiveStudents}', icon: Icons.school_outlined),
                _StatCard(label: 'Pending Dues', value: '₹${summary.totalPendingDues.toStringAsFixed(0)}', icon: Icons.warning_amber_outlined),
                _StatCard(label: 'Collected (month)', value: '₹${summary.collectedThisMonth.toStringAsFixed(0)}', icon: Icons.trending_up),
                _StatCard(label: 'Expenses (month)', value: '₹${summary.expensesThisMonth.toStringAsFixed(0)}', icon: Icons.trending_down),
                _StatCard(label: 'Net (month)', value: '₹${summary.netThisMonth.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_outlined),
                _StatCard(label: 'Open Complaints', value: '${summary.openComplaints}', icon: Icons.report_problem_outlined),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
