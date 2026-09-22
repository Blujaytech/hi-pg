import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../shared/app_states.dart';
import '../booking/booking_models.dart';
import 'customer_profile_models.dart';
import 'customer_profile_repository.dart';

class CustomerProfileScreen extends StatefulWidget {
  final BookingType? requiredFor;

  const CustomerProfileScreen({super.key, this.requiredFor});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _repository = CustomerProfileRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _occupationController = TextEditingController();
  final _addressController = TextEditingController();
  final _identityLast4Controller = TextEditingController();

  CustomerProfile? _profile;
  IdentityType? _identityType;
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _acceptAadhaarConsent = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _monthlyRequired => widget.requiredFor == BookingType.monthly;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _occupationController.dispose();
    _addressController.dispose();
    _identityLast4Controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repository.getMine();
      if (!mounted) return;
      _applyProfile(profile);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'Your profile could not be loaded.';
      });
    }
  }

  void _applyProfile(CustomerProfile profile) {
    _profile = profile;
    _nameController.text = profile.fullName;
    _occupationController.text = profile.occupation;
    _addressController.text = profile.permanentAddress ?? '';
    _identityType = profile.identityType;
    _identityLast4Controller.text = profile.identityLast4 ?? '';
    _acceptTerms = profile.termsAcceptedVersion != null;
    _acceptPrivacy = profile.privacyAcceptedVersion != null;
    _acceptAadhaarConsent = profile.aadhaarConsentVersion != null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms || !_acceptPrivacy) {
      setState(() => _error =
          'Accept the Terms of Service and Privacy Policy to continue.');
      return;
    }
    if (_monthlyRequired && !_hasMonthlyDetails()) {
      setState(() => _error =
          'Permanent address and a government ID ending are required for monthly bookings.');
      return;
    }
    if (_identityType == IdentityType.aadhaar && !_acceptAadhaarConsent) {
      setState(() => _error =
          'Aadhaar use requires the separate, specific consent below. You can choose another government ID instead.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repository.save(
        fullName: _nameController.text,
        occupation: _occupationController.text,
        permanentAddress: _addressController.text,
        identityType: _identityType,
        identityLast4: _identityLast4Controller.text,
        acceptTerms: _acceptTerms,
        acceptPrivacy: _acceptPrivacy,
        acceptAadhaarConsent:
            _identityType == IdentityType.aadhaar && _acceptAadhaarConsent,
      );
      if (!mounted) return;
      setState(() => _applyProfile(saved));

      if (widget.requiredFor != null) {
        final eligibility = await _repository.eligibility(widget.requiredFor!);
        if (!mounted) return;
        if (eligibility.eligible) {
          context.pop(true);
          return;
        }
        setState(() => _error = eligibility.missingRequirements
            .map((requirement) => requirement.label)
            .join('\n'));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved securely.')),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your profile could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _hasMonthlyDetails() =>
      _addressController.text.trim().isNotEmpty &&
      _identityType != null &&
      RegExp(r'^[A-Za-z0-9]{4}$')
          .hasMatch(_identityLast4Controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.requiredFor == null
            ? 'Profile & verification'
            : 'Complete your profile'),
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading your profile...')
          : _error != null && _profile == null
              ? AppErrorView(message: _error!, onRetry: _load)
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: [
          if (widget.requiredFor != null) ...[
            AppMessageBanner(
              icon: Icons.verified_user_outlined,
              message: widget.requiredFor == BookingType.monthly
                  ? 'Monthly stays need your permanent address and a government ID ending.'
                  : 'Complete your basic profile to book a day-wise stay.',
            ),
            const SizedBox(height: 20),
          ],
          if (_error != null) ...[
            AppMessageBanner(
              icon: Icons.error_outline_rounded,
              message: _error!,
              color: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
            const SizedBox(height: 20),
          ],
          _SectionCard(
            title: 'About you',
            subtitle: 'Use the same name shown on your ID.',
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Full legal name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Enter your full name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _occupationController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Profession or occupation',
                  hintText: 'Student, software engineer, business…',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Enter your profession or occupation'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'For monthly stays',
            subtitle:
                'Not required for day-wise bookings. We never ask for or store your complete Aadhaar number.',
            children: [
              TextFormField(
                controller: _addressController,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Permanent address',
                  prefixIcon: Icon(Icons.home_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    _monthlyRequired && (value ?? '').trim().length < 8
                        ? 'Enter your complete permanent address'
                        : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<IdentityType>(
                initialValue: _identityType,
                decoration: const InputDecoration(
                  labelText: 'Government ID type',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: IdentityType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _identityType = value;
                          if (value != IdentityType.aadhaar) {
                            _acceptAadhaarConsent = false;
                          }
                        }),
                validator: (value) => _monthlyRequired && value == null
                    ? 'Choose a government ID type'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _identityLast4Controller,
                enabled: !_saving && _identityType != null,
                maxLength: 4,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Last 4 characters only',
                  helperText: 'Do not enter the complete ID number.',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) {
                  if (!_monthlyRequired && _identityType == null) return null;
                  return RegExp(r'^[A-Za-z0-9]{4}$')
                          .hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter exactly the last 4 characters';
                },
              ),
              if (_identityType == IdentityType.aadhaar) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _acceptAadhaarConsent,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _acceptAadhaarConsent = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('I consent to Aadhaar detail use'),
                  subtitle: const Text(
                    'Only the final four digits are stored to identify the document used for monthly-stay verification. You may choose another ID.',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Agreements',
            subtitle:
                'Your acceptance is recorded with the current document versions.',
            children: [
              CheckboxListTile(
                value: _acceptTerms,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _acceptTerms = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I accept the Terms of Service'),
                subtitle: const Text(
                    'Includes booking, cancellation, direct-payment, and house-rule responsibilities.'),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _acceptPrivacy,
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _acceptPrivacy = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I accept the Privacy Policy'),
                subtitle: const Text(
                    'Explains why profile data is collected, who can see it, and retention and deletion choices.'),
              ),
            ],
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
                : const Icon(Icons.shield_outlined),
            label: Text(_saving
                ? 'Saving securely...'
                : widget.requiredFor == null
                    ? 'Save profile'
                    : 'Save & continue booking'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}
