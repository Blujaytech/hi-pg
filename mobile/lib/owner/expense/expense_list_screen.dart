import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../pg/pg_models.dart';
import 'expense_models.dart';
import 'expense_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

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

  void _reload() =>
      setState(() => _future = _repository.listForPg(widget.pgId));

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder renders the error state.
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showFormSheet<bool>(
      context,
      (_) => _ExpenseFormSheet(repository: _repository, pgId: widget.pgId),
    );
    if (created == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Expense>>(
      future: _future,
      builder: (context, snapshot) {
        final expenses = snapshot.data ?? const <Expense>[];
        final ready = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expenses'),
                if (widget.pg != null)
                  Text(widget.pg!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          floatingActionButton: ready && expenses.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _openCreateSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add expense'),
                )
              : null,
          body: _buildBody(snapshot, expenses),
        );
      },
    );
  }

  Widget _buildBody(
      AsyncSnapshot<List<Expense>> snapshot, List<Expense> expenses) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading expenses...');
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : 'Expenses could not be loaded.';
      return AppErrorView(message: message, onRetry: _reload);
    }
    if (expenses.isEmpty) {
      return AppEmptyView(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No expenses yet',
        message:
            'Track maintenance, utilities and other running costs to see your real monthly net.',
        actionLabel: 'Add expense',
        actionIcon: Icons.add_rounded,
        onAction: _openCreateSheet,
      );
    }
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        itemCount: expenses.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total spent',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .62),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_money.format(total),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6)),
                      ],
                    ),
                  ),
                  Text(
                    '${expenses.length} ${expenses.length == 1 ? 'entry' : 'entries'}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .62),
                        fontSize: 12.5),
                  ),
                ],
              ),
            );
          }
          final expense = expenses[index - 1];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const IconTile(icon: Icons.receipt_outlined, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expense.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 3),
                        Text(
                          '${expense.category.label} · ${DateFormat('d MMM yyyy').format(expense.expenseDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money.format(expense.amount),
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  final ExpenseRepository repository;
  final String pgId;

  const _ExpenseFormSheet({required this.repository, required this.pgId});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.maintenance;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
      helpText: 'Expense date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.create(
        pgId: widget.pgId,
        category: _category,
        description: _description.text.trim(),
        amount: double.parse(_amount.text.trim()),
        expenseDate: _date,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: FormSheet(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Add an expense',
        subtitle: 'Running costs for this property',
        children: [
          if (_error != null) ...[
            AppMessageBanner(
              icon: Icons.error_outline_rounded,
              message: _error!,
              color: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: ExpenseCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: _saving
                ? null
                : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Description is required'
                : null,
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
            validator: (v) {
              final amount = double.tryParse(v?.trim() ?? '');
              return amount == null || amount <= 0
                  ? 'Enter an amount greater than 0'
                  : null;
            },
          ),
          const SizedBox(height: 13),
          PickerField(
            label: 'Date',
            value: DateFormat('d MMM yyyy').format(_date),
            icon: Icons.event_outlined,
            onTap: _saving ? null : _pickDate,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Add expense'),
          ),
        ],
      ),
    );
  }
}
