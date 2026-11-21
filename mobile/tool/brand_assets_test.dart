// Generates Android launcher icons and the matching native launch mark from
// the Hi PG palette and typeface. The cinematic Flutter splash remains an
// independent in-app asset.
//
// Run from mobile/ after changing the launcher source:
//   powershell -ExecutionPolicy Bypass -File tool/generate_brand_assets.ps1
//
// Lives under tool/ (not test/) so a normal `flutter test` never rewrites
// resources as a side effect.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _outputRoot = 'build/generated_launcher_assets';
const _res = '$_outputRoot/android/app/src/main/res';
const _iconFont = 'assets/fonts/Inter-ExtraBold.ttf';
const _iconFontFamily = 'HiPgIconInter';
const _plainLogoAsset = 'assets/branding/hi_pg_logo_plain.png';
late ui.Image _plainLogo;
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
  await File(path)
      .create(recursive: true)
      .then((file) => file.writeAsBytes(png!.buffer.asUint8List()));
}

Future<void> _loadIconFont() async {
  final bytes = await File(_iconFont).readAsBytes();
  await (FontLoader(_iconFontFamily)
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}

Future<void> _loadPlainLogo() async {
  final bytes = await File(_plainLogoAsset).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  _plainLogo = frame.image;
  codec.dispose();
}

void _background(Canvas canvas, double size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFFFFFAFB),
  );
}

void _wordmark(Canvas canvas, double size, {required bool adaptive}) {
  final fontSize = size * (adaptive ? 0.235 : 0.285);
  final painter = TextPainter(
    text: TextSpan(
      style: TextStyle(
        fontFamily: _iconFontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -fontSize * 0.065,
      ),
      children: const [
        TextSpan(text: 'hi', style: TextStyle(color: Color(0xFF77797F))),
        TextSpan(text: 'pg', style: TextStyle(color: Color(0xFFF84464))),
      ],
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      (size - painter.width) / 2,
      (size - painter.height) / 2 - size * 0.012,
    ),
  );
  painter.dispose();
}

void _launcher(Canvas canvas, double size) {
  _background(canvas, size);
  _wordmark(canvas, size, adaptive: false);
}

void _adaptiveForeground(Canvas canvas, double size) {
  _wordmark(canvas, size, adaptive: true);
}

void _nativeSplashMark(Canvas canvas, double size) {
  canvas.drawColor(Colors.white, BlendMode.src);
  const source = Rect.fromLTWH(270, 422, 715, 397);
  final width = size * .5;
  final height = width * source.height / source.width;
  final destination = Rect.fromLTWH(
    (size - width) / 2,
    (size - height) / 2,
    width,
    height,
  );
  canvas.drawImageRect(
    _plainLogo,
    source,
    destination,
    Paint()..filterQuality = FilterQuality.high,
  );
}

void _notificationMark(Canvas canvas, double size) {
  final fontSize = size * .29;
  final painter = TextPainter(
    text: TextSpan(
      text: 'hipg',
      style: TextStyle(
        color: Colors.white,
        fontFamily: _iconFontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: -fontSize * .065,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  painter.paint(
    canvas,
    Offset((size - painter.width) / 2, (size - painter.height) / 2),
  );
  painter.dispose();
}

void main() {
  testWidgets('generate Android launcher icons', (tester) async {
    await tester.runAsync(() async {
      await _loadIconFont();
      await _loadPlainLogo();
      for (final density in _densities.entries) {
        final d = density.value;
        await _render('$_res/mipmap-${density.key}/ic_launcher.png',
            (48 * d).round(), _launcher);
        await _render('$_res/mipmap-${density.key}/ic_launcher_round.png',
            (48 * d).round(), _launcher);
        await _render('$_res/mipmap-${density.key}/ic_launcher_foreground.png',
            (108 * d).round(), _adaptiveForeground);
        await _render('$_res/drawable-${density.key}/splash_mark.png',
            (288 * d).round(), _nativeSplashMark);
        await _render('$_res/drawable-${density.key}/ic_stat_hipg.png',
            (24 * d).round(), _notificationMark);
      }
      await _render(
        '$_outputRoot/android/app/src/main/ic_launcher-playstore.png',
        512,
        _launcher,
      );
      _plainLogo.dispose();
    });
  });
}
