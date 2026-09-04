import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../owner/fee/fee_models.dart';
import 'student_fee_repository.dart';

/// Phase 12 -- read-only fee visibility for a logged-in student. Online
/// payment (Razorpay) isn't wired up to a UI yet: the backend contract
/// exists (`POST /student/fees/{feeId}/payment-orders`) but always returns
/// 501 until a real Razorpay account is configured, so -- same call made
/// for Document uploads in Phase 7b -- there's no "Pay Online" checkout
/// flow here yet either. See docs/decisions.md ADR-0019.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Fees')),
      body: FutureBuilder<List<Fee>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : "Couldn't load your fees. If you haven't booked a bed yet, there's nothing here.";
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)));
          }
          final fees = snapshot.data!;
          if (fees.isEmpty) {
            return const Center(child: Text('No fees recorded yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: fees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final fee = fees[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${fee.periodMonth}/${fee.periodYear}', style: Theme.of(context).textTheme.titleMedium),
                          Chip(
                            label: Text(fee.status.label),
                            backgroundColor: fee.status == FeeStatus.paid ? Colors.green.shade50 : Colors.orange.shade50,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Amount: ₹${fee.amount.toStringAsFixed(0)} • Paid: ₹${fee.amountPaid.toStringAsFixed(0)} • '
                          'Balance: ₹${fee.balance.toStringAsFixed(0)}'),
                      Text('Due ${fee.dueDate.toIso8601String().substring(0, 10)}${fee.overdue ? ' (overdue)' : ''}',
                          style: TextStyle(color: fee.overdue ? Colors.red.shade700 : null)),
                      if (fee.balance > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Online payment is coming soon. For now, pay your owner directly and they\'ll record it.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
