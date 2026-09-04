import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import 'fee_models.dart';
import 'fee_repository.dart';

class FeeListScreen extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const FeeListScreen({super.key, required this.studentId, this.studentName});

  @override
  State<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends State<FeeListScreen> {
  final _repository = FeeRepository();
  late Future<List<Fee>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listForStudent(widget.studentId);
  }

  void _reload() => setState(() => _future = _repository.listForStudent(widget.studentId));

  Future<void> _openCreateDialog() async {
    final now = DateTime.now();
    final monthController = TextEditingController(text: '${now.month}');
    final yearController = TextEditingController(text: '${now.year}');
    final amountController = TextEditingController();
    DateTime dueDate = DateTime(now.year, now.month, 10);
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add a fee'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: monthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Month (1-12)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Due date: ${dueDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: dueDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _repository.create(
                    studentId: widget.studentId,
                    periodMonth: int.tryParse(monthController.text.trim()) ?? now.month,
                    periodYear: int.tryParse(yearController.text.trim()) ?? now.year,
                    amount: double.tryParse(amountController.text.trim()) ?? 0,
                    dueDate: dueDate,
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _openRecordPaymentDialog(Fee fee) async {
    final amountController = TextEditingController(text: fee.balance.toStringAsFixed(2));
    PaymentMethod method = PaymentMethod.cash;
    String? error;

    final recorded = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Record payment • ${fee.periodMonth}/${fee.periodYear}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
              Text('Balance due: ₹${fee.balance.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount received (₹)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                value: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: PaymentMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label))).toList(),
                onChanged: (v) => setDialogState(() => method = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await _repository.recordPayment(
                    feeId: fee.id,
                    amountPaid: double.tryParse(amountController.text.trim()) ?? 0,
                    paidOn: DateTime.now(),
                    method: method,
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (recorded == true) _reload();
  }

  Color _statusColor(Fee fee) {
    if (fee.overdue) return Colors.red;
    switch (fee.status) {
      case FeeStatus.paid:
        return Colors.green;
      case FeeStatus.partiallyPaid:
        return Colors.orange;
      case FeeStatus.pending:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fees${widget.studentName != null ? ' • ${widget.studentName}' : ''}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Fee'),
      ),
      body: FutureBuilder<List<Fee>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fees = snapshot.data ?? [];
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
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(fee).withOpacity(0.15),
                    child: Icon(Icons.receipt_long_outlined, color: _statusColor(fee)),
                  ),
                  title: Text('${fee.periodMonth}/${fee.periodYear} • ₹${fee.amount.toStringAsFixed(0)}'),
                  subtitle: Text('${fee.overdue ? "OVERDUE • " : ""}${fee.status.label} • Balance ₹${fee.balance.toStringAsFixed(0)}'),
                  children: [
                    if (fee.payments.isNotEmpty)
                      ...fee.payments.map((p) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.check_circle_outline, size: 18),
                            title: Text('₹${p.amountPaid.toStringAsFixed(0)} • ${p.method.label}'),
                            subtitle: Text(p.paidOn.toIso8601String().substring(0, 10)),
                          )),
                    if (fee.status != FeeStatus.paid)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton.icon(
                          onPressed: () => _openRecordPaymentDialog(fee),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Record payment'),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
