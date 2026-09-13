import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../shared/brand/hi_pg_brand.dart';

/// Welcome screen the launch animation wipes into: what hi pg is, and the
/// app's only two entry points, grouped together a little above centre.
/// Content eases in once and then stays still, so nothing competes with the
/// choice.
class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  static const _stepCount = 6;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final List<CurvedAnimation> _steps = [
    for (var i = 0; i < _stepCount; i++)
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(i * .08, .5 + i * .08, curve: Curves.easeOutCubic),
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
          offset: Offset(0, (1 - animation.value) * 22),
          child: child,
        ),
      ),
    );
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
                        // Less space above than below lifts the message and
                        // both choices a little above centre.
                        const Spacer(flex: 2),
                        const SizedBox(height: 20),
                        _step(1, const _LiveBanner()),
                        const SizedBox(height: 56),
                        _step(
                          2,
                          Text(
                            'PG life, made simple.',
                            style: textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _step(
                          2,
                          Text(
                            "Find a PG that fits your budget, or run your property's rooms, customers and rent, all in one app.",
                            style: textTheme.bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 64),
                        _step(
                          3,
                          _RoleCard(
                            buttonKey: const Key('owner-entry-button'),
                            icon: Icons.domain_rounded,
                            title: "I'm a PG owner",
                            subtitle: 'Manage rooms, customers & rent',
                            primary: true,
                            onTap: () => context.push('/owner/login'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _step(
                          4,
                          _RoleCard(
                            buttonKey: const Key('student-entry-button'),
                            icon: Icons.search_rounded,
                            title: 'Search for a stay',
                            subtitle: 'Browse PGs, no sign-up needed',
                            primary: false,
                            onTap: () => context.push('/explore'),
                          ),
                        ),
                        const Spacer(flex: 3),
                        const SizedBox(height: 16),
                        _step(
                          5,
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 13, color: AppColors.subtle),
                              SizedBox(width: 6),
                              Text(
                                'Secure sign-in  ·  Your data stays private',
                                style: TextStyle(
                                    color: AppColors.subtle, fontSize: 11.5),
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

/// Compact banner: the customer promise in one line, with the brand mark.
class _LiveBanner extends StatelessWidget {
  const _LiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.live,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE AVAILABILITY',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'See which beds are free before you visit.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const HiPgMark(
            size: 46,
            color: AppColors.surface,
            faceColor: AppColors.ink,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  const _RoleCard({
    required this.buttonKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      child: Material(
        color: primary ? AppColors.ink : AppColors.fill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primary ? Colors.white : AppColors.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: primary ? AppColors.ink : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primary
                              ? Colors.white.withValues(alpha: .62)
                              : AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: foreground, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
