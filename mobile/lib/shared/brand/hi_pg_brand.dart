import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The hi pg mark: a house-shaped speech bubble with a friendly face --
/// "hi" + home. This painter is the single source of the brand geometry:
/// the in-app logo, the launch animation and the generated Android launcher
/// icons / native splash (see tool/brand_assets_test.dart) all draw it.
///
/// Geometry is authored in a 100x100 "mark space" and scaled to fit.
class HiPgMarkPainter extends CustomPainter {
  /// Colour of the house bubble.
  final Color color;

  /// Colour of the eyes and smile. `null` cuts the face out of the house so
  /// whatever is behind the mark shows through (used for launcher icons).
  final Color? faceColor;

  /// 0 = eyes open, 1 = both eyes closed.
  final double blink;

  /// 0 = right eye open, 1 = right eye closed (a wink).
  final double wink;

  /// 0 = small smile, 1 = full grin.
  final double smile;

  const HiPgMarkPainter({
    required this.color,
    this.faceColor,
    this.blink = 0,
    this.wink = 0,
    this.smile = .55,
  });

  /// Fraction of a 108dp adaptive-icon / 288dp splash canvas the mark box
  /// occupies. Kept here so the Flutter launch animation can start at exactly
  /// the size Android's native splash drew it.
  static const double adaptiveMarkFraction = 52 / 108;

  static final Path _house = _buildHouse();

  static Path _buildHouse() {
    final body = _roundedPolygon(const [
      Offset(50, 4), // roof apex
      Offset(94, 45), // right eave
      Offset(94, 86), // bottom right
      Offset(45, 86), // speech tail starts
      Offset(21, 99), // speech tail tip
      Offset(28, 86), // speech tail ends
      Offset(6, 86), // bottom left
      Offset(6, 45), // left eave
    ], const [
      13,
      8,
      12,
      5,
      3,
      4,
      12,
      8
    ]);
    final chimney = Path()
      ..addRRect(RRect.fromLTRBR(70, 12, 81, 34, const Radius.circular(2.5)));
    return Path.combine(PathOperation.union, body, chimney);
  }

  /// A closed polygon whose corners are softened with quadratic curves;
  /// `radii[i]` is how far along each edge corner `i` starts bending.
  static Path _roundedPolygon(List<Offset> points, List<double> radii) {
    final path = Path();
    final count = points.length;
    for (var i = 0; i < count; i++) {
      final previous = points[(i - 1 + count) % count];
      final current = points[i];
      final next = points[(i + 1) % count];
      final incoming = current - previous;
      final outgoing = next - current;
      final radius = math.min(
        radii[i],
        math.min(incoming.distance, outgoing.distance) / 2,
      );
      final start = current - incoming / incoming.distance * radius;
      final end = current + outgoing / outgoing.distance * radius;
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);

    // A `null` faceColor clears the face out of the house, which needs an
    // offscreen layer. Painted faces skip it: the launch animation zooms the
    // mark far past screen size, where a layer would be very expensive.
    final cutOut = faceColor == null;
    if (cutOut) {
      canvas.saveLayer(const Rect.fromLTWH(-4, -4, 108, 108), Paint());
    }
    canvas.drawPath(_house, Paint()..color = color);

    final face = Paint();
    if (cutOut) {
      face.blendMode = BlendMode.clear;
    } else {
      face.color = faceColor!;
    }
    _eye(canvas, const Offset(35, 60), blink, face);
    _eye(canvas, const Offset(65, 60), math.max(blink, wink), face);

    final grin = smile.clamp(0.0, 1.0);
    final sweep = 1.1 + 1.25 * grin;
    final radius = 7.2 + 2.2 * grin;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(50, 74 - radius), radius: radius),
      math.pi / 2 - sweep / 2,
      sweep,
      false,
      Paint()
        ..blendMode = face.blendMode
        ..color = face.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.4
        ..strokeCap = StrokeCap.round,
    );
    if (cutOut) canvas.restore();
    canvas.restore();
  }

  void _eye(Canvas canvas, Offset center, double closed, Paint paint) {
    final t = closed.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: 8.8 + 1.8 * t,
          height: 11 - 8.6 * t,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(HiPgMarkPainter old) =>
      old.color != color ||
      old.faceColor != faceColor ||
      old.blink != blink ||
      old.wink != wink ||
      old.smile != smile;
}

/// The bare mark (house bubble with a face) at any size.
class HiPgMark extends StatelessWidget {
  final double size;
  final Color color;
  final Color? faceColor;
  final double blink;
  final double wink;
  final double smile;

  const HiPgMark({
    super.key,
    this.size = 40,
    this.color = AppColors.brand,
    this.faceColor = AppColors.surface,
    this.blink = 0,
    this.wink = 0,
    this.smile = .55,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: HiPgMarkPainter(
        color: color,
        faceColor: faceColor,
        blink: blink,
        wink: wink,
        smile: smile,
      ),
    );
  }
}

/// The same full-colour icon Android displays on the home screen.
class HiPgAppIcon extends StatelessWidget {
  final double size;
  final bool elevated;

  const HiPgAppIcon({
    super.key,
    this.size = 56,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = ClipRRect(
      borderRadius: BorderRadius.circular(size * .23),
      child: Image.asset(
        'assets/branding/hi_pg_launcher_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
    if (!elevated) return icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .23),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: .16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: icon,
    );
  }
}

/// "hi pg" set in the brand weight. Always lowercase.
class HiPgWordmark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const HiPgWordmark({
    super.key,
    this.fontSize = 22,
    this.color = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'hi pg',
      style: brandWordStyle(fontSize, color),
    );
  }
}

/// The primary in-app Hi PG logo: a clean grey-and-rose wordmark with no
/// launcher tile, house badge, glow, or decorative background.
class HiPgPlainLogo extends StatelessWidget {
  final double fontSize;
  final Color hiColor;
  final Color pgColor;

  const HiPgPlainLogo({
    super.key,
    this.fontSize = 28,
    this.hiColor = const Color(0xFF77797F),
    this.pgColor = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'hi pg',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: brandWordStyle(fontSize, hiColor).copyWith(
              letterSpacing: -fontSize * .055,
            ),
            children: [
              TextSpan(text: 'hi', style: TextStyle(color: hiColor)),
              TextSpan(text: 'pg', style: TextStyle(color: pgColor)),
            ],
          ),
          maxLines: 1,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

TextStyle brandWordStyle(double fontSize, Color color) => TextStyle(
      fontFamily: AppTheme.fontFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * .03,
      // Keeps "hi" and "pg" reading as two words despite the tight tracking.
      wordSpacing: fontSize * .06,
      height: 1,
    );

/// Backwards-compatible lockup API. In-app branding now intentionally uses
/// only the clean wordmark; launcher artwork remains independent.
class HiPgLockup extends StatelessWidget {
  final double height;
  final Color color;
  final Color faceColor;
  final Color wordColor;

  const HiPgLockup({
    super.key,
    this.height = 28,
    this.color = AppColors.brand,
    this.faceColor = AppColors.surface,
    this.wordColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return HiPgPlainLogo(
      fontSize: height,
      hiColor: wordColor,
      pgColor: color,
    );
  }
}
