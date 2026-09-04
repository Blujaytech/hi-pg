import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../pg/pg_models.dart';
import 'expense_models.dart';
import 'expense_repository.dart';

class ExpenseListScreen extends StatefulWidget {
  final String pgId;
  final Pg? pg;

  const ExpenseListScreen({super.key, required this.pgId, this.pg});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _repository = ExpenseRepository();
  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listForPg(widget.pgId);
  }

  void _reload() => setState(() => _future = _repository.listForPg(widget.pgId));

  Future<void> _openCreateDialog() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    ExpenseCategory category = ExpenseCategory.maintenance;
    DateTime expenseDate = DateTime.now();
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add an expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
                DropdownButtonFormField<ExpenseCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ExpenseCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${expenseDate.toIso8601String().substring(0, 10)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: expenseDate,
                      firstDate: DateTime(expenseDate.year - 1),
                      lastDate: DateTime(expenseDate.year + 1),
                    );
                    if (picked != null) setDialogState(() => expenseDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (descriptionController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Description is required');
                  return;
                }
                try {
                  await _repository.create(
                    pgId: widget.pgId,
                    category: category,
                    description: descriptionController.text.trim(),
                    amount: double.tryParse(amountController.text.trim()) ?? 0,
                    expenseDate: expenseDate,
                  );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Expenses${widget.pg != null ? ' • ${widget.pg!.name}' : ''}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: FutureBuilder<List<Expense>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final expenses = snapshot.data ?? [];
          if (expenses.isEmpty) {
            return const Center(child: Text('No expenses recorded yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_outlined),
                  title: Text(expense.description),
                  subtitle: Text('${expense.category.label} • ${expense.expenseDate.toIso8601String().substring(0, 10)}'),
                  trailing: Text('₹${expense.amount.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
