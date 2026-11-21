import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import 'auth_models.dart';
import 'auth_state.dart';
import 'auth_widgets.dart';

class OwnerLoginScreen extends StatefulWidget {
  const OwnerLoginScreen({super.key});

  @override
  State<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends State<OwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthState>();
      await auth.ownerLogin(
          email: _emailController.text.trim(),
          password: _passwordController.text);
      if (mounted) {
        context.go(auth.role == UserRole.admin ? '/admin' : '/owner/dashboard');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      leading: const AuthBackButton(),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                eyebrow: 'Owner workspace',
                title: 'Welcome back',
                subtitle:
                    'Manage properties, customers, collections and daily operations from one calm workspace.',
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                AppMessageBanner(
                  icon: Icons.error_outline_rounded,
                  message: _error!,
                  color: AppColors.danger,
                  background: AppColors.dangerSoft,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 14),
              PasswordFormField(
                controller: _passwordController,
                enabled: !_loading,
                onSubmitted: _submit,
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: ProgressLabel(
                  loading: _loading,
                  label: 'Open owner dashboard',
                  loadingLabel: 'Signing you in...',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed:
                    _loading ? null : () => context.push('/owner/phone-login'),
                icon: const Icon(Icons.phone_iphone_rounded),
                label: const Text('Claim an invited PG'),
              ),
              const SizedBox(height: 10),
              Text(
                'Use the mobile number recorded for your property.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New to hi pg?',
                      style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(
                    onPressed:
                        _loading ? null : () => context.push('/owner/signup'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
