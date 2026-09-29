import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import 'auth_state.dart';
import 'auth_widgets.dart';
import 'firebase_phone_auth.dart';

class OwnerPhoneLoginScreen extends StatefulWidget {
  const OwnerPhoneLoginScreen({super.key});

  @override
  State<OwnerPhoneLoginScreen> createState() => _OwnerPhoneLoginScreenState();
}

class _OwnerPhoneLoginScreenState extends State<OwnerPhoneLoginScreen> {
  final _phoneKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _codeError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _send({bool resend = false}) async {
    if (_loading || !_phoneKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().requestStudentOtp(
            phone: _phone.text.trim(),
            resend: resend,
          );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _code.clear();
        _codeError = null;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _codeFocus.requestFocus());
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FirebasePhoneAuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_loading) return;
    if (_code.text.trim().length != OtpCodeField.length) {
      setState(() => _codeError = 'Enter the complete 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().verifyOwnerOtp(
            code: _code.text.trim(),
            fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          );
      if (mounted) context.go('/owner');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FirebasePhoneAuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: authAppBar(leading: const AuthBackButton()),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Form(
            key: _phoneKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    eyebrow: 'PG OWNER CLAIM',
                    title: 'Verify your invited mobile',
                    subtitle:
                        'Use the owner mobile saved by hi pg. After OTP verification, you can claim the matched property and submit KYC.',
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    AppMessageBanner(
                      icon: Icons.error_outline,
                      message: _error!,
                      color: AppColors.danger,
                      background: AppColors.dangerSoft,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _name,
                    enabled: !_loading && !_codeSent,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Owner name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    enabled: !_loading && !_codeSent,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                      return digits.length < 10
                          ? 'Enter a valid mobile number'
                          : null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Invited mobile number',
                      prefixIcon: Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  if (!_codeSent) ...[
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _send,
                      child: Text(_loading ? 'Sending code...' : 'Send OTP'),
                    ),
                  ] else ...[
                    const SizedBox(height: 22),
                    OtpCodeField(
                      controller: _code,
                      focusNode: _codeFocus,
                      enabled: !_loading,
                      errorText: _codeError,
                      onChanged: (_) => setState(() => _codeError = null),
                      onCompleted: (_) => _verify(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _verify,
                      child: Text(
                          _loading ? 'Verifying...' : 'Verify and continue'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : () => _send(resend: true),
                      child: const Text('Resend code'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _codeSent = false;
                                _code.clear();
                              }),
                      child: const Text('Use a different number'),
                    ),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}
