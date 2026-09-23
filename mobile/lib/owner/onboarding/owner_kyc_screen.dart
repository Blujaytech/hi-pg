import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../pg/pg_models.dart';
import 'owner_kyc_models.dart';
import 'owner_onboarding_repository.dart';

class OwnerKycScreen extends StatefulWidget {
  final String pgId;
  final Pg? pg;

  const OwnerKycScreen({super.key, required this.pgId, this.pg});

  @override
  State<OwnerKycScreen> createState() => _OwnerKycScreenState();
}

class _OwnerKycScreenState extends State<OwnerKycScreen> {
  final _repository = OwnerOnboardingRepository();
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _legalName = TextEditingController();
  final _pan = TextEditingController();
  final _aadhaar = TextEditingController();
  OwnerKycSubmission? _kyc;
  bool _phoneVerifiedInSession = false;
  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _locked =>
      _kyc?.status == OwnerKycStatus.submitted ||
      _kyc?.status == OwnerKycStatus.verified;
  bool get _phoneVerified =>
      _phoneVerifiedInSession || (_kyc?.verifiedPhone ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _legalName.dispose();
    _pan.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kyc = await _repository.getKyc(widget.pgId);
      if (!mounted) return;
      _setKyc(kyc);
    } catch (error) {
      if (mounted) _error = _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setKyc(OwnerKycSubmission? value) {
    _kyc = value;
    if (value != null) {
      _phone.text = value.verifiedPhone ?? '';
      _legalName.text = value.legalName;
      _pan.text = value.panLastFour;
      _aadhaar.text = value.aadhaarLastFour;
    }
    setState(() {});
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  Future<void> _verifyPhone() async {
    final phone = _phone.text.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10 to 15 digit mobile number.');
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _repository.requestPhoneOtp(phone);
      if (!mounted) return;
      final code = await _askForOtp();
      if (code == null || !mounted) return;
      await _repository.verifyPhoneOtp(phone, code);
      if (!mounted) return;
      setState(() => _phoneVerifiedInSession = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner mobile number verified.')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _askForOtp() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify owner mobile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'OTP code',
            helperText: 'Enter the code sent to the owner mobile.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final updated = await _repository.saveProfile(
        pgId: widget.pgId,
        legalName: _legalName.text,
        panLastFour: _pan.text,
        aadhaarLastFour: _aadhaar.text,
      );
      _setKyc(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('KYC details saved. Upload the documents below.')),
        );
      }
    });
  }

  Future<void> _upload(OwnerKycDocumentType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024) {
      setState(() => _error = 'Each KYC document must be 10 MB or smaller.');
      return;
    }
    await _run(() async {
      _setKyc(await _repository.uploadDocument(
        pgId: widget.pgId,
        type: type,
        file: file,
      ));
    });
  }

  Future<void> _submit() async {
    if (_kyc?.hasAllDocuments != true) {
      setState(() =>
          _error = 'Upload all five required documents before submitting.');
      return;
    }
    await _run(() async {
      _setKyc(await _repository.submit(widget.pgId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC submitted for admin review.')),
        );
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner & PG verification')),
      body: _loading
          ? const AppLoadingView(label: 'Loading verification...')
          : RefreshIndicator(
              onRefresh: _load,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
                  children: [
                    _statusCard(),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      AppMessageBanner(
                        icon: Icons.error_outline_rounded,
                        message: _error!,
                        color: AppColors.danger,
                        background: AppColors.dangerSoft,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _detailsCard(),
                    if (_kyc != null) ...[
                      const SizedBox(height: 16),
                      _documentsCard(),
                    ],
                    const SizedBox(height: 16),
                    _phoneCard(),
                    const SizedBox(height: 16),
                    const AppMessageBanner(
                      icon: Icons.lock_outline_rounded,
                      message:
                          'Data storage: legal name and only the last 4 PAN/Aadhaar characters are stored in PostgreSQL. Document files are kept in a private object-storage bucket; admins receive time-limited links for review.',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statusCard() {
    final status = _kyc?.status;
    final (title, message, color, background, icon) = switch (status) {
      OwnerKycStatus.submitted => (
          'Awaiting admin review',
          'Your documents are locked until the administrator approves or returns them.',
          AppColors.warning,
          AppColors.warningSoft,
          Icons.hourglass_top_rounded,
        ),
      OwnerKycStatus.verified => (
          'KYC verified',
          'This PG can now enable direct owner UPI payments.',
          AppColors.success,
          AppColors.successSoft,
          Icons.verified_user_rounded,
        ),
      OwnerKycStatus.rejected => (
          'Changes required',
          _kyc?.reviewNote ?? 'Update the requested details and submit again.',
          AppColors.danger,
          AppColors.dangerSoft,
          Icons.warning_amber_rounded,
        ),
      _ => (
          'Complete verification',
          'Save KYC details, upload all documents, then submit. Mobile OTP is optional.',
          AppColors.ink,
          AppColors.fill,
          Icons.fact_check_outlined,
        ),
    };
    return AppMessageBanner(
      icon: icon,
      message: '$title\n$message',
      color: color,
      background: background,
    );
  }

  Widget _phoneCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Owner mobile OTP (optional)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              const Text(
                  'You can skip this for now. KYC can be saved and submitted without mobile verification.'),
              const SizedBox(height: 14),
              TextField(
                controller: _phone,
                enabled: !_working && !_phoneVerified,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Owner mobile number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: _phoneVerified
                      ? const Icon(Icons.verified_rounded,
                          color: AppColors.success)
                      : null,
                ),
              ),
              if (!_phoneVerified) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _working ? null : _verifyPhone,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send OTP and verify'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _detailsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('1. Owner KYC details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(widget.pg?.name ?? _kyc?.pgName ?? 'Selected PG'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _legalName,
                enabled: !_working && !_locked,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Legal name'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the legal name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pan,
                enabled: !_working && !_locked,
                textCapitalization: TextCapitalization.characters,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))
                ],
                decoration:
                    const InputDecoration(labelText: 'PAN last 4 characters'),
                validator: (value) =>
                    RegExp(r'^[A-Za-z0-9]{4}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'Enter exactly 4 characters',
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _aadhaar,
                enabled: !_working && !_locked,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: 'Aadhaar last 4 digits'),
                validator: (value) =>
                    RegExp(r'^\d{4}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'Enter exactly 4 digits',
              ),
              if (!_locked) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _working ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                      _kyc == null ? 'Save and continue' : 'Save KYC details'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _documentsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('2. Required documents',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              const Text('JPG, PNG or PDF. Maximum 10 MB per file.'),
              const SizedBox(height: 10),
              for (final type in OwnerKycDocumentType.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _kyc!.hasDocument(type)
                        ? Icons.check_circle_rounded
                        : Icons.upload_file_outlined,
                    color: _kyc!.hasDocument(type) ? AppColors.success : null,
                  ),
                  title: Text(type.label),
                  subtitle: Text(_kyc!.documents
                          .where((document) => document.type == type)
                          .map((document) => document.fileName)
                          .firstOrNull ??
                      'Not uploaded'),
                  trailing: _locked
                      ? null
                      : TextButton(
                          onPressed: _working ? null : () => _upload(type),
                          child: Text(
                              _kyc!.hasDocument(type) ? 'Replace' : 'Upload'),
                        ),
                ),
              if (!_locked) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _working || !_kyc!.hasAllDocuments ? null : _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit for admin review'),
                ),
              ],
            ],
          ),
        ),
      );
}
