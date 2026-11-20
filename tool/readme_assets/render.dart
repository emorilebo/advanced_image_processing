// Renders the README and pub.dev visuals from real package output.
//
// Every photo tile and GIF frame is produced by this package's own engine.
// Headless Chrome only typesets the grids and labels (see render.sh).
//
//   tool/readme_assets/render.sh
//
// Stages (called by render.sh):
//   dart run tool/readme_assets/render.dart prepare <work-dir>
//   dart run tool/readme_assets/render.dart finish  <work-dir> <out-dir>

import 'dart:io';
import 'dart:math' as math;

import 'package:advanced_image_processing_toolkit/engine.dart';
import 'package:image/image.dart' as img;

const _sample = 'example/assets/sample_image.jpg';
const _people = 'example/assets/people_sample.jpg';
const _faces = 'tool/readme_assets/people_faces.txt';
// Produced by: (cd example && flutter test --dart-define=STUDIO_CAPTURE=true test/visual_test.dart)
const _appShots = 'example/build/qa';

const _bg = '#0B0C0F';
const _surface = '#15171C';
const _text = '#F2F3F5';
const _muted = '#9AA0AA';
const _accent = '#FF9F43';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: render.dart prepare <work> | finish <work> <out>');
    exit(64);
  }
  switch (args[0]) {
    case 'prepare':
      _prepare(Directory(args[1]));
    case 'finish':
      _finish(Directory(args[1]), Directory(args[2]));
    default:
      stderr.writeln('unknown stage ${args[0]}');
      exit(64);
  }
}

// ---------------------------------------------------------------------------
// Stage 1: tiles and HTML pages
// ---------------------------------------------------------------------------

void _prepare(Directory work) {
  work.createSync(recursive: true);
  final tiles = Directory('${work.path}/tiles')..createSync();
  final source = File(_sample).readAsBytesSync();
  final base = const ImagePipeline()
      .downscale(960)
      .runSync(source, output: const OutputFormat.jpeg(quality: 92))
      .bytes;
  File('${tiles.path}/original.jpg').writeAsBytesSync(base);

  void tile(String name, ImagePipeline p) {
    final r = p.runSync(base, output: const OutputFormat.jpeg(quality: 90));
    File('${tiles.path}/$name.jpg').writeAsBytesSync(r.bytes);
    stdout.writeln('  tile $name  ${r.processingTime.inMilliseconds} ms');
  }

  for (final preset in FilterPreset.all) {
    tile(preset.id, preset.pipeline);
  }
  final lut = CubeLut.parse(_tealOrangeCube());
  final effects = <String, (String, String, ImagePipeline)>{
    'fx_original': ('Original', 'no processing', const ImagePipeline()),
    'fx_auto': (
      'Auto enhance',
      '.autoEnhance()',
      const ImagePipeline().autoEnhance(),
    ),
    'fx_lut': ('.cube LUT', '.lut(tealOrange)', const ImagePipeline().lut(lut)),
    'fx_kuwahara': (
      'Painterly',
      '.kuwahara(radius: 6)',
      const ImagePipeline().kuwahara(radius: 6),
    ),
    'fx_oil': (
      'Oil paint',
      '.oilPaint(radius: 4)',
      const ImagePipeline().oilPaint(radius: 4, levels: 24),
    ),
    'fx_watercolor': (
      'Watercolor',
      '.watercolor(radius: 6)',
      const ImagePipeline().watercolor(radius: 6),
    ),
    'fx_sketch': (
      'Pencil sketch',
      '.sketch(sigma: 4)',
      const ImagePipeline().sketch(sigma: 4),
    ),
    'fx_edges': (
      'Ink edges',
      '.edges(invert: true)',
      const ImagePipeline().edges(invert: true),
    ),
    'fx_emboss': (
      'Emboss',
      '.emboss()',
      const ImagePipeline().emboss(strength: 1.5),
    ),
    'fx_film': (
      'Vignette + grain',
      '.vignette().grain()',
      const ImagePipeline().vignette(strength: 0.6).grain(amount: 0.2),
    ),
    'fx_blur': ('Gaussian blur', '.blur(8)', const ImagePipeline().blur(8)),
    'fx_pixelate': (
      'Pixelate',
      '.pixelate(24)',
      const ImagePipeline().pixelate(24),
    ),
  };
  for (final e in effects.entries) {
    tile(e.key, e.value.$3);
  }

  final pages = <String, (int, int)>{};

  // Preset grid.
  final presetCards = [
    for (final p in FilterPreset.all)
      _card('tiles/${p.id}.jpg', p.name, 'FilterPreset.${p.id}'),
  ];
  File('${work.path}/presets.html').writeAsStringSync(
    _gridPage(
      eyebrow: 'FilterPreset.all',
      title: '12 looks. Live on the GPU, identical on export.',
      cards: presetCards,
    ),
  );
  pages['presets'] = (1280, 860);

  // Effects grid.
  File('${work.path}/effects.html').writeAsStringSync(
    _gridPage(
      eyebrow: 'ImagePipeline',
      title: 'Tone, LUTs, painterly and detail effects.',
      cards: [
        for (final e in effects.entries)
          _card('tiles/${e.key}.jpg', e.value.$1, e.value.$2),
      ],
    ),
  );
  pages['effects'] = (1280, 860);

  // Hero banner: split comparison rendered by the engine.
  final heroSplit = _split(
    img.decodeJpg(base)!,
    img.decodeJpg(File('${tiles.path}/goldenHour.jpg').readAsBytesSync())!,
    0.5,
  );
  File(
    '${tiles.path}/hero_split.jpg',
  ).writeAsBytesSync(img.encodeJpg(heroSplit, quality: 90));
  File('${work.path}/hero.html').writeAsStringSync(_heroPage());
  pages['hero'] = (1280, 560);

  // Label sprites for the GIF.
  final labels = ['Original', ..._gifLooks.map((l) => l.$2)];
  for (var i = 0; i < labels.length; i++) {
    File('${work.path}/label_$i.html').writeAsStringSync(_labelPage(labels[i]));
    pages['label_$i'] = (220, 44);
  }

  // Redaction demo, if the synthetic people photo and face boxes exist.
  if (File(_people).existsSync() && File(_faces).existsSync()) {
    _prepareRedaction(tiles);
    File('${work.path}/redaction.html').writeAsStringSync(_redactionPage());
    pages['redaction'] = (1280, 600);
  } else {
    stdout.writeln('  (skipping redaction demo: $_people or $_faces missing)');
  }

  // Example app showcase, if the visual test has captured screenshots.
  final shots = ['studio-1600', 'studio-390', 'privacy-390'];
  if (shots.every((s) => File('$_appShots/$s.png').existsSync())) {
    for (final s in shots) {
      File('$_appShots/$s.png').copySync('${tiles.path}/$s.png');
    }
    File('${work.path}/app.html').writeAsStringSync(_appPage());
    pages['app'] = (1280, 640);
  } else {
    stdout.writeln(
      '  (skipping app showcase: run the example visual test first)',
    );
  }

  File('${work.path}/pages.txt').writeAsStringSync(
    [
      for (final e in pages.entries) '${e.key} ${e.value.$1} ${e.value.$2}',
    ].map((line) => '$line\n').join(),
  );
}

const _gifLooks = [
  ('goldenHour', 'Golden Hour'),
  ('noir', 'Noir'),
  ('fx_watercolor', 'Watercolor'),
  ('dusk', 'Dusk'),
];

void _prepareRedaction(Directory tiles) {
  final bytes = File(_people).readAsBytesSync();
  final faces = [
    for (final line in File(_faces).readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        () {
          final v = line.split(RegExp(r'[\s,]+')).map(double.parse).toList();
          return math.Rectangle<double>(v[0], v[1], v[2], v[3]);
        }(),
  ];
  final original = const ImagePipeline()
      .downscale(1200)
      .runSync(bytes, output: const OutputFormat.jpeg(quality: 90));
  final source = img.decodeJpg(bytes)!;
  final scale = original.width / source.width;
  final scaled = [
    for (final f in faces)
      math.Rectangle<double>(
        f.left * scale,
        f.top * scale,
        f.width * scale,
        f.height * scale,
      ),
  ];
  File('${tiles.path}/people_original.jpg').writeAsBytesSync(original.bytes);
  final redacted = const ImagePipeline()
      .redact(scaled, padding: 0.15)
      .runSync(original.bytes, output: const OutputFormat.jpeg(quality: 90));
  File('${tiles.path}/people_redacted.jpg').writeAsBytesSync(redacted.bytes);
}

String _card(String src, String name, String code) =>
    '''
<figure>
  <img src="$src" alt="">
  <figcaption><span class="name">$name</span><code>$code</code></figcaption>
</figure>''';

String _styles() =>
    '''
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body { background: $_bg; color: $_text; font-family: Inter, -apple-system, sans-serif;
    -webkit-font-smoothing: antialiased; }
  code { font-family: "JetBrains Mono", ui-monospace, monospace; }
</style>''';

String _gridPage({
  required String eyebrow,
  required String title,
  required List<String> cards,
}) =>
    '''<!doctype html><html><head><meta charset="utf-8">${_styles()}
<style>
  body { padding: 36px 40px; }
  .eyebrow { color: $_accent; font: 600 13px/1 "JetBrains Mono", monospace; letter-spacing: .04em; }
  h1 { font-size: 26px; font-weight: 700; letter-spacing: -.02em; margin: 10px 0 24px; }
  .grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }
  figure { background: $_surface; border: 1px solid #23262D; border-radius: 14px; overflow: hidden; }
  figure img { display: block; width: 100%; aspect-ratio: 3 / 2; object-fit: cover; }
  figcaption { display: flex; justify-content: space-between; align-items: baseline; gap: 8px;
    padding: 9px 12px 10px; }
  .name { font-weight: 600; font-size: 14px; }
  figcaption code { color: $_muted; font-size: 10.5px; white-space: nowrap; overflow: hidden;
    text-overflow: ellipsis; }
</style></head><body>
<div class="eyebrow">$eyebrow</div>
<h1>$title</h1>
<div class="grid">${cards.join()}</div>
</body></html>''';

String _heroPage() =>
    '''<!doctype html><html><head><meta charset="utf-8">${_styles()}
<style>
  body { width: 1280px; height: 560px; display: grid; grid-template-columns: 520px 1fr;
    align-items: center; gap: 40px; padding: 48px 48px 48px 56px;
    background: radial-gradient(1200px 600px at 85% 30%, #1A1712 0%, $_bg 60%); }
  .eyebrow { color: $_accent; font: 600 14px/1 "JetBrains Mono", monospace; letter-spacing: .03em; }
  h1 { font-size: 46px; line-height: 1.04; font-weight: 800; letter-spacing: -.035em; margin: 16px 0 18px; }
  p { color: #C4C8CF; font-size: 17px; line-height: 1.5; max-width: 470px; }
  .chips { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 26px; }
  .chip { border: 1px solid #2A2E36; background: $_surface; color: #D9DCE1; border-radius: 999px;
    padding: 7px 12px; font-size: 13px; font-weight: 500; }
  .shot { position: relative; border-radius: 18px; overflow: hidden; border: 1px solid #2A2E36;
    box-shadow: 0 30px 80px rgba(0,0,0,.55); }
  .shot img { display: block; width: 100%; }
  .tag { position: absolute; top: 14px; padding: 6px 11px; border-radius: 999px; font-size: 12px;
    font-weight: 600; background: rgba(11,12,15,.72); backdrop-filter: blur(6px); }
  .tag.l { left: 14px; } .tag.r { right: 14px; color: $_accent; }
  .handle { position: absolute; left: 50%; top: 50%; width: 42px; height: 42px; margin: -21px 0 0 -21px;
    border-radius: 50%; background: #fff; box-shadow: 0 4px 14px rgba(0,0,0,.4);
    display: grid; place-items: center; color: #1F2328; font: 700 16px/1 Inter; letter-spacing: -2px; }
  .line { position: absolute; left: 50%; top: 0; bottom: 0; width: 2px; margin-left: -1px; background: #fff; }
</style></head><body>
<div>
  <div class="eyebrow">advanced_image_processing_toolkit</div>
  <h1>Fast, private image processing for Flutter.</h1>
  <p>Chain any edit into one pipeline that decodes once, runs off the UI thread and strips location data on export.</p>
  <div class="chips">
    <span class="chip">Background isolates</span><span class="chip">Live GPU presets</span>
    <span class="chip">.cube LUTs</span><span class="chip">Face &amp; text redaction</span>
    <span class="chip">EXIF / GPS stripping</span><span class="chip">ML Kit detection</span>
  </div>
</div>
<div class="shot">
  <img src="tiles/hero_split.jpg" alt="">
  <div class="line"></div><div class="handle">‹ ›</div>
  <span class="tag l">Original</span><span class="tag r">FilterPreset.goldenHour</span>
</div>
</body></html>''';

String _labelPage(String text) =>
    '''<!doctype html><html><head><meta charset="utf-8">${_styles()}
<style>
  html, body { background: transparent; }
  body { width: 220px; height: 44px; display: flex; align-items: center; padding-left: 6px; }
  span { display: inline-block; padding: 7px 13px; border-radius: 999px; font-size: 15px; font-weight: 600;
    color: #fff; background: rgba(11,12,15,.78); }
</style></head><body><span>$text</span></body></html>''';

String _redactionPage() =>
    '''<!doctype html><html><head><meta charset="utf-8">${_styles()}
<style>
  body { padding: 34px 40px; }
  .eyebrow { color: $_accent; font: 600 13px/1 "JetBrains Mono", monospace; }
  h1 { font-size: 24px; font-weight: 700; letter-spacing: -.02em; margin: 10px 0 20px; }
  .row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
  figure { position: relative; border-radius: 14px; overflow: hidden; border: 1px solid #23262D; }
  figure img { display: block; width: 100%; aspect-ratio: 3 / 2; object-fit: cover; }
  figcaption { position: absolute; left: 12px; top: 12px; padding: 6px 11px; border-radius: 999px;
    background: rgba(11,12,15,.78); font-size: 12.5px; font-weight: 600; }
  .note { color: $_muted; font-size: 12px; margin-top: 12px; }
</style></head><body>
<div class="eyebrow">ImagePipeline().redact(faces)</div>
<h1>Faces hidden on device. EXIF and GPS stripped on export.</h1>
<div class="row">
  <figure><img src="tiles/people_original.jpg" alt=""><figcaption>Input</figcaption></figure>
  <figure><img src="tiles/people_redacted.jpg" alt=""><figcaption>Output</figcaption></figure>
</div>
<p class="note">Synthetic photo, no real people. On Android and iOS, ObjectRecognition.redactFromPath finds the faces with ML Kit and applies this same step.</p>
</body></html>''';

String _appPage() =>
    '''<!doctype html><html><head><meta charset="utf-8">${_styles()}
<style>
  body { width: 1280px; height: 640px; padding: 36px 40px; overflow: hidden;
    background: radial-gradient(900px 500px at 20% 0%, #1A1712 0%, $_bg 65%); }
  .eyebrow { color: $_accent; font: 600 13px/1 "JetBrains Mono", monospace; }
  h1 { font-size: 24px; font-weight: 700; letter-spacing: -.02em; margin: 10px 0 22px; }
  .stage { display: flex; gap: 22px; align-items: flex-start; }
  .desk { width: 800px; border-radius: 14px; overflow: hidden; border: 1px solid #2A2E36;
    box-shadow: 0 24px 60px rgba(0,0,0,.5); }
  .desk img, .phone img { display: block; width: 100%; }
  .phone { width: 176px; border-radius: 26px; overflow: hidden; border: 6px solid #1E2128;
    box-shadow: 0 24px 60px rgba(0,0,0,.5); }
  .phone:nth-child(3) { margin-top: 40px; }
</style></head><body>
<div class="eyebrow">example/ · Toolkit Studio</div>
<h1>The example app is a complete, private photo studio.</h1>
<div class="stage">
  <div class="desk"><img src="tiles/studio-1600.png" alt=""></div>
  <div class="phone"><img src="tiles/studio-390.png" alt=""></div>
  <div class="phone"><img src="tiles/privacy-390.png" alt=""></div>
</div>
</body></html>''';

// ---------------------------------------------------------------------------
// Stage 2: encode screenshots and the GIF
// ---------------------------------------------------------------------------

void _finish(Directory work, Directory out) {
  out.createSync(recursive: true);
  for (final name in ['hero', 'presets', 'effects', 'redaction', 'app']) {
    final png = File('${work.path}/$name.png');
    if (!png.existsSync()) continue;
    final result = const ImagePipeline().runSync(
      png.readAsBytesSync(),
      output: const OutputFormat.jpeg(quality: 86),
      maxInputPixels: 20000000,
    );
    File('${out.path}/$name.jpg').writeAsBytesSync(result.bytes);
    stdout.writeln(
      '  ${out.path}/$name.jpg  ${result.width}x${result.height}  '
      '${(result.bytes.length / 1024).round()} KB',
    );
  }
  _gif(work, out);
}

void _gif(Directory work, Directory out) {
  const width = 560;
  img.Image load(String name) => img.copyResize(
    img.decodeJpg(File('${work.path}/tiles/$name.jpg').readAsBytesSync())!,
    width: width,
    interpolation: img.Interpolation.average,
  );
  img.Image label(int i) {
    final sprite = _trim(
      img.decodePng(File('${work.path}/label_$i.png').readAsBytesSync())!,
    );
    return img.copyResize(
      sprite,
      width: sprite.width ~/ 2,
      interpolation: img.Interpolation.average,
    );
  }

  final before = load('original');
  final beforeLabel = label(0);
  final encoder = img.GifEncoder(samplingFactor: 5, ditherStrength: 0.35);
  const wipeFrames = 6;
  for (var i = 0; i < _gifLooks.length; i++) {
    final after = load(_gifLooks[i].$1);
    final afterLabel = label(i + 1);
    for (var f = 0; f <= wipeFrames; f++) {
      final t = f / wipeFrames;
      final eased = t * t * (3 - 2 * t);
      final position =
          0.92 - 0.42 * eased; // divider glides from right to centre
      final frame = _split(before, after, position, handle: true);
      img.compositeImage(frame, beforeLabel, dstX: 10, dstY: 10);
      img.compositeImage(
        frame,
        afterLabel,
        dstX: frame.width - afterLabel.width - 10,
        dstY: 10,
      );
      encoder.addFrame(frame, duration: f == wipeFrames ? 150 : 6);
    }
  }
  final bytes = encoder.finish()!;
  File('${out.path}/presets.gif').writeAsBytesSync(bytes);
  stdout.writeln(
    '  ${out.path}/presets.gif  ${(bytes.length / 1024).round()} KB',
  );
}

/// Crops a sprite to its non-transparent pixels.
img.Image _trim(img.Image sprite) {
  var x0 = sprite.width, y0 = sprite.height, x1 = -1, y1 = -1;
  for (final p in sprite) {
    if (p.a > 8) {
      if (p.x < x0) x0 = p.x;
      if (p.y < y0) y0 = p.y;
      if (p.x > x1) x1 = p.x;
      if (p.y > y1) y1 = p.y;
    }
  }
  if (x1 < 0) return sprite;
  return img.copyCrop(
    sprite,
    x: x0,
    y: y0,
    width: x1 - x0 + 1,
    height: y1 - y0 + 1,
  );
}

/// Left of [position] shows [before], right shows [after], with a divider.
img.Image _split(
  img.Image before,
  img.Image after,
  double position, {
  bool handle = false,
}) {
  final out = img.Image.from(after.convert(numChannels: 3));
  final split = (out.width * position).round();
  final left = img.copyCrop(
    before.convert(numChannels: 3),
    x: 0,
    y: 0,
    width: split,
    height: out.height,
  );
  img.compositeImage(out, left);
  img.fillRect(
    out,
    x1: split - 1,
    y1: 0,
    x2: split,
    y2: out.height - 1,
    color: img.ColorRgb8(255, 255, 255),
  );
  if (handle) {
    final cy = out.height ~/ 2;
    img.fillCircle(
      out,
      x: split,
      y: cy,
      radius: 15,
      color: img.ColorRgb8(255, 255, 255),
      antialias: true,
    );
    for (final dir in const [-1, 1]) {
      final tip = split + dir * 8;
      img.drawLine(
        out,
        x1: tip - dir * 4,
        y1: cy - 5,
        x2: tip,
        y2: cy,
        color: img.ColorRgb8(31, 35, 40),
        thickness: 2,
      );
      img.drawLine(
        out,
        x1: tip,
        y1: cy,
        x2: tip - dir * 4,
        y2: cy + 5,
        color: img.ColorRgb8(31, 35, 40),
        thickness: 2,
      );
    }
  }
  return out;
}

/// A 17-point "teal and orange" grade: cool shadows, warm highlights,
/// protected skin mid-tones. Generated, so it ships without licensing
/// questions.
String _tealOrangeCube() {
  const n = 17;
  final b = StringBuffer()
    ..writeln('TITLE "Teal Orange (generated)"')
    ..writeln('LUT_3D_SIZE $n');
  for (var bi = 0; bi < n; bi++) {
    for (var gi = 0; gi < n; gi++) {
      for (var ri = 0; ri < n; ri++) {
        final r = ri / (n - 1), g = gi / (n - 1), bl = bi / (n - 1);
        final l = 0.2126 * r + 0.7152 * g + 0.0722 * bl;
        final shadow = math.pow(1 - l, 2).toDouble();
        final light = math.pow(l, 2).toDouble();
        double c(double v) => v.clamp(0.0, 1.0);
        final or = c(r + 0.10 * light - 0.06 * shadow);
        final og = c(g + 0.02 * light + 0.03 * shadow);
        final ob = c(bl - 0.10 * light + 0.09 * shadow);
        // Slight contrast lift around mid-grey.
        double s(double v) => v + (v - 0.5) * 0.08;
        b.writeln(
          '${c(s(or)).toStringAsFixed(5)} ${c(s(og)).toStringAsFixed(5)} ${c(s(ob)).toStringAsFixed(5)}',
        );
      }
    }
  }
  return b.toString();
}
