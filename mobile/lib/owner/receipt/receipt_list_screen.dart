import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../fee/fee_models.dart';
import 'receipt_models.dart';
import 'receipt_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Read-only -- receipts are auto-generated when a payment is recorded
/// (Fee screen), never created here. See docs/decisions.md ADR on Receipt.
class ReceiptListScreen extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ReceiptListScreen(
      {super.key, required this.studentId, this.studentName});

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

  void _reload() =>
      setState(() => _future = _repository.listForStudent(widget.studentId));

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receipts'),
            if (widget.studentName != null)
              Text(widget.studentName!,
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: FutureBuilder<List<Receipt>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(label: 'Loading receipts...');
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : 'Receipts could not be loaded.';
            return AppErrorView(message: message, onRetry: _reload);
          }
          final receipts = snapshot.data ?? const <Receipt>[];
          if (receipts.isEmpty) {
            return const AppEmptyView(
              icon: Icons.description_outlined,
              title: 'No receipts yet',
              message:
                  'A receipt is generated automatically every time a payment is recorded on the Fees screen.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              itemCount: receipts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final receipt = receipts[index];
                final period = DateFormat('MMM yyyy').format(
                    DateTime(receipt.feePeriodYear, receipt.feePeriodMonth));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const IconTile(icon: Icons.receipt_rounded, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(receipt.receiptNumber,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 3),
                              Text(
                                '$period · ${receipt.method.label} · ${DateFormat('d MMM yyyy').format(receipt.paidOn)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _money.format(receipt.amount),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
