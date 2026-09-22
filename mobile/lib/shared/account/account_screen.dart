import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_models.dart';
import '../../auth/auth_state.dart';
import '../../core/theme.dart';
import '../brand/hi_pg_brand.dart';

/// Account tab for both roles: who is signed in, role-specific shortcuts
/// that are not tabs of their own, licences and sign-out.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final isOwner = auth.role == UserRole.owner;
    final storedName = auth.fullName?.trim() ?? '';
    final name = storedName.isNotEmpty
        ? storedName
        : (isOwner ? 'Property owner' : 'Customer');

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          _ProfileCard(name: name, role: isOwner ? 'PG owner' : 'Customer'),
          if (!isOwner) ...[
            const SizedBox(height: 28),
            const _GroupLabel('Your stay'),
            _LinkGroup(children: [
              _LinkTile(
                icon: Icons.badge_outlined,
                title: 'Profile & verification',
                subtitle: 'Booking details, mobile and government ID',
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
                icon: Icons.support_agent_outlined,
                title: 'Help & support',
                subtitle: 'Raise and track requests',
                onTap: () => context.push('/student/complaints'),
              ),
            ]),
          ],
          const SizedBox(height: 28),
          const _GroupLabel('About'),
          _LinkGroup(children: [
            _LinkTile(
              icon: Icons.description_outlined,
              title: 'Open-source licences',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'hi pg',
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(16),
                  child: HiPgAppIcon(size: 56),
                ),
              ),
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
          const SizedBox(height: 24),
          const Center(
            child: HiPgLockup(
              height: 18,
              color: AppColors.subtle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String role;

  const _ProfileCard({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
