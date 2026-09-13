import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_state.dart';
import '../core/theme.dart';
import '../shared/app_states.dart';
import '../shared/brand/hi_pg_brand.dart';

/// Student home tab: search first, then the things a student comes back for
/// (bookings, rent, support).
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fullName = context.watch<AuthState>().fullName?.trim() ?? '';
    final firstName =
        fullName.isEmpty ? null : fullName.split(RegExp(r'\s+')).first;
    return Scaffold(
      appBar: AppBar(
        title: const HiPgLockup(height: 26),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              button: true,
              label: 'Account',
              child: Material(
                color: AppColors.ink,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go('/student/account'),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: fullName.isEmpty
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 20)
                          : Text(
                              fullName.characters.first.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
        children: [
          Text(
            firstName == null ? 'Hello there' : 'Hi, $firstName',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Where are you staying next?',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _SearchHero(onSearch: () => context.go('/student/search')),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Quick access'),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.event_available_rounded,
                    title: 'My bookings',
                    subtitle: 'Manage your stays',
                    onTap: () => context.go('/student/bookings'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.receipt_long_rounded,
                    title: 'Fees & payments',
                    subtitle: 'Rent and balance',
                    onTap: () => context.push('/student/fees'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SupportAction(onTap: () => context.push('/student/complaints')),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Why hi pg'),
          const SizedBox(height: 12),
          const _TrustPanel(),
        ],
      ),
    );
  }
}

class _SearchHero extends StatelessWidget {
  final VoidCallback onSearch;

  const _SearchHero({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE BED AVAILABILITY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const HiPgMark(
                size: 30,
                color: Colors.white,
                faceColor: AppColors.ink,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Find a PG with a\nbed free today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -.45,
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onSearch,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        color: AppColors.ink, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Search area, PG name or city',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 19),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, size: 44),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const IconTile(
                  icon: Icons.support_agent_rounded, size: 44, dark: true),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Help & support',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text('Raise and track requests with your PG',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            _TrustItem(
              icon: Icons.bed_rounded,
              title: 'Availability that stays current',
              subtitle: 'See open beds before you choose a property.',
            ),
            Divider(height: 1),
            _TrustItem(
              icon: Icons.currency_rupee_rounded,
              title: 'Clear monthly pricing',
              subtitle: 'Compare room rent without hidden guesswork.',
            ),
            Divider(height: 1),
            _TrustItem(
              icon: Icons.verified_user_outlined,
              title: 'Simple, secure booking',
              subtitle: 'Choose your room and bed in a few taps.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          IconTile(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
