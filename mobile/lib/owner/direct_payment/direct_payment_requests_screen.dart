import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../../shared/direct_payment/direct_payment_models.dart';
import '../../student/booking/booking_models.dart';
import '../pg/pg_models.dart';
import 'direct_payment_repository.dart';

class DirectPaymentRequestsScreen extends StatefulWidget {
  final String? pgId;
  final String? bookingId;
  final Pg? pg;

  const DirectPaymentRequestsScreen({
    super.key,
    this.pgId,
    this.bookingId,
    this.pg,
  });

  @override
  State<DirectPaymentRequestsScreen> createState() =>
      _DirectPaymentRequestsScreenState();
}

class _DirectPaymentRequestsScreenState
    extends State<DirectPaymentRequestsScreen> {
  final _repository = OwnerDirectPaymentRepository();
  late Future<List<DirectPaymentRequest>> _future;
  DirectPaymentRequestStatus _status = DirectPaymentRequestStatus.pending;
  String? _actingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DirectPaymentRequest>> _load() async {
    if (widget.bookingId == null) {
      return _repository.list(status: _status, pgId: widget.pgId);
    }
    final openRequests = await Future.wait([
      _repository.list(
          status: DirectPaymentRequestStatus.pending, pgId: widget.pgId),
      _repository.list(
          status: DirectPaymentRequestStatus.reviewOverdue, pgId: widget.pgId),
    ]);
    return openRequests
        .expand((requests) => requests)
        .where((request) => request.bookingId == widget.bookingId)
        .toList();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _refresh() async {
    _reload();
    try {
      await _future;
    } catch (_) {
      // FutureBuilder renders the error.
    }
  }

  void _changeStatus(DirectPaymentRequestStatus status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _future = _load();
    });
  }

  Future<void> _approve(DirectPaymentRequest request) async {
    final input = await showDialog<_ApprovalInput>(
      context: context,
      builder: (_) => _ApprovePaymentDialog(request: request),
    );
    if (input == null || !mounted) return;
    setState(() => _actingId = request.id);
    try {
      await _repository.approve(
        requestId: request.id,
        amountReceived: input.amount,
        note: input.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${request.customerName}’s payment was verified and the booking approved.'),
        ),
      );
      if (widget.bookingId != null) {
        Navigator.of(context).pop(true);
      } else {
        _reload();
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  Future<void> _reject(DirectPaymentRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectPaymentDialog(request: request),
    );
    if (reason == null || !mounted) return;
    setState(() => _actingId = request.id);
    try {
      await _repository.reject(requestId: request.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request rejected.')),
      );
      if (widget.bookingId != null) {
        Navigator.of(context).pop(true);
      } else {
        _reload();
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.bookingId == null
                ? 'Direct payment requests'
                : 'Review customer payment'),
            if (widget.pg != null)
              Text(widget.pg!.name,
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (widget.pgId != null)
            IconButton(
              tooltip: 'Direct payment settings',
              onPressed: () => context.push(
                '/owner/pgs/${widget.pgId}/direct-payment-settings',
                extra: widget.pg,
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.bookingId == null) ...[
            _StatusFilter(selected: _status, onSelected: _changeStatus),
            const Divider(height: 1),
          ],
          Expanded(
            child: FutureBuilder<List<DirectPaymentRequest>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingView(
                      label: 'Loading payment requests...');
                }
                if (snapshot.hasError) {
                  final message = snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Payment requests could not be loaded.';
                  return AppErrorView(message: message, onRetry: _reload);
                }
                final requests = snapshot.data ?? const [];
                if (requests.isEmpty) {
                  return AppEmptyView(
                    icon: widget.bookingId != null
                        ? Icons.info_outline_rounded
                        : _status == DirectPaymentRequestStatus.pending
                            ? Icons.verified_outlined
                            : Icons.receipt_long_outlined,
                    title: widget.bookingId != null
                        ? 'No payment awaiting review'
                        : _status == DirectPaymentRequestStatus.pending
                            ? 'No payments awaiting review'
                            : 'No ${_status.label.toLowerCase()} requests',
                    message: widget.bookingId != null
                        ? 'This request may already have been approved or rejected. Go back and refresh the customer list.'
                        : _status == DirectPaymentRequestStatus.pending
                            ? 'New direct UPI payment claims will appear here. Always verify your bank account before approving.'
                            : 'Choose another status to view its requests.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final request = requests[index];
                      return _RequestCard(
                        request: request,
                        busy: _actingId == request.id,
                        onApprove: request.status ==
                                    DirectPaymentRequestStatus.pending ||
                                request.status ==
                                    DirectPaymentRequestStatus.reviewOverdue
                            ? () => _approve(request)
                            : null,
                        onReject: request.status ==
                                    DirectPaymentRequestStatus.pending ||
                                request.status ==
                                    DirectPaymentRequestStatus.reviewOverdue
                            ? () => _reject(request)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final DirectPaymentRequestStatus selected;
  final ValueChanged<DirectPaymentRequestStatus> onSelected;

  const _StatusFilter({required this.selected, required this.onSelected});

  static const statuses = [
    DirectPaymentRequestStatus.pending,
    DirectPaymentRequestStatus.reviewOverdue,
    DirectPaymentRequestStatus.approved,
    DirectPaymentRequestStatus.rejected,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final status = statuses[index];
          return ChoiceChip(
            label: Text(status == DirectPaymentRequestStatus.pending
                ? 'Pending'
                : status.label),
            selected: selected == status,
            onSelected: (_) => onSelected(status),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DirectPaymentRequest request;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: request.currency == 'INR' ? '₹' : '${request.currency} ',
    );
    final statusTone = switch (request.status) {
      DirectPaymentRequestStatus.approved => StatusTone.success,
      DirectPaymentRequestStatus.rejected => StatusTone.danger,
      DirectPaymentRequestStatus.pending ||
      DirectPaymentRequestStatus.reviewOverdue =>
        StatusTone.warning,
      _ => StatusTone.neutral,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(
                    icon: Icons.account_balance_wallet_outlined, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.customerName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${request.pgName} · Room ${request.roomNumber}, ${request.bedLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusPill(label: request.status.label, tone: statusTone),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _ValueRow(
                      label: 'Expected amount',
                      value: money.format(request.quotedAmount),
                      important: true),
                  const SizedBox(height: 9),
                  _ValueRow(
                      label: 'UPI reference',
                      value: request.transactionReference),
                  const SizedBox(height: 9),
                  _ValueRow(label: 'Booking', value: request.bookingType.label),
                  const SizedBox(height: 9),
                  _ValueRow(
                    label: 'Check-in',
                    value: DateFormat('d MMM yyyy').format(request.checkInDate),
                  ),
                  if (request.maskedCustomerPhone.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    _ValueRow(
                        label: 'Customer', value: request.maskedCustomerPhone),
                  ],
                ],
              ),
            ),
            if (request.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Text('Reason: ${request.rejectionReason}',
                  style: const TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w600)),
            ],
            if (request.confirmedAmount != null) ...[
              const SizedBox(height: 12),
              Text(
                  'Confirmed received: ${money.format(request.confirmedAmount)}',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.w700)),
            ],
            if (onApprove != null && onReject != null) ...[
              const SizedBox(height: 15),
              const AppMessageBanner(
                icon: Icons.security_rounded,
                message:
                    'Open your bank or UPI statement and match both the amount and reference. Do not approve from a screenshot alone.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onReject,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onApprove,
                      icon: busy
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: Text(busy ? 'Saving...' : 'Verify & approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool important;

  const _ValueRow({
    required this.label,
    required this.value,
    this.important = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: important ? FontWeight.w800 : FontWeight.w700,
              fontSize: important ? 16 : 13,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApprovalInput {
  final double amount;
  final String? note;

  const _ApprovalInput(this.amount, this.note);
}

class _ApprovePaymentDialog extends StatefulWidget {
  final DirectPaymentRequest request;

  const _ApprovePaymentDialog({required this.request});

  @override
  State<_ApprovePaymentDialog> createState() => _ApprovePaymentDialogState();
}

class _ApprovePaymentDialogState extends State<_ApprovePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();
  bool _checkedStatement = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.request.quotedAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_checkedStatement) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Confirm that you checked your statement.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _ApprovalInput(
        double.parse(_amountController.text.trim()),
        _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify payment & approve booking'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Match ${widget.request.transactionReference} in your bank or UPI statement. The booking price cannot be changed here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount actually received',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter the amount received';
                  }
                  if ((amount - widget.request.quotedAmount).abs() >= .005) {
                    return 'Amount must match ₹${widget.request.quotedAmount.toStringAsFixed(2)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLength: 250,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Internal note (optional)',
                  counterText: '',
                ),
              ),
              CheckboxListTile(
                value: _checkedStatement,
                onChanged: (value) =>
                    setState(() => _checkedStatement = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I verified this in my bank/UPI statement'),
                subtitle: const Text(
                    'Approving records the payment and allocates the bed.'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Approve booking')),
      ],
    );
  }
}

class _RejectPaymentDialog extends StatefulWidget {
  final DirectPaymentRequest request;

  const _RejectPaymentDialog({required this.request});

  @override
  State<_RejectPaymentDialog> createState() => _RejectPaymentDialogState();
}

class _RejectPaymentDialogState extends State<_RejectPaymentDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject payment request?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Explain why ${widget.request.transactionReference} could not be verified. The customer will see this reason.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 250,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Payment not found in statement',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.length < 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Enter a clear rejection reason.')),
              );
              return;
            }
            Navigator.pop(context, reason);
          },
          child: const Text('Reject request'),
        ),
      ],
    );
  }
}
