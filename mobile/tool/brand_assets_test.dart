// Regenerates every Android launcher-icon and native-splash bitmap from the
// same HiPgMarkPainter the app draws at runtime, so the brand never drifts
// between the home screen, the splash and the in-app logo.
//
// Run from mobile/ after changing the mark:
//   flutter test tool/brand_assets_test.dart
//
// Lives under tool/ (not test/) so a normal `flutter test` never rewrites
// resources as a side effect.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_platform_mobile/core/theme.dart';
import 'package:pg_platform_mobile/shared/brand/hi_pg_brand.dart';

const _res = 'android/app/src/main/res';
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

Future<void> _render(
    String path, int pixels, void Function(Canvas, double) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder), pixels.toDouble());
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void _mark(Canvas canvas, Offset center, double size, {Color? face}) {
  canvas.save();
  canvas.translate(center.dx - size / 2, center.dy - size / 2);
  HiPgMarkPainter(color: AppColors.surface, faceColor: face)
      .paint(canvas, Size.square(size));
  canvas.restore();
}

/// Transparent canvas, white mark with a cut-out face, sized to Android's
/// adaptive-icon safe zone. Doubles as the themed (monochrome) icon layer
/// and the Android 12+ splash icon.
void _foreground(Canvas canvas, double size) => _mark(
      canvas,
      Offset(size / 2, size / 2),
      size * HiPgMarkPainter.adaptiveMarkFraction,
    );

/// Pre-Android 8 launchers: a full black tile (square or round) with the mark.
void _legacy(Canvas canvas, double size, {required bool round}) {
  final inset = size * 2 / 48;
  final tile = Rect.fromLTRB(inset, inset, size - inset, size - inset);
  final paint = Paint()..color = AppColors.ink;
  if (round) {
    canvas.drawOval(tile, paint);
  } else {
    canvas.drawRRect(
        RRect.fromRectAndRadius(tile, Radius.circular(size * .22)), paint);
  }
  _mark(canvas, tile.center, size * (round ? .54 : .6), face: AppColors.ink);
}

void main() {
  testWidgets('generate Android launcher icons and splash', (tester) async {
    await tester.runAsync(() async {
      for (final density in _densities.entries) {
        final d = density.value;
        await _render('$_res/mipmap-${density.key}/ic_launcher.png',
            (48 * d).round(), (c, s) => _legacy(c, s, round: false));
        await _render('$_res/mipmap-${density.key}/ic_launcher_round.png',
            (48 * d).round(), (c, s) => _legacy(c, s, round: true));
        await _render('$_res/mipmap-${density.key}/ic_launcher_foreground.png',
            (108 * d).round(), _foreground);
        await _render('$_res/drawable-${density.key}/splash_mark.png',
            (288 * d).round(), _foreground);
      }
      // Store listing icon (Play Console wants 512x512, full-bleed).
      await _render('android/app/src/main/ic_launcher-playstore.png', 512,
          (canvas, size) {
        canvas.drawRect(
            Offset.zero & Size.square(size), Paint()..color = AppColors.ink);
        _mark(canvas, Offset(size / 2, size / 2), size * .6,
            face: AppColors.ink);
      });
    });
  });
}
