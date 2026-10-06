import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../shared/brand/hi_pg_brand.dart';

/// Welcome screen the launch animation wipes into: the brand, one line on
/// what hi pg does, and the app's two entry points at the bottom where a
/// thumb lands. Customer sign-in leads into the customer home, while owners
/// use the secondary button. Content eases in once and then stays still, so
/// nothing competes with the choice.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  static const _stepCount = 5;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final List<CurvedAnimation> _steps = [
    for (var i = 0; i < _stepCount; i++)
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(i * .09, .55 + i * .09, curve: Curves.easeOutCubic),
      ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isAnimating || _entrance.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    for (final step in _steps) {
      step.dispose();
    }
    _entrance.dispose();
    super.dispose();
  }

  Widget _step(int index, Widget child) {
    final animation = _steps[index];
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 18),
          child: child,
        ),
      ),
    );
  }

  Future<void> _openLegalPage(String path) async {
    final uri = Uri.parse('${Env.legalBaseUrl}/$path');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the legal page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightChrome,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 30),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _step(
                          0,
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: HiPgLockup(height: 28),
                          ),
                        ),
                        const Spacer(flex: 2),
                        const SizedBox(height: 16),
                        _step(1, const _Hero()),
                        const SizedBox(height: 28),
                        _step(
                          2,
                          Column(
                            children: [
                              Text(
                                'Paying guest life, made simple.',
                                textAlign: TextAlign.center,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Stay by the month or just for a few days, '
                                "or run your property's rooms, customers "
                                'and rent, all in one app.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _step(
                          2,
                          const Row(
                            children: [
                              Expanded(
                                child: _Benefit(
                                  icon: Icons.bed_outlined,
                                  label: 'Live bed\navailability',
                                ),
                              ),
                              Expanded(
                                child: _Benefit(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'Monthly or\nday-wise stays',
                                ),
                              ),
                              Expanded(
                                child: _Benefit(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Secure\npayments',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 3),
                        const SizedBox(height: 28),
                        _step(
                          3,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                key: const Key('student-entry-button'),
                                onPressed: () => context.push('/student/login'),
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 54)),
                                icon:
                                    const Icon(Icons.search_rounded, size: 21),
                                label: const Text('Search for a stay'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in or create an account to continue',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                key: const Key('owner-entry-button'),
                                onPressed: () => context.push('/owner/login'),
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 54)),
                                icon:
                                    const Icon(Icons.domain_rounded, size: 20),
                                label: const Text("I'm a PG owner"),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _step(
                          4,
                          Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded,
                                      size: 13, color: AppColors.subtle),
                                  SizedBox(width: 6),
                                  Text(
                                    'Secure sign-in  ·  Your data stays private',
                                    style: TextStyle(
                                        color: AppColors.subtle,
                                        fontSize: 11.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () => _openLegalPage('privacy'),
                                    child: const Text('Privacy Policy'),
                                  ),
                                  TextButton(
                                    onPressed: () => _openLegalPage('terms'),
                                    child: const Text('Terms of Service'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The house mark on a soft rose disc.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.brandSoft,
          shape: BoxShape.circle,
        ),
        child: const HiPgMark(size: 64),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Benefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.brand, size: 21),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
