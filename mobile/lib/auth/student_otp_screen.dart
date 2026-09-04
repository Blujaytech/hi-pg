import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import 'auth_state.dart';

/// One screen, two steps: request an OTP for a phone number, then verify it.
/// Same endpoint pair handles both signup and login (technical plan §6
/// Phase 1: "student is phone/OTP-first").
class StudentOtpScreen extends StatefulWidget {
  const StudentOtpScreen({super.key});

  @override
  State<StudentOtpScreen> createState() => _StudentOtpScreenState();
}

enum _Step { phone, code }

class _StudentOtpScreenState extends State<StudentOtpScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  _Step _step = _Step.phone;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_phoneController.text.trim().length < 10) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().requestStudentOtp(phone: _phoneController.text.trim());
      setState(() => _step = _Step.code);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().verifyStudentOtp(
            phone: _phoneController.text.trim(),
            code: _codeController.text.trim(),
            fullName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          );
      if (mounted) context.go('/student');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              if (_step == _Step.phone) ..._phoneStep() else ..._codeStep(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep() {
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone number'),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _loading ? null : _requestOtp,
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Send OTP'),
      ),
    ];
  }

  List<Widget> _codeStep() {
    return [
      Text('Enter the code sent to ${_phoneController.text}'),
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '6-digit code'),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Full name (first time only)'),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _loading ? null : _verifyOtp,
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Verify & continue'),
      ),
      TextButton(
        onPressed: _loading ? null : () => setState(() => _step = _Step.phone),
        child: const Text('Change phone number'),
      ),
    ];
  }
}
