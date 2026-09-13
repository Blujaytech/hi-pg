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

/// First route on every cold start. It continues exactly where Android's
/// native splash stops -- same black, same mark, same size and position --
/// then plays the brand moment: the house hops and winks, glides left while
/// "hi pg" springs in letter by letter, then rushes toward the camera as the
/// screen floods white and opens into the (white) app.
///
/// Session restore (AuthState.bootstrap) runs in parallel; the hand-off goes
/// to the welcome screen or the signed-in role's home once both are done.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Choreography, as fractions of the controller's duration.
abstract final class _Timeline {
  static const duration = Duration(milliseconds: 3000);
  static const bounce = (.05, .26);
  static const wink = (.17, .29);
  static const move = (.27, .47);
  static const lettersStart = .40;
  static const letterStagger = .045;
  static const letterDuration = .15;
  static const tagline = (.58, .70);
  static const blink = (.74, .79);
  static const zoom = (.84, 1.0);

  /// Share of the zoom over which the screen floods white. The flood is
  /// opaque well before the house would be drawn at its largest, so the
  /// final frames are a cheap solid fill rather than a huge path.
  static const flood = (.45, .8);

  /// Everything is on screen and still; used when animations are disabled.
  static const lockupComplete = .72;
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _launchChannel = MethodChannel('hipg/launch');

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _Timeline.duration);
  late final AuthState _auth;
  _Geometry? _geometry;
  bool _animationDone = false;
  bool _handedOff = false;

  // Squash-and-stretch hop, anchored at the base of the mark.
  static final _squashX = _sequence([1, 1.1, .94, 1.05, 1]);
  static final _squashY = _sequence([1, .86, 1.1, .93, 1]);
  static final _hop = _sequence([0, 0, -.17, 0, 0]);
  static final _closeAndOpen = _sequence([0, 1, 1, 0]);

  static TweenSequence<double> _sequence(List<double> stops) {
    return TweenSequence([
      for (var i = 0; i < stops.length - 1; i++)
        TweenSequenceItem(
          tween: Tween(begin: stops[i], end: stops[i + 1])
              .chain(CurveTween(curve: Curves.easeInOutSine)),
          weight: 1,
        ),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthState>()..addListener(_handOffWhenReady);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    // Android 12+ keeps its system splash on top of these first frames until
    // the platform removes it; MainActivity answers once it is gone (or
    // decides no splash was shown) so the opening beats are never played
    // unseen. The timeout is only a last-resort safety net.
    try {
      await _launchChannel
          .invokeMethod<void>('systemSplashGone')
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Older Android, other platforms and tests: nothing to wait for.
    }
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _Timeline.lockupComplete;
      Future<void>.delayed(const Duration(milliseconds: 700), _onAnimationDone);
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
      AuthStatus.authenticated =>
        _auth.role == UserRole.owner ? '/owner' : '/student',
      _ => '/',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('launch-animation'),
      backgroundColor: AppColors.ink,
      body: Semantics(
        label: 'hi pg',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final geometry = _geometry?.size == size
                  ? _geometry!
                  : _geometry = _Geometry(size);
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _frame(geometry, _controller.value),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _frame(_Geometry g, double t) {
    final bounce = _progress(t, _Timeline.bounce);
    final zoom = _progress(t, _Timeline.zoom);
    final flood = Curves.easeInCubic.transform(_progress(zoom, _Timeline.flood));
    final lockupOpacity = 1 - (zoom * 3).clamp(0.0, 1.0);
    final tagline =
        Curves.easeOutCubic.transform(_progress(t, _Timeline.tagline));

    final double markSize;
    final Offset markTopLeft;
    if (zoom > 0) {
      // Rush into the house: grow it around the middle of its body.
      // Exponential growth reads as a steady zoom; easing the exponent makes
      // it accelerate toward the camera.
      markSize = _Geometry.endMark *
          math
              .pow(g.coverSize / _Geometry.endMark,
                  Curves.easeInQuad.transform(zoom))
              .toDouble();
      markTopLeft = g.zoomAnchor -
          Offset(markSize * _Geometry.anchorX, markSize * _Geometry.anchorY);
    } else {
      final move =
          Curves.easeInOutCubic.transform(_progress(t, _Timeline.move));
      markSize = lerpDouble(g.startMark, _Geometry.endMark, move)!;
      final center = Offset.lerp(g.center, g.endMarkCenter, move)!;
      markTopLeft = Offset(
        center.dx - markSize / 2,
        center.dy - markSize / 2 + _hop.transform(bounce) * g.startMark,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: flood > .5 ? AppTheme.lightChrome : AppTheme.darkChrome,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < _Geometry.letters.length; i++)
            _letter(g, i, t, lockupOpacity),
          if (flood < 1)
            Positioned(
              left: markTopLeft.dx,
              top: markTopLeft.dy,
              width: markSize,
              height: markSize,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(
                  _squashX.transform(bounce),
                  _squashY.transform(bounce),
                  1,
                ),
                child: HiPgMark(
                  size: markSize,
                  color: AppColors.surface,
                  // The face melts away as the house rushes in.
                  faceColor: Color.lerp(AppColors.ink, AppColors.surface,
                      (zoom * 4).clamp(0.0, 1.0)),
                  wink: _closeAndOpen.transform(_progress(t, _Timeline.wink)),
                  blink:
                      _closeAndOpen.transform(_progress(t, _Timeline.blink)),
                  smile: lerpDouble(
                    .55,
                    1,
                    Curves.easeOut.transform(_progress(t, _Timeline.wink)),
                  )!,
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            top: g.center.dy + _Geometry.endMark / 2 + 30 + (1 - tagline) * 10,
            child: Opacity(
              opacity: tagline * lockupOpacity,
              child: Text(
                'Find a stay  ·  Run a PG',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .6),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3,
                ),
              ),
            ),
          ),
          if (flood > 0)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.surface.withValues(alpha: flood),
              ),
            ),
        ],
      ),
    );
  }

  Widget _letter(_Geometry g, int index, double t, double lockupOpacity) {
    final start = _Timeline.lettersStart + index * _Timeline.letterStagger;
    final pop = Curves.easeOutBack
        .transform(_progress(t, (start, start + _Timeline.letterDuration)));
    return Positioned(
      left: g.letterLeft(index),
      top: g.center.dy - _Geometry.fontSize * .56,
      child: Opacity(
        opacity: _progress(t, (start, start + .05)) * lockupOpacity,
        child: Transform.translate(
          offset: Offset(0, (1 - pop) * _Geometry.fontSize * .5),
          child: Transform.scale(
            scale: .45 + .55 * pop,
            alignment: Alignment.bottomCenter,
            child: Text(
              _Geometry.letters[index],
              textScaler: TextScaler.noScaling,
              style: brandWordStyle(_Geometry.fontSize, AppColors.surface),
            ),
          ),
        ),
      ),
    );
  }

  static double _progress(double t, (double, double) window) =>
      ((t - window.$1) / (window.$2 - window.$1)).clamp(0.0, 1.0);
}

/// Where everything sits for a given screen size. The start size matches the
/// native splash: splash_mark is a 288dp canvas and the mark fills
/// [HiPgMarkPainter.adaptiveMarkFraction] of it.
class _Geometry {
  static const letters = ['h', 'i', 'p', 'g'];
  static const double fontSize = 54;
  static const double endMark = 58;
  static const double gap = 14;

  /// Middle of the house body, as a fraction of the mark box; the closing
  /// zoom grows around this point.
  static const double anchorX = .5;
  static const double anchorY = .66;

  final Size size;
  final List<double> _letterWidths;

  _Geometry(this.size)
      : _letterWidths = [
          for (final letter in letters) _measure(letter),
        ];

  static double _measure(String letter) {
    final painter = TextPainter(
      text: TextSpan(
        text: letter,
        style: brandWordStyle(fontSize, Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double get startMark => 288 * HiPgMarkPainter.adaptiveMarkFraction;
  double get _space => fontSize * .24;
  Offset get center => size.center(Offset.zero);

  double get _lockupLeft {
    final word = _letterWidths.fold<double>(0, (a, b) => a + b) + _space;
    return center.dx - (endMark + gap + word) / 2;
  }

  Offset get endMarkCenter => Offset(_lockupLeft + endMark / 2, center.dy);

  Offset get zoomAnchor =>
      endMarkCenter + const Offset(0, endMark * (anchorY - .5));

  /// Mark size at which the solid part of the house body (about x .12-.88,
  /// y .48-.82 of the mark box) would cover the whole screen around
  /// [zoomAnchor]; the zoom heads here while the white flood takes over.
  double get coverSize {
    final a = zoomAnchor;
    return [
          a.dx / (anchorX - .12),
          (size.width - a.dx) / (.88 - anchorX),
          a.dy / (anchorY - .48),
          (size.height - a.dy) / (.82 - anchorY),
        ].reduce(math.max) *
        1.05;
  }

  double letterLeft(int index) {
    var left = _lockupLeft + endMark + gap;
    for (var i = 0; i < index; i++) {
      left += _letterWidths[i];
    }
    return index >= 2 ? left + _space : left;
  }
}
