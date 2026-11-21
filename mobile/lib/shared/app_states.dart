import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'brand/hi_pg_brand.dart';

class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const PremiumAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottom,
  }) : assert(title != null || titleWidget != null);

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFFFFAFB),
      foregroundColor: AppColors.ink,
      systemOverlayStyle: AppTheme.lightChrome,
      leading: leading,
      actions: actions,
      bottom: bottom,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      title: titleWidget ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title!,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
    );
  }
}

class AppLoadingView extends StatelessWidget {
  final String label;

  const AppLoadingView({super.key, this.label = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutBack,
        builder: (context, value, _) => Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(
            scale: .84 + (.16 * value),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HiPgPlainLogo(fontSize: 30),
                  const SizedBox(height: 18),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 116,
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  const AppEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon = Icons.arrow_forward_rounded,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, AppColors.brandSoft],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: AppShadows.card,
              ),
              child: Icon(icon, color: AppColors.brand, size: 40),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                icon: Icon(actionIcon, size: 19),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.card,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: AppColors.brand, size: 36),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text("Couldn't load this",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppMessageBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color background;

  const AppMessageBanner({
    super.key,
    required this.icon,
    required this.message,
    this.color = AppColors.ink,
    this.background = AppColors.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.medium,
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { neutral, dark, success, warning, danger }

/// Compact rounded label for a record's state (Active, Paid, Overdue, ...).
class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dot;

  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      StatusTone.neutral => (AppColors.ink, AppColors.fill),
      StatusTone.dark => (Colors.white, AppColors.ink),
      StatusTone.success => (AppColors.success, AppColors.successSoft),
      StatusTone.warning => (AppColors.warning, AppColors.warningSoft),
      StatusTone.danger => (AppColors.danger, AppColors.dangerSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded-square icon holder used at the start of cards and rows.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool dark;
  final Color? color;
  final Color? background;

  const IconTile({
    super.key,
    required this.icon,
    this.size = 46,
    this.dark = false,
    this.color,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? (dark ? AppColors.ink : AppColors.fill),
        borderRadius: BorderRadius.circular(size * .22),
      ),
      child: Icon(
        icon,
        size: size * .48,
        color: color ?? (dark ? Colors.white : AppColors.ink),
      ),
    );
  }
}

/// App bar title with an optional second line, readable on the charcoal
/// bar (a plain `bodySmall` subtitle would be muted grey on charcoal).
class AppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AppBarTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .72),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null)
          Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Tappable field styled like a text input, for values chosen from a picker
/// (dates, mostly).
class PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.medium,
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.medium,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// White sheet body used for create/edit forms opened from list screens, so
/// every "add" flow looks and behaves alike.
class FormSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const FormSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(
                  icon: icon,
                  size: 48,
                  color: AppColors.brandText,
                  background: AppColors.brandSoft,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Keeps page content aligned and readable on phones, tablets, and wide
/// windows without forcing individual screens to invent their own gutters.
class AppContentWidth extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const AppContentWidth({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Standard white surface for grouped content such as search controls and
/// property summaries.
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: AppRadii.medium,
      side: BorderSide(color: AppColors.border),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.medium,
        boxShadow: elevated ? AppShadows.card : null,
      ),
      child: Material(
        color: AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Opens [builder] as a rounded, keyboard-aware modal sheet.
Future<T?> showFormSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}
