import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makan_mana/app/opening/reels_art.dart';

/// The launcher icons and the system splash are files the platforms read
/// before Flutter starts, so they are written from the app's own drawing
/// rather than kept by hand. Run with --dart-define=UPDATE_ICONS=true to
/// rewrite them; otherwise this checks the committed vector files still
/// match the drawing (docs/decisions.md 020).
const bool update = bool.fromEnvironment('UPDATE_ICONS');
const String res = 'android/app/src/main/res';

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _path(ArtShape s, String indent, {Color? only}) {
  final StringBuffer b = StringBuffer('$indent<path\n')
    ..write('$indent    android:pathData="${s.path.data}"');
  if (s.fill case final Color c) {
    b.write('\n$indent    android:fillColor="${_hex(only ?? c)}"');
  }
  if (s.stroke case final Color c) {
    b
      ..write('\n$indent    android:strokeColor="${_hex(only ?? c)}"')
      ..write('\n$indent    android:strokeWidth="${s.strokeWidth}"')
      ..write('\n$indent    android:strokeLineCap="round"')
      ..write('\n$indent    android:strokeLineJoin="round"');
  }
  return '$b />';
}

/// A vector drawable of the reels: [mono] for Android's themed icon (one
/// colour, frame as an outline), [splash] for the system splash (reels
/// still rolling, no sparks).
String vectorXml({bool mono = false, bool splash = false}) {
  const Color white = Color(0xFFFFFFFF);
  final Color? only = mono ? white : null;
  final double t = splash ? 0 : 1;
  final String size = splash ? '288dp' : '108dp';
  final List<ArtShape> body = ReelsArt.body(outline: mono);
  final StringBuffer b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
      '<!-- Written by test/app/opening/reels_art_export_test.dart from '
      'lib/app/opening/reels_art.dart; do not edit by hand. -->',
    )
    ..writeln(
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
    )
    ..writeln('    android:width="$size"')
    ..writeln('    android:height="$size"')
    ..writeln('    android:viewportWidth="108"')
    ..writeln('    android:viewportHeight="108">')
    ..writeln(_path(body.first, '    ', only: only));
  for (int j = 0; j < 3; j++) {
    final Rect w = ReelsArt.window(j);
    b
      ..writeln('    <group>')
      ..writeln('        <clip-path')
      ..writeln(
        '            android:pathData="'
        '${ArtPath.roundRect(w.left, w.top, w.width, w.height, 3).data}" />',
      );
    for (final ArtShape s in ReelsArt.reel(j, ReelsArt.reelPosition(j, t))) {
      b.writeln(_path(s, '        ', only: only));
    }
    b.writeln('    </group>');
  }
  for (final ArtShape s in body.skip(1)) {
    b.writeln(_path(s, '    ', only: only));
  }
  if (!splash) {
    for (final ArtShape s in ReelsArt.sparks()) {
      b.writeln(_path(s, '    ', only: only));
    }
  }
  b.write('</vector>\n');
  return b.toString();
}

/// The icon as a PNG [px] square: [crop] units of the 108-unit canvas
/// around its middle, on ink; [round] masks it to a circle.
Future<Uint8List> png(
  int px, {
  required double crop,
  bool round = false,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final double scale = px / crop;
  if (round) {
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, px * 1.0, px * 1.0)));
  }
  canvas.drawRect(
    Rect.fromLTWH(0, 0, px * 1.0, px * 1.0),
    Paint()..color = ReelsArt.ink,
  );
  paintReels(
    canvas,
    t: 1,
    scale: scale,
    origin: Offset(-(108 - crop) / 2 * scale, -(108 - crop) / 2 * scale),
  );
  final ui.Image image = await recorder.endRecording().toImage(px, px);
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> vectors = <String, String>{
    '$res/drawable/ic_launcher_foreground.xml': vectorXml(),
    '$res/drawable/ic_launcher_monochrome.xml': vectorXml(mono: true),
    '$res/drawable/splash_reels.xml': vectorXml(splash: true),
  };

  test('the Android icon and splash files match the drawing', () {
    for (final MapEntry<String, String> e in vectors.entries) {
      final File f = File(e.key);
      if (update) {
        f.writeAsStringSync(e.value);
      } else {
        expect(
          f.readAsStringSync().replaceAll('\r\n', '\n'),
          e.value,
          reason: '${e.key} is out of date: rerun with UPDATE_ICONS=true',
        );
      }
    }
  });

  test('everything that shows stays inside the launcher safe circle', () {
    // Android's safe zone: a circle of 33 units round the canvas middle.
    final List<ArtShape> shapes = <ArtShape>[
      ...ReelsArt.body(),
      ...ReelsArt.sparks(),
    ];
    for (final ArtShape s in shapes) {
      // Walk each outline and take its furthest point from the middle.
      double far = 0;
      for (final ui.PathMetric m in s.path.toPath().computeMetrics()) {
        for (double d = 0; d <= m.length; d += 0.25) {
          final Offset at = m.getTangentForOffset(d)!.position;
          final double r = (at - const Offset(54, 54)).distance;
          if (r > far) far = r;
        }
      }
      if (s.stroke != null) far += s.strokeWidth / 2;
      expect(far, lessThanOrEqualTo(33), reason: '${s.path.data} reaches $far');
    }
  });

  test('the reels stop on bowl, burger and cup', () {
    final List<int> shown = <int>[
      for (int j = 0; j < 3; j++)
        ReelsArt.symbolAt(ReelsArt.reelPosition(j, 1).round(), j),
    ];
    expect(shown, <int>[0, 1, 2]);
    // At the start each reel is on a whole row too, so the system splash
    // shows whole symbols.
    for (int j = 0; j < 3; j++) {
      final double p = ReelsArt.reelPosition(j, 0);
      expect(p, p.roundToDouble());
    }
  });

  test('writes the PNG icons', () async {
    // Legacy Android launchers (API 24 and 25) take a round PNG.
    const Map<String, int> mipmaps = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final MapEntry<String, int> e in mipmaps.entries) {
      File(
        '$res/mipmap-${e.key}/ic_launcher.png',
      ).writeAsBytesSync(await png(e.value, crop: 72, round: true));
    }
    // iOS masks its own corners, so the PNGs are full squares, opaque.
    const String ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final RegExp name = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png');
    for (final FileSystemEntity f in Directory(ios).listSync()) {
      final RegExpMatch? m = name.firstMatch(f.uri.pathSegments.last);
      if (m == null) continue;
      final int px = (double.parse(m[1]!) * int.parse(m[2]!)).round();
      File(f.path).writeAsBytesSync(await png(px, crop: 80));
    }
  }, skip: update ? false : 'only with UPDATE_ICONS=true');
}
