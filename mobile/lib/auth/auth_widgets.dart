import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../shared/brand/hi_pg_brand.dart';

class AuthPageScaffold extends StatelessWidget {
  final Widget child;
  final Widget? leading;
  final bool compact;

  const AuthPageScaffold({
    super.key,
    required this.child,
    this.leading,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final authTheme = baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 49),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 49),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFB),
      appBar: authAppBar(leading: leading),
      body: Stack(
        children: [
          const Positioned(
            top: -94,
            right: -72,
            child: _AuthGlow(size: 220, color: Color(0x24F84464)),
          ),
          const Positioned(
            bottom: -120,
            left: -92,
            child: _AuthGlow(size: 250, color: Color(0x14F84464)),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: HiPgPlainLogo(fontSize: 42),
                      ),
                      SizedBox(height: compact ? 16 : 20),
                      Theme(
                        data: authTheme,
                        child: AuthEntrance(child: child),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 14, color: AppColors.subtle),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Secure, private and protected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.subtle,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _AuthGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class AuthEntrance extends StatelessWidget {
  final Widget child;

  const AuthEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Eyebrow + large title + supporting line at the top of every auth screen.
class AuthHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              eyebrow.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.brandText,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 26,
                letterSpacing: -.8,
              ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.45,
                fontSize: 14,
              ),
        ),
      ],
    );
  }
}

/// Light, borderless bar for the sign-in screens, which sit on a plain page
/// rather than under the charcoal header the signed-in app uses.
AppBar authAppBar({Widget? leading}) => AppBar(
      leading: leading,
      backgroundColor: const Color(0xFFFFFAFB),
      foregroundColor: AppColors.ink,
      iconTheme: const IconThemeData(color: AppColors.ink),
      systemOverlayStyle: AppTheme.lightChrome,
    );

/// Back arrow that pops when there is somewhere to pop to, otherwise returns
/// to [fallback] (e.g. after a cold start straight onto this screen).
class AuthBackButton extends StatelessWidget {
  final String fallback;
  final VoidCallback? onPressed;

  const AuthBackButton({super.key, this.fallback = '/', this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: onPressed ??
          () => context.canPop() ? context.pop() : context.go(fallback),
    );
  }
}

/// Button label that swaps to a spinner + progress text while [loading].
class ProgressLabel extends StatelessWidget {
  final bool loading;
  final String label;
  final String loadingLabel;

  const ProgressLabel({
    super.key,
    required this.loading,
    required this.label,
    required this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(loading ? loadingLabel : label),
      ],
    );
  }
}

/// Consistent student Google sign-in action used on the login screen and the
/// guest booking sheet. It intentionally lives outside the owner auth flow.
class GoogleStudentButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleStudentButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size(0, 49),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.ink,
              ),
            )
          else
            const Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              loading ? 'Opening Google...' : 'Continue with Google',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool enabled;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onSubmitted;

  const PasswordFormField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.helperText,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const [AutofillHints.password],
    this.validator,
    this.onSubmitted,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(_obscured
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Six separate digit boxes backed by one invisible text field, so paste,
/// SMS autofill and the numeric keyboard all behave like a normal input.
class OtpCodeField extends StatelessWidget {
  static const int length = 6;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 60,
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([controller, focusNode]),
                builder: (context, _) {
                  final code = controller.text;
                  return Row(
                    children: [
                      for (var i = 0; i < length; i++) ...[
                        if (i > 0) const SizedBox(width: 9),
                        Expanded(
                          child: _OtpBox(
                            digit: i < code.length ? code[i] : '',
                            active: focusNode.hasFocus &&
                                (i == code.length ||
                                    (i == length - 1 && code.length == length)),
                            error: errorText != null,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: Semantics(
                  label: 'One-time code',
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      showCursor: false,
                      enableInteractiveSelection: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(length),
                      ],
                      decoration: const InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        counterText: '',
                      ),
                      onChanged: (value) {
                        onChanged?.call(value);
                        if (value.length == length) onCompleted?.call(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  final bool active;
  final bool error;

  const _OtpBox({
    required this.digit,
    required this.active,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? AppColors.brand
        : error
            ? AppColors.danger
            : digit.isEmpty
                ? Colors.transparent
                : AppColors.border;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: digit.isEmpty ? AppColors.fill : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: active ? 1.6 : 1.2),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
