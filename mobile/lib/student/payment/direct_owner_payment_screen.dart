import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../../shared/direct_payment/direct_payment_models.dart';
import 'direct_payment_repository.dart';

class DirectOwnerPaymentScreen extends StatefulWidget {
  final String bookingId;
  final bool selectBeforeLoad;

  const DirectOwnerPaymentScreen({
    super.key,
    required this.bookingId,
    this.selectBeforeLoad = false,
  });

  @override
  State<DirectOwnerPaymentScreen> createState() =>
      _DirectOwnerPaymentScreenState();
}

class _DirectOwnerPaymentScreenState extends State<DirectOwnerPaymentScreen> {
  final _repository = DirectPaymentRepository();
  final _referenceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _idempotencyKey = DirectPaymentRepository.newIdempotencyKey();

  DirectPaymentDetails? _details;
  DirectPaymentRequest? _request;
  bool _loading = true;
  bool _submitting = false;
  bool _paymentConfirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = widget.selectBeforeLoad
          ? await _repository.selectDirectPayment(widget.bookingId)
          : await _repository.details(widget.bookingId);
      DirectPaymentRequest? request;
      try {
        request = await _repository.currentRequest(widget.bookingId);
      } on ApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      if (!mounted) return;
      setState(() {
        _details = details;
        _request = request;
        _loading = false;
        if (request != null) {
          _referenceController.text = request.transactionReference;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Payment details could not be loaded.';
      });
    }
  }

  Future<void> _copyUpiId() async {
    await Clipboard.setData(ClipboardData(text: _details!.upiId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID copied.')),
      );
    }
  }

  Future<void> _openUpi() async {
    final details = _details!;
    Uri? uri = Uri.tryParse(details.upiUri);
    if (uri == null || uri.scheme.toLowerCase() != 'upi') {
      uri = Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': details.upiId,
          'pn': details.ownerName,
          'am': details.amount.toStringAsFixed(2),
          'cu': details.currency,
          'tn': 'Hi PG booking ${details.bookingId}',
        },
      );
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No UPI app could be opened. Copy the UPI ID and pay from your preferred app.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No UPI app could be opened. Copy the UPI ID and pay manually.'),
          ),
        );
      }
    }
  }

  Future<void> _informOwner() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_paymentConfirmed) {
      setState(() => _error =
          'Confirm that the payment succeeded in your UPI app before informing the owner.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final request = await _repository.informOwner(
        bookingId: widget.bookingId,
        transactionReference: _referenceController.text,
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      setState(() => _request = request);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Owner informed. Your bed will be allocated only after payment verification.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'The owner could not be informed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay owner directly')),
      body: _loading
          ? const AppLoadingView(label: 'Loading payment details...')
          : _details == null
              ? AppErrorView(
                  message: _error ?? 'Payment details are unavailable.',
                  onRetry: _load,
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final details = _details!;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: details.currency == 'INR' ? '₹' : '${details.currency} ',
    );
    final request = _request;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
      children: [
        if (_error != null) ...[
          AppMessageBanner(
            icon: Icons.error_outline_rounded,
            message: _error!,
            color: AppColors.danger,
            background: AppColors.dangerSoft,
          ),
          const SizedBox(height: 16),
        ],
        if (request != null) ...[
          _RequestStatusCard(request: request),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const IconTile(
                      icon: Icons.account_balance_outlined,
                      size: 46,
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PG owner payment details',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('Configured for this PG booking',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DetailRow(label: 'Owner name', value: details.ownerName),
                const Divider(height: 22),
                _DetailRow(label: 'UPI ID', value: details.upiId),
                const Divider(height: 22),
                _DetailRow(
                    label: 'Mobile',
                    value: details.maskedMobile.isEmpty
                        ? 'Not shared'
                        : details.maskedMobile),
                const Divider(height: 22),
                _DetailRow(
                  label: 'Exact amount',
                  value: money.format(details.amount),
                  important: true,
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _copyUpiId,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy UPI ID'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: request == null ? _openUpi : null,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Pay via UPI'),
                ),
                if (details.paymentHoldExpiresAt != null &&
                    request == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Complete and report payment before ${DateFormat('d MMM, h:mm a').format(details.paymentHoldExpiresAt!.toLocal())}.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (request == null)
          _buildConfirmationForm(money, details)
        else ...[
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to my bookings'),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmationForm(
      NumberFormat money, DirectPaymentDetails details) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('After completing payment',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(
                'Check your UPI app for a successful payment, then enter its transaction reference. A screenshot or reference alone is not proof of payment.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _referenceController,
                enabled: !_submitting,
                textCapitalization: TextCapitalization.characters,
                maxLength: 40,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'UPI transaction reference / UTR',
                  hintText: 'Enter the reference from your UPI app',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  counterText: '',
                ),
                validator: (value) => RegExp(r'^[A-Za-z0-9-]{6,40}$')
                        .hasMatch((value ?? '').trim())
                    ? null
                    : 'Enter a valid transaction reference',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _paymentConfirmed,
                onChanged: _submitting
                    ? null
                    : (value) =>
                        setState(() => _paymentConfirmed = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                    'I paid ${money.format(details.amount)} to ${details.ownerName}'),
                subtitle: const Text(
                    'I understand the owner must verify receipt before the bed is allocated.'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _informOwner,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(_submitting
                    ? 'Informing owner...'
                    : 'I Have Paid – Inform Owner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestStatusCard extends StatelessWidget {
  final DirectPaymentRequest request;

  const _RequestStatusCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final (icon, color, background, message) = switch (request.status) {
      DirectPaymentRequestStatus.pending => (
          Icons.hourglass_top_rounded,
          AppColors.warning,
          AppColors.warningSoft,
          'The owner has been notified. Your booking is not confirmed until they verify the payment.'
        ),
      DirectPaymentRequestStatus.approved => (
          Icons.check_circle_outline_rounded,
          AppColors.success,
          AppColors.successSoft,
          'The owner verified your payment and approved the booking.'
        ),
      DirectPaymentRequestStatus.rejected => (
          Icons.cancel_outlined,
          AppColors.danger,
          AppColors.dangerSoft,
          request.rejectionReason == null
              ? 'The owner could not verify this payment.'
              : 'The owner could not verify this payment: ${request.rejectionReason}'
        ),
      _ => (
          Icons.info_outline_rounded,
          AppColors.muted,
          AppColors.fill,
          request.status.label
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.status.label,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(message,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: color)),
                if (request.transactionReference.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reference: ${request.transactionReference}',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool important;

  const _DetailRow({
    required this.label,
    required this.value,
    this.important = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: important ? 18 : 14,
              fontWeight: important ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
