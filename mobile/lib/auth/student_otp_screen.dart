import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import 'auth_state.dart';
import 'auth_widgets.dart';
import 'google_owner_conflict.dart';
import 'google_student_sign_in.dart';

class StudentOtpScreen extends StatefulWidget {
  /// Where to return after sign-in: the PG a guest was booking from.
  /// Defaults to the customer home.
  final String? returnTo;

  const StudentOtpScreen({super.key, this.returnTo});

  @override
  State<StudentOtpScreen> createState() => _StudentOtpScreenState();
}

enum _Step { phone, code }

class _StudentOtpScreenState extends State<StudentOtpScreen> {
  static const _resendCooldown = 30;

  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeFocus = FocusNode();

  _Step _step = _Step.phone;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  String? _codeError;
  Timer? _resendTimer;
  int _resendIn = 0;

  bool get _busy => _loading || _googleLoading;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _requestOtp() async {
    if (_busy || !_phoneFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context
          .read<AuthState>()
          .requestStudentOtp(phone: _phoneController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = _Step.code;
        _codeError = null;
        _codeController.clear();
      });
      _startResendCountdown();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _codeFocus.requestFocus());
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_busy || _resendIn > 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context
          .read<AuthState>()
          .requestStudentOtp(phone: _phoneController.text.trim());
      if (!mounted) return;
      _codeController.clear();
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code is on its way.')));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    if (code.length != OtpCodeField.length) {
      setState(() => _codeError = 'Enter the complete 6-digit code');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().verifyStudentOtp(
            phone: _phoneController.text.trim(),
            code: code,
            fullName: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
          );
      _finishSignIn();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    var ownerGmail = false;
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().googleStudentLogin();
      _finishSignIn();
    } on GoogleStudentSignInCanceled {
      // Closing Google's account picker is a normal user action, not an error.
    } on GoogleStudentSignInFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ApiException catch (error) {
      if (isOwnerGmailConflict(error)) {
        ownerGmail = true;
      } else if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Google sign-in could not be completed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
    if (!ownerGmail || !mounted) return;
    final choice = await showOwnerGmailConflict(context);
    if (choice == OwnerGmailChoice.anotherGoogleAccount && mounted) {
      // Forget the owner account so Google shows its account picker again.
      await GoogleStudentSignIn.instance.signOut();
      if (mounted) await _signInWithGoogle();
    }
    // "Continue with mobile number" simply leaves them on this phone step.
  }

  void _finishSignIn() {
    if (!mounted) return;
    context.go(widget.returnTo ?? '/student');
  }

  void _changePhone() {
    _resendTimer?.cancel();
    setState(() {
      _step = _Step.phone;
      _error = null;
      _codeError = null;
      _resendIn = 0;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final onCodeStep = _step == _Step.code;
    return PopScope(
      // System back on the code step returns to the phone step instead of
      // leaving sign-in entirely.
      canPop: !onCodeStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _changePhone();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AuthBackButton(onPressed: onCodeStep ? _changePhone : null),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: AuthHeader(
                    key: ValueKey(_step),
                    eyebrow: 'Customer',
                    title:
                        onCodeStep ? 'Enter your code' : "What's your number?",
                    subtitle: onCodeStep
                        ? 'We sent a 6-digit code to ${_phoneController.text.trim()}.'
                        : widget.returnTo != null
                            ? "Verify your number to finish booking. We'll text you a 6-digit code."
                            : "We'll text you a 6-digit code to sign in or create your account.",
                  ),
                ),
                const SizedBox(height: 22),
                _StepProgress(step: _step),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  AppMessageBanner(
                    icon: Icons.error_outline_rounded,
                    message: _error!,
                    color: AppColors.danger,
                    background: AppColors.dangerSoft,
                  ),
                ],
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: onCodeStep ? _codeStep() : _phoneStep(),
                ),
                const SizedBox(height: 28),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppColors.subtle, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Your session is securely protected',
                      style: TextStyle(color: AppColors.subtle, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phone-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            onFieldSubmitted: (_) => _requestOtp(),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: .4),
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '10-digit mobile number',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
            validator: (value) {
              final phone = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
              if (!RegExp(r'^\+?[0-9]{10,13}$').hasMatch(phone)) {
                return 'Enter a valid mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _requestOtp,
            child: ProgressLabel(
              loading: _loading,
              label: 'Send code',
              loadingLabel: 'Sending code...',
            ),
          ),
          const SizedBox(height: 22),
          const _OrDivider(),
          const SizedBox(height: 18),
          GoogleStudentButton(
            onPressed: _busy ? null : _signInWithGoogle,
            loading: _googleLoading,
          ),
          const SizedBox(height: 10),
          const Text(
            'Google sign-in creates a customer account. PG owner login stays separate.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtle, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _codeStep() {
    return Column(
      key: const ValueKey('code-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kDebugMode) ...[
          const AppMessageBanner(
            icon: Icons.developer_mode_rounded,
            message:
                'Local testing: the SMS is simulated. Copy the latest OTP from the backend container logs.',
          ),
          const SizedBox(height: 16),
        ],
        OtpCodeField(
          controller: _codeController,
          focusNode: _codeFocus,
          enabled: !_busy,
          errorText: _codeError,
          onChanged: (_) {
            if (_codeError != null) setState(() => _codeError = null);
          },
          onCompleted: (_) => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _nameController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          onFieldSubmitted: (_) => _verifyOtp(),
          decoration: const InputDecoration(
            labelText: 'Full name (new accounts only)',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _verifyOtp,
          child: ProgressLabel(
            loading: _loading,
            label: 'Verify & continue',
            loadingLabel: 'Verifying...',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _busy ? null : _changePhone,
              child: const Text('Change number'),
            ),
            TextButton(
              onPressed: _busy || _resendIn > 0 ? null : _resendOtp,
              child: Text(
                  _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code'),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.subtle,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }
}

class _StepProgress extends StatelessWidget {
  final _Step step;

  const _StepProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 4,
            decoration: BoxDecoration(
              color: step == _Step.code ? AppColors.ink : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}
