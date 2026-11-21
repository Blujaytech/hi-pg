import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../shared/brand/hi_pg_brand.dart';
import 'auth_models.dart';
import 'auth_state.dart';

const _roomBackground = 'assets/branding/hi_pg_splash_room.png';

/// A four-second, layered launch composition inspired by the approved artwork.
/// Every branded element is rendered independently so it can move naturally
/// over the cinematic room background without animating a flattened poster.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

abstract final class _Timeline {
  static const duration = Duration(milliseconds: 4000);
  static const logo = (0.04, 0.25);
  static const accent = (0.18, 0.32);
  static const wordsStart = 0.25;
  static const wordStagger = 0.055;
  static const wordDuration = 0.18;
  static const underline = (0.61, 0.78);
  static const subtitle = (0.54, 0.70);
  static const topWave = (0.0, 0.30);
  static const bottomWave = (0.68, 0.91);
  static const featureStarts = [0.61, 0.68, 0.75];
  static const featureDuration = 0.17;
  static const fadeOut = (0.94, 1.0);
  static const reducedMotionFrame = 0.92;
  static const reducedMotionHold = Duration(milliseconds: 1100);
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _launchChannel = MethodChannel('hipg/launch');

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _Timeline.duration);
  late final AuthState _auth;
  bool _animationDone = false;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthState>()..addListener(_handOffWhenReady);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await _launchChannel
          .invokeMethod<void>('systemSplashGone')
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Older Android, other platforms and tests have no native hand-off.
    }
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _Timeline.reducedMotionFrame;
      Future<void>.delayed(_Timeline.reducedMotionHold, _onAnimationDone);
    } else {
      _controller.forward().whenComplete(_onAnimationDone);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_handOffWhenReady);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationDone() {
    _animationDone = true;
    _handOffWhenReady();
  }

  void _handOffWhenReady() {
    if (_handedOff ||
        !_animationDone ||
        !mounted ||
        _auth.status == AuthStatus.unknown) {
      return;
    }
    _handedOff = true;
    context.go(switch (_auth.status) {
      AuthStatus.authenticated => switch (_auth.role) {
          UserRole.admin => '/admin',
          UserRole.owner => '/owner/dashboard',
          _ => '/student',
        },
      _ => '/',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('launch-animation'),
      backgroundColor: const Color(0xFFF8E9E5),
      body: Semantics(
        label: 'hi pg. Your Next Place Feels Like Home. '
            'Prime locations, verified PGs, safe and hassle-free.',
        image: true,
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _frame(
                context,
                constraints.biggest,
                _controller.value,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _frame(BuildContext context, Size size, double progress) {
    final eased = Curves.easeOutCubic.transform(progress);
    final backgroundScale = lerpDouble(1.075, 1.0, eased)!;
    final backgroundOffset = Offset(
      lerpDouble(-8, 0, eased)!,
      lerpDouble(22, 0, eased)!,
    );
    final fadeOut = Curves.easeInCubic.transform(
      _progress(progress, _Timeline.fadeOut),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightChrome,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          RepaintBoundary(
            child: Transform.translate(
              offset: backgroundOffset,
              child: Transform.scale(
                scale: backgroundScale,
                child: Image.asset(
                  _roomBackground,
                  key: const Key('launch-room-background'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFDFEF8F6),
                  Color(0xE8FEF8F6),
                  Color(0x78FEF8F6),
                  Color(0x00FFFFFF),
                ],
                stops: [0, 0.27, 0.52, 0.72],
              ),
            ),
          ),
          _topWave(size, progress),
          _content(context, size, progress),
          _bottomWave(size, progress),
          if (fadeOut > 0)
            ColoredBox(color: Colors.white.withValues(alpha: fadeOut)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Size size, double progress) {
    final padding = MediaQuery.paddingOf(context);
    final horizontal = (size.width * 0.09).clamp(26.0, 54.0);
    final top = math.max(padding.top + 14, size.height * 0.052);
    final logoSize = (size.width * 0.105).clamp(42.0, 70.0);
    final headlineSize = (size.width * 0.064).clamp(27.0, 43.0);
    final subtitleSize = (size.width * 0.033).clamp(15.0, 21.0);
    final contentWidth = size.width - horizontal * 2;

    return Positioned(
      left: horizontal,
      right: horizontal,
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _logo(logoSize, progress),
          SizedBox(height: logoSize * 0.22),
          _accent(progress),
          SizedBox(height: headlineSize * 0.52),
          _headline(headlineSize, progress),
          SizedBox(height: headlineSize * 0.52),
          _subtitle(subtitleSize, progress),
          SizedBox(height: headlineSize * 0.86),
          _features(contentWidth, size.width, progress),
        ],
      ),
    );
  }

  Widget _logo(double fontSize, double progress) {
    final raw = _progress(progress, _Timeline.logo);
    final spring = Curves.easeOutBack.transform(raw);
    return Opacity(
      opacity: raw,
      child: Transform.translate(
        offset: Offset(0, (1 - spring) * 18),
        child: Transform.scale(
          scale: lerpDouble(0.72, 1, spring)!,
          alignment: Alignment.bottomLeft,
          child: HiPgPlainLogo(
            key: const Key('launch-logo'),
            fontSize: fontSize,
            hiColor: const Color(0xFF96989D),
          ),
        ),
      ),
    );
  }

  Widget _accent(double progress) {
    final value = Curves.easeOutCubic.transform(
      _progress(progress, _Timeline.accent),
    );
    return Transform.scale(
      scaleX: value,
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('launch-logo-accent'),
        width: 48,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _headline(double fontSize, double progress) {
    final style = TextStyle(
      fontFamily: AppTheme.fontFamily,
      color: const Color(0xFF111421),
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.08,
      letterSpacing: -fontSize * 0.038,
    );
    final gap = fontSize * 0.22;
    return Column(
      key: const Key('launch-headline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _word('Your', 0, style, progress),
              SizedBox(width: gap),
              _word('Next', 1, style, progress),
              SizedBox(width: gap),
              _word('Place', 2, style, progress),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _word('Feels', 3, style, progress),
              SizedBox(width: gap),
              _word('Like', 4, style, progress),
              SizedBox(width: gap),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _word(
                    'Home',
                    5,
                    style.copyWith(color: AppColors.brand),
                    progress,
                    key: const Key('launch-home-word'),
                  ),
                  Positioned(
                    left: 1,
                    right: 0,
                    bottom: -fontSize * 0.23,
                    height: fontSize * 0.24,
                    child: CustomPaint(
                      key: const Key('launch-home-underline'),
                      painter: _UnderlinePainter(
                        Curves.easeOutCubic.transform(
                          _progress(progress, _Timeline.underline),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _word(
    String text,
    int index,
    TextStyle style,
    double progress, {
    Key? key,
  }) {
    final start = _Timeline.wordsStart + index * _Timeline.wordStagger;
    final raw = _progress(
      progress,
      (start, start + _Timeline.wordDuration),
    );
    final eased = Curves.easeOutCubic.transform(raw);
    return Opacity(
      opacity: raw,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * style.fontSize! * 0.62),
        child: Text(
          text,
          key: key ?? Key('launch-word-${text.toLowerCase()}'),
          style: style,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }

  Widget _subtitle(double fontSize, double progress) {
    final raw = _progress(progress, _Timeline.subtitle);
    final eased = Curves.easeOutCubic.transform(raw);
    return Opacity(
      opacity: raw,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 14),
        child: Text(
          'Discover comfortable PGs\nin the best locations.',
          key: const Key('launch-subtitle'),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: const Color(0xFF66676D),
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            height: 1.36,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _features(double width, double screenWidth, double progress) {
    final iconSize = (screenWidth * 0.058).clamp(23.0, 34.0);
    final labelSize = (screenWidth * 0.026).clamp(12.0, 16.0);
    final features = [
      (Icons.location_on_rounded, 'Prime\nLocations', 'location'),
      (Icons.bed_rounded, 'Verified\nPGs', 'bed'),
      (Icons.verified_user_rounded, 'Safe &\nHassle-Free', 'shield'),
    ];
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < features.length; index++)
            Expanded(
              child: _feature(
                features[index],
                index,
                iconSize,
                labelSize,
                progress,
              ),
            ),
        ],
      ),
    );
  }

  Widget _feature(
    (IconData, String, String) feature,
    int index,
    double iconSize,
    double labelSize,
    double progress,
  ) {
    final start = _Timeline.featureStarts[index];
    final raw = _progress(
      progress,
      (start, start + _Timeline.featureDuration),
    );
    final spring = Curves.easeOutBack.transform(raw);
    return Opacity(
      opacity: raw,
      child: Transform.translate(
        offset: Offset(0, (1 - spring) * 24),
        child: Transform.scale(
          scale: lerpDouble(0.58, 1, spring)!,
          child: Column(
            key: Key('launch-feature-${feature.$3}'),
            children: [
              Container(
                width: iconSize * 2.05,
                height: iconSize * 2.05,
                decoration: const BoxDecoration(
                  color: Color(0x66FFE1E8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  feature.$1,
                  size: iconSize,
                  color: AppColors.brand,
                ),
              ),
              SizedBox(height: iconSize * 0.33),
              Text(
                feature.$2,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: const Color(0xFF292B34),
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  height: 1.14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topWave(Size screen, double progress) {
    final raw = _progress(progress, _Timeline.topWave);
    final eased = Curves.easeOutCubic.transform(raw);
    return Positioned(
      right: -screen.width * 0.07,
      top: -screen.height * 0.035,
      child: Opacity(
        opacity: raw,
        child: Transform.translate(
          offset: Offset((1 - eased) * screen.width * 0.2, 0),
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('launch-top-wave'),
              size: Size(screen.width * 0.46, screen.height * 0.30),
              painter: _TopWavePainter(progress),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomWave(Size screen, double progress) {
    final raw = _progress(progress, _Timeline.bottomWave);
    final eased = Curves.easeOutCubic.transform(raw);
    return Positioned(
      left: -screen.width * 0.1,
      right: -screen.width * 0.08,
      bottom: -screen.height * 0.02,
      height: screen.height * 0.17,
      child: Opacity(
        opacity: raw,
        child: Transform.translate(
          offset: Offset(0, (1 - eased) * screen.height * 0.11),
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('launch-bottom-wave'),
              painter: _BottomWavePainter(progress),
            ),
          ),
        ),
      ),
    );
  }

  static double _progress(double value, (double, double) window) =>
      ((value - window.$1) / (window.$2 - window.$1)).clamp(0.0, 1.0);
}

class _UnderlinePainter extends CustomPainter {
  final double progress;

  const _UnderlinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.06,
        size.width - 1,
        size.height * 0.42,
      );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = AppColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3, size.height * 0.28)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _TopWavePainter extends CustomPainter {
  final double phase;

  const _TopWavePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(phase * math.pi) * size.height * 0.035;
    final fill = Path()
      ..moveTo(size.width * 0.36, 0)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.36 + drift,
        size.width * 0.66,
        size.height * 0.74 + drift,
        size.width,
        size.height * 0.84,
      )
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = AppColors.brand.withValues(alpha: 0.9));

    final line = Path()
      ..moveTo(size.width * 0.24, 0)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.34 + drift,
        size.width * 0.61,
        size.height * 0.63 + drift,
        size.width,
        size.height * 0.70,
      );
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TopWavePainter oldDelegate) => oldDelegate.phase != phase;
}

class _BottomWavePainter extends CustomPainter {
  final double phase;

  const _BottomWavePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(phase * math.pi) * size.height * 0.04;
    final fill = Path()
      ..moveTo(0, size.height * 0.27)
      ..cubicTo(
        size.width * 0.19,
        -size.height * 0.02 + drift,
        size.width * 0.39,
        size.height * 0.10 + drift,
        size.width * 0.56,
        size.height * 0.43,
      )
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.74,
        size.width * 0.88,
        size.height * 0.73,
        size.width,
        size.height * 0.62,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = AppColors.brand.withValues(alpha: 0.93));

    final line = Path()
      ..moveTo(0, size.height * 0.47)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.28 + drift,
        size.width * 0.42,
        size.height * 0.39 + drift,
        size.width * 0.61,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.89,
        size.width * 0.91,
        size.height * 0.84,
        size.width,
        size.height * 0.76,
      );
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BottomWavePainter oldDelegate) =>
      oldDelegate.phase != phase;
}
