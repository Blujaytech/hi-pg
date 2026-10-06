import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_models.dart';
import '../../auth/auth_state.dart';
import '../../core/api_exception.dart';
import '../../core/env.dart';
import '../../core/theme.dart';
import '../../student/profile/customer_profile_repository.dart';
import '../brand/hi_pg_brand.dart';

/// Account tab for both roles: who is signed in, role-specific shortcuts
/// that are not tabs of their own, licences and sign-out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _deleting = false;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out of hi pg?'),
        content: const Text(
            'You will need to sign in again to get back to your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthState>().logout();
    }
  }

  Future<void> _openLegalPage(String path) async {
    final uri = Uri.parse('${Env.legalBaseUrl}$path');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this page.')),
      );
    }
  }

  Future<void> _confirmAccountDeletion({required bool isOwner}) async {
    final input = await showDialog<_DeletionConfirmation>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeletionConfirmationDialog(isOwner: isOwner),
    );
    if (input == null || !mounted) return;

    setState(() => _deleting = true);
    try {
      await context.read<AuthState>().deleteAccount(
            currentPassword: input.currentPassword,
          );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account deletion failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isOwner = auth.role != UserRole.student;
    final isAdmin = auth.role == UserRole.admin;
    final storedName = auth.fullName?.trim() ?? '';
    final name = storedName.isNotEmpty
        ? storedName
        : (isOwner ? 'Property owner' : 'Customer');

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          _ProfileCard(
            name: name,
            loadCustomerPhoto: !isOwner,
            role: isAdmin
                ? 'Administrator & PG owner'
                : (isOwner ? 'PG owner' : null),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 28),
            const _GroupLabel('Administration'),
            _LinkGroup(children: [
              _LinkTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'KYC review dashboard',
                subtitle: 'Review and approve owner submissions',
                onTap: () => context.go('/admin'),
              ),
            ]),
          ],
          if (!isOwner) ...[
            const SizedBox(height: 28),
            const _GroupLabel('Your stay'),
            _LinkGroup(children: [
              _LinkTile(
                icon: Icons.badge_outlined,
                title: 'Profile & verification',
                subtitle: 'Personal details and ID document',
                onTap: () => context.push('/student/profile'),
              ),
              _LinkTile(
                icon: Icons.event_available_outlined,
                title: 'My bookings',
                subtitle: 'Current and past stays',
                onTap: () => context.go('/student/bookings'),
              ),
              _LinkTile(
                icon: Icons.receipt_long_outlined,
                title: 'Fees & payments',
                subtitle: 'Rent history and balance',
                onTap: () => context.push('/student/fees'),
              ),
              _LinkTile(
                icon: Icons.report_problem_outlined,
                title: 'Raise a complaint',
                subtitle: 'Report and track a PG or stay issue',
                onTap: () => context.push('/student/complaints'),
              ),
              _LinkTile(
                icon: Icons.support_agent_outlined,
                title: 'Help & support',
                subtitle: 'Contact the hi pg admin team',
                onTap: () => context.push('/support'),
              ),
            ]),
          ],
          if (isOwner && !isAdmin) ...[
            const SizedBox(height: 28),
            const _GroupLabel('Support'),
            _LinkGroup(children: [
              _LinkTile(
                icon: Icons.support_agent_outlined,
                title: 'Help & support',
                subtitle: 'Contact the hi pg admin team',
                onTap: () => context.push('/support'),
              ),
            ]),
          ],
          const SizedBox(height: 28),
          const _GroupLabel('Legal & privacy'),
          _LinkGroup(children: [
            _LinkTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How hi pg handles your information',
              onTap: () => _openLegalPage('/privacy'),
            ),
            _LinkTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Booking, payment and account terms',
              onTap: () => _openLegalPage('/terms'),
            ),
            _LinkTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Account deletion information',
              subtitle: 'What is removed and what must be retained',
              onTap: () => _openLegalPage('/account-deletion'),
            ),
          ]),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.dangerSoft, width: 1.4),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('Log out'),
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _deleting
                  ? null
                  : () => _confirmAccountDeletion(isOwner: isOwner),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined, size: 20),
              label: Text(_deleting ? 'Deleting account…' : 'Delete account'),
            ),
          ],
          const SizedBox(height: 24),
          const Center(
            child: HiPgLockup(
              height: 18,
              color: AppColors.subtle,
              wordColor: AppColors.subtle,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletionConfirmation {
  final String? currentPassword;

  const _DeletionConfirmation(this.currentPassword);
}

class _DeletionConfirmationDialog extends StatefulWidget {
  final bool isOwner;

  const _DeletionConfirmationDialog({required this.isOwner});

  @override
  State<_DeletionConfirmationDialog> createState() =>
      _DeletionConfirmationDialogState();
}

class _DeletionConfirmationDialogState
    extends State<_DeletionConfirmationDialog> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmationController.text == 'DELETE';
    return AlertDialog(
      title: const Text('Permanently delete account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes your login, profile, private documents, active '
              'sessions and notifications. This cannot be undone.',
            ),
            const SizedBox(height: 10),
            Text(
              widget.isOwner
                  ? 'Your PG listings will be unpublished and future AutoPay '
                      'will be stopped. Required booking and financial records '
                      'remain only in anonymized form.'
                  : 'Required booking, payment, receipt and legal records may '
                      'remain only in anonymized form. Deletion does not create '
                      'a refund or cancel an active accommodation agreement.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _confirmationController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  helperText: 'Required for owners who sign in with email',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(_hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: confirmed
              ? () => Navigator.pop(
                    context,
                    _DeletionConfirmation(
                      _passwordController.text.trim().isEmpty
                          ? null
                          : _passwordController.text,
                    ),
                  )
              : null,
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String? role;
  final bool loadCustomerPhoto;

  const _ProfileCard({
    required this.name,
    required this.role,
    required this.loadCustomerPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _AccountAvatar(
            name: name,
            loadCustomerPhoto: loadCustomerPhoto,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),
                if (role != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatefulWidget {
  final String name;
  final bool loadCustomerPhoto;

  const _AccountAvatar({
    required this.name,
    required this.loadCustomerPhoto,
  });

  @override
  State<_AccountAvatar> createState() => _AccountAvatarState();
}

class _AccountAvatarState extends State<_AccountAvatar> {
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    if (widget.loadCustomerPhoto) {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    try {
      final profile = await CustomerProfileRepository().getMine();
      if (mounted) {
        setState(() => _photoUrl = profile.profilePhotoUrl);
      }
    } catch (_) {
      // The account remains usable when the optional profile request fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        widget.name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return ClipOval(
      child: SizedBox(
        width: 56,
        height: 56,
        child: _photoUrl == null
            ? fallback
            : Image.network(
                _photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _LinkGroup extends StatelessWidget {
  final List<Widget> children;

  const _LinkGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}
