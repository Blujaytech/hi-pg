import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import 'receipt_models.dart';
import 'receipt_repository.dart';

/// Read-only -- receipts are auto-generated when a payment is recorded
/// (Fee screen), never created here. See docs/decisions.md ADR on Receipt.
class ReceiptListScreen extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ReceiptListScreen({super.key, required this.studentId, this.studentName});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final _repository = ReceiptRepository();
  late Future<List<Receipt>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listForStudent(widget.studentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Receipts${widget.studentName != null ? ' • ${widget.studentName}' : ''}')),
      body: FutureBuilder<List<Receipt>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Failed to load receipts';
            return Center(child: Text(message));
          }
          final receipts = snapshot.data ?? [];
          if (receipts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No receipts yet. A receipt is generated automatically every time a payment is recorded on the Fees screen.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: receipts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(receipt.receiptNumber),
                  subtitle: Text('${receipt.feePeriodMonth}/${receipt.feePeriodYear} • ${receipt.method.label} • ${receipt.paidOn.toIso8601String().substring(0, 10)}'),
                  trailing: Text('₹${receipt.amount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
