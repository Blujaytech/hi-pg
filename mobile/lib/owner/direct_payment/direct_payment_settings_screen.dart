import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../../shared/direct_payment/direct_payment_models.dart';
import '../pg/pg_models.dart';
import 'direct_payment_repository.dart';

class DirectPaymentSettingsScreen extends StatefulWidget {
  final String pgId;
  final Pg? pg;

  const DirectPaymentSettingsScreen({
    super.key,
    required this.pgId,
    this.pg,
  });

  @override
  State<DirectPaymentSettingsScreen> createState() =>
      _DirectPaymentSettingsScreenState();
}

class _DirectPaymentSettingsScreenState
    extends State<DirectPaymentSettingsScreen> {
  final _repository = OwnerDirectPaymentRepository();
  final _formKey = GlobalKey<FormState>();
  final _beneficiaryController = TextEditingController();
  final _upiController = TextEditingController();
  final _mobileController = TextEditingController();

  DirectPaymentSettings? _settings;
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    _upiController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _repository.getSettings(widget.pgId);
      if (!mounted) return;
      _apply(settings);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Direct-payment settings could not be loaded.';
      });
    }
  }

  void _apply(DirectPaymentSettings settings) {
    _settings = settings;
    _enabled = settings.enabled;
    _beneficiaryController.text = settings.beneficiaryName;
    _upiController.text = settings.upiId;
    _mobileController.text = settings.mobileNumber;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await _repository.saveSettings(
        pgId: widget.pgId,
        enabled: _enabled,
        beneficiaryName: _beneficiaryController.text,
        upiId: _upiController.text,
        mobileNumber: _mobileController.text,
      );
      if (!mounted) return;
      setState(() => _apply(settings));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.enabled
              ? 'Direct owner payments are enabled.'
              : 'Direct owner payments are disabled.'),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct payment settings'),
        actions: [
          IconButton(
            tooltip: 'Payment requests',
            onPressed: () => context.push(
              '/owner/pgs/${widget.pgId}/payment-requests',
              extra: widget.pg,
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading payment settings...')
          : _settings == null
              ? AppErrorView(
                  message: _error ?? 'Payment settings are unavailable.',
                  onRetry: _load,
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final verified = _settings!.verified;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: verified ? AppColors.successSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  verified
                      ? Icons.verified_user_rounded
                      : Icons.policy_outlined,
                  color: verified ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verified
                            ? 'Owner checks complete'
                            : 'Verification required',
                        style: TextStyle(
                          color:
                              verified ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        verified
                            ? 'Your phone and PG KYC checks are complete. Customers see this owner-declared UPI ID only after creating a booking hold.'
                            : 'Your owner phone and PG KYC must be verified before direct payments can be enabled.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: verified
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppMessageBanner(
              icon: Icons.error_outline_rounded,
              message: _error!,
              color: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.pg?.name ?? 'Property payment account',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Use a UPI ID whose beneficiary name you can verify in your UPI app.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _beneficiaryController,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Beneficiary name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Enter the bank account beneficiary name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _upiController,
                    enabled: !_saving,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      hintText: 'name@bank',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z0-9.-]{2,64}$')
                                .hasMatch((value ?? '').trim())
                            ? null
                            : 'Enter a valid UPI ID such as name@bank',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _mobileController,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Payment support mobile',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => RegExp(r'^\+?[0-9]{10,13}$').hasMatch(
                            (value ?? '').replaceAll(RegExp(r'[\s-]'), ''))
                        ? null
                        : 'Enter a valid mobile number',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _enabled = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow direct owner payments'),
                    subtitle: const Text(
                      'Customers can send UPI payment and request your verification. A bed is never allocated until you approve.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save payment settings'),
          ),
        ],
      ),
    );
  }
}
