import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import 'fee_models.dart';
import 'fee_repository.dart';

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

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

  Future<void> _openCreateSheet() async {
    final created = await showFormSheet<bool>(
      context,
      (_) => _FeeFormSheet(
          repository: _repository, studentId: widget.studentId),
    );
    if (created == true && mounted) _reload();
  }

  Future<void> _openRecordPaymentSheet(Fee fee) async {
    final recorded = await showFormSheet<bool>(
      context,
      (_) => _PaymentFormSheet(repository: _repository, fee: fee),
    );
    if (recorded == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment recorded. A receipt was generated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Fee>>(
      future: _future,
      builder: (context, snapshot) {
        final fees = snapshot.data ?? const <Fee>[];
        final ready = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fees'),
                if (widget.studentName != null)
                  Text(widget.studentName!,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          floatingActionButton: ready && fees.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _openCreateSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add fee'),
                )
              : null,
          body: _buildBody(snapshot, fees),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<List<Fee>> snapshot, List<Fee> fees) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingView(label: 'Loading fees...');
    }
    if (snapshot.hasError) {
      final message = snapshot.error is ApiException
          ? (snapshot.error as ApiException).message
          : 'Fees could not be loaded.';
      return AppErrorView(message: message, onRetry: _reload);
    }
    if (fees.isEmpty) {
      return AppEmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'No fees yet',
        message:
            'Add a monthly fee to start tracking what is due and what has been paid.',
        actionLabel: 'Add fee',
        actionIcon: Icons.add_rounded,
        onAction: _openCreateSheet,
      );
    }
    final outstanding = fees.fold<double>(0, (sum, fee) => sum + fee.balance);
    final collected = fees.fold<double>(0, (sum, fee) => sum + fee.amountPaid);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 100),
        itemCount: fees.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _BalanceSummary(
                outstanding: outstanding, collected: collected);
          }
          final fee = fees[index - 1];
          return _FeeCard(
            fee: fee,
            onRecordPayment: () => _openRecordPaymentSheet(fee),
          );
        },
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  final double outstanding;
  final double collected;

  const _BalanceSummary({required this.outstanding, required this.collected});

  @override
  Widget build(BuildContext context) {
    Widget value(String label, String amount) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .62),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(amount,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          value('Outstanding', _money.format(outstanding)),
          Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withValues(alpha: .14),
          ),
          value('Collected', _money.format(collected)),
        ],
      ),
    );
  }
}

(String, StatusTone) _feeStatus(Fee fee) {
  if (fee.overdue) return ('Overdue', StatusTone.danger);
  return switch (fee.status) {
    FeeStatus.paid => (fee.status.label, StatusTone.success),
    FeeStatus.partiallyPaid => (fee.status.label, StatusTone.dark),
    FeeStatus.pending => (fee.status.label, StatusTone.warning),
  };
}

class _FeeCard extends StatelessWidget {
  final Fee fee;
  final VoidCallback onRecordPayment;

  const _FeeCard({required this.fee, required this.onRecordPayment});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = _feeStatus(fee);
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(fee.periodYear, fee.periodMonth));
    final progress =
        fee.amount <= 0 ? 0.0 : (fee.amountPaid / fee.amount).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.calendar_month_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(month,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                          'Due ${DateFormat('d MMM yyyy').format(fee.dueDate)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(label: statusLabel, tone: tone),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Amount(label: 'Fee', value: _money.format(fee.amount)),
                _Amount(
                    label: 'Paid',
                    value: _money.format(fee.amountPaid),
                    color: AppColors.success),
                _Amount(
                  label: 'Balance',
                  value: _money.format(fee.balance),
                  color: fee.balance > 0 ? AppColors.warning : AppColors.ink,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: AppColors.success,
              ),
            ),
            if (fee.payments.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text('Payments', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              for (final payment in fee.payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        '${_money.format(payment.amountPaid)} · ${payment.method.label}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(DateFormat('d MMM yyyy').format(payment.paidOn),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
            if (fee.status != FeeStatus.paid) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRecordPayment,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Record payment'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Amount({
    required this.label,
    required this.value,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 14.5)),
          ),
        ],
      ),
    );
  }
}

class _FeeFormSheet extends StatefulWidget {
  final FeeRepository repository;
  final String studentId;

  const _FeeFormSheet({required this.repository, required this.studentId});

  @override
  State<_FeeFormSheet> createState() => _FeeFormSheetState();
}

class _FeeFormSheetState extends State<_FeeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late int _month;
  late final TextEditingController _year;
  late DateTime _dueDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = TextEditingController(text: '${now.year}');
    _dueDate = DateTime(now.year, now.month, 10);
  }

  @override
  void dispose() {
    _amount.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Fee due date',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.create(
        studentId: widget.studentId,
        periodMonth: _month,
        periodYear: int.parse(_year.text.trim()),
        amount: double.parse(_amount.text.trim()),
        dueDate: _dueDate,
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
        icon: Icons.receipt_long_rounded,
        title: 'Add a fee',
        subtitle: 'Monthly rent or a one-off charge',
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat('MMMM').format(DateTime(2000, m))),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _month = value ?? _month),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _year,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                  validator: (v) {
                    final year = int.tryParse(v?.trim() ?? '');
                    return year == null || year < 2000 ? 'Invalid' : null;
                  },
                ),
              ),
            ],
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
            label: 'Due date',
            value: DateFormat('d MMM yyyy').format(_dueDate),
            icon: Icons.event_outlined,
            onTap: _saving ? null : _pickDueDate,
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
                : const Text('Add fee'),
          ),
        ],
      ),
    );
  }
}

class _PaymentFormSheet extends StatefulWidget {
  final FeeRepository repository;
  final Fee fee;

  const _PaymentFormSheet({required this.repository, required this.fee});

  @override
  State<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<_PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount =
      TextEditingController(text: widget.fee.balance.toStringAsFixed(2));
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.recordPayment(
        feeId: widget.fee.id,
        amountPaid: double.parse(_amount.text.trim()),
        paidOn: DateTime.now(),
        method: _method,
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
    final fee = widget.fee;
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(fee.periodYear, fee.periodMonth));
    return Form(
      key: _formKey,
      child: FormSheet(
        icon: Icons.payments_rounded,
        title: 'Record payment',
        subtitle: '$month · ${_money.format(fee.balance)} due',
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
          TextFormField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount received',
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
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _method,
            decoration: const InputDecoration(
              labelText: 'Method',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: PaymentMethod.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _method = value ?? _method),
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
                : const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}
