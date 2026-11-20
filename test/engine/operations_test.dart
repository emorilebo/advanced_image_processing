import 'dart:math';
import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/fixtures.dart';

Future<img.Image> _run(ImagePipeline p, Uint8List input) async =>
    decode((await p.run(input, output: const OutputFormat.png())).bytes);

/// A 64x64 PNG with a white square in the middle of a black field.
Uint8List _square() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  img.fillRect(
    image,
    x1: 16,
    y1: 16,
    x2: 47,
    y2: 47,
    color: img.ColorRgb8(255, 255, 255),
  );
  return img.encodePng(image);
}

void main() {
  group('geometry', () {
    final input = solid(200, 100, png: true);

    test('resize with one side keeps aspect ratio', () async {
      final r = await const ImagePipeline().resize(width: 50).run(input);
      expect((r.width, r.height), (50, 25));
    });

    test('resize fits: contain, cover, fill', () async {
      final contain = await const ImagePipeline()
          .resize(width: 80, height: 80)
          .run(input);
      expect((contain.width, contain.height), (80, 40));
      final cover = await const ImagePipeline()
          .resize(width: 80, height: 80, fit: ResizeFit.cover)
          .run(input);
      expect((cover.width, cover.height), (80, 80));
      final fill = await const ImagePipeline()
          .resize(width: 80, height: 80, fit: ResizeFit.fill)
          .run(input);
      expect((fill.width, fill.height), (80, 80));
    });

    test('downscale shrinks the long side and never enlarges', () async {
      final down = await const ImagePipeline().downscale(50).run(input);
      expect((down.width, down.height), (50, 25));
      final same = await const ImagePipeline().downscale(1000).run(input);
      expect((same.width, same.height), (200, 100));
    });

    test('rotate 90 swaps dimensions', () async {
      final r = await const ImagePipeline().rotate(90).run(input);
      expect((r.width, r.height), (100, 200));
    });

    test('crop clips to bounds', () async {
      final r = await const ImagePipeline().crop(150, 50, 100, 100).run(input);
      expect((r.width, r.height), (50, 50));
    });

    test('cropToAspect centre-crops', () async {
      final r = await const ImagePipeline().cropToAspect(1).run(input);
      expect((r.width, r.height), (100, 100));
    });

    test('flip mirrors pixels', () async {
      final out = await _run(const ImagePipeline().flip(), ramp(32, 4));
      expect(rgbAt(out, 0, 0)[0], 255);
      expect(rgbAt(out, 31, 0)[0], 0);
    });
  });

  group('tone', () {
    test('autoLevels stretches a flat image to the full range', () async {
      final out = await _run(
        const ImagePipeline().autoLevels(clip: 0),
        flatNoisy(64, 64),
      );
      var lo = 255, hi = 0;
      for (final p in out) {
        lo = min(lo, p.r.toInt());
        hi = max(hi, p.r.toInt());
      }
      expect(lo, 0);
      expect(hi, 255);
    });

    test('autoWhiteBalance pulls a colour cast towards neutral', () async {
      final input = solid(32, 32, r: 90, g: 120, b: 200, png: true);
      final out = await _run(const ImagePipeline().autoWhiteBalance(), input);
      final rgb = rgbAt(out, 10, 10);
      expect((rgb[0] - rgb[2]).abs(), lessThan(6));
    });

    test('exposure +1 EV brightens mid-grey in linear light', () async {
      final out = await _run(
        const ImagePipeline().exposure(1),
        solid(8, 8, r: 118, g: 118, b: 118, png: true),
      );
      // sRGB 118 is ~18% linear grey; one stop up is ~36%, sRGB ~163.
      expect(rgbAt(out, 4, 4)[0], inInclusiveRange(160, 166));
    });

    test('posterize and threshold quantise', () async {
      final poster = await _run(
        const ImagePipeline().posterize(2),
        ramp(64, 2),
      );
      expect(poster.map((p) => p.r.toInt()).toSet(), {0, 255});
      final thresh = await _run(const ImagePipeline().threshold(), ramp(64, 2));
      expect(thresh.map((p) => p.g.toInt()).toSet(), {0, 255});
    });

    test('gamma above 1 lifts mid-tones', () async {
      final out = await _run(
        const ImagePipeline().gamma(2),
        solid(4, 4, r: 64, g: 64, b: 64, png: true),
      );
      expect(rgbAt(out, 1, 1)[0], greaterThan(100));
    });
  });

  group('detail and artistic', () {
    test('blur keeps a flat image flat and softens an edge', () async {
      final flat = await _run(
        const ImagePipeline().blur(6),
        solid(30, 30, png: true),
      );
      expect(rgbAt(flat, 0, 0), rgbAt(flat, 15, 15));
      final soft = await _run(const ImagePipeline().blur(3), _square());
      final edge = rgbAt(soft, 16, 32)[0];
      expect(edge, inExclusiveRange(30, 225));
    });

    test('blur does not darken the edge of a transparent PNG', () async {
      final out = await _run(
        const ImagePipeline().blur(3),
        halfTransparent(40, 10),
      );
      final edgePixel = out.getPixel(21, 5);
      expect(edgePixel.r.toInt(), greaterThan(240));
    });

    test('every effect runs and keeps dimensions', () async {
      final input = _square();
      final effects = <String, ImagePipeline>{
        'sharpen': const ImagePipeline().sharpen(),
        'edges': const ImagePipeline().edges(),
        'emboss': const ImagePipeline().emboss(),
        'sketch': const ImagePipeline().sketch(sigma: 3),
        'kuwahara': const ImagePipeline().kuwahara(radius: 3),
        'oilPaint': const ImagePipeline().oilPaint(radius: 3, levels: 8),
        'watercolor': const ImagePipeline().watercolor(radius: 3),
        'pixelate': const ImagePipeline().pixelate(8),
      };
      for (final e in effects.entries) {
        final r = await e.value.run(input);
        expect((r.width, r.height), (64, 64), reason: e.key);
      }
    });

    test('edges light up the square outline only', () async {
      final out = await _run(const ImagePipeline().edges(), _square());
      expect(rgbAt(out, 5, 5)[0], 0);
      expect(rgbAt(out, 32, 32)[0], 0);
      expect(rgbAt(out, 16, 32)[0], 255);
    });

    test('kuwahara keeps a hard edge hard', () async {
      final out = await _run(
        const ImagePipeline().kuwahara(radius: 4),
        _square(),
      );
      expect(rgbAt(out, 14, 32)[0], 0);
      expect(rgbAt(out, 18, 32)[0], 255);
    });

    test('vignette darkens corners, not the centre', () async {
      final out = await _run(
        const ImagePipeline().vignette(strength: 0.8, radius: 0.3),
        solid(60, 60, r: 200, g: 200, b: 200, png: true),
      );
      expect(rgbAt(out, 30, 30)[0], 200);
      expect(rgbAt(out, 0, 0)[0], lessThan(80));
    });

    test('grain is deterministic per seed', () async {
      final input = solid(32, 32, png: true);
      final a = await const ImagePipeline().grain(seed: 1).run(input);
      final b = await const ImagePipeline().grain(seed: 1).run(input);
      final c = await const ImagePipeline().grain(seed: 2).run(input);
      expect(a.bytes, b.bytes);
      expect(a.bytes, isNot(c.bytes));
    });
  });

  group('privacy', () {
    test('fill redaction paints the padded region and nothing else', () async {
      final out = await _run(
        const ImagePipeline().redact(
          [const Rectangle(10, 10, 20, 20)],
          style: RedactionStyle.fill,
          padding: 0,
          color: 0xFF0000FF,
        ),
        solid(64, 64, r: 255, g: 255, b: 255, png: true),
      );
      expect(rgbAt(out, 15, 15), [0, 0, 255]);
      expect(rgbAt(out, 29, 29), [0, 0, 255]);
      expect(rgbAt(out, 30, 30), [255, 255, 255]);
      expect(rgbAt(out, 5, 5), [255, 255, 255]);
    });

    test('pixelate redaction makes uniform blocks inside the region', () async {
      final out = await _run(
        const ImagePipeline().redact(
          [const Rectangle(0, 0, 32, 2)],
          blockSize: 8,
          padding: 0,
        ),
        ramp(64, 2),
      );
      expect(rgbAt(out, 0, 0), rgbAt(out, 7, 1));
      expect(rgbAt(out, 0, 0), isNot(rgbAt(out, 8, 0)));
      // Outside the region the ramp is untouched.
      expect(rgbAt(out, 63, 0)[0], 255);
    });

    test('blur redaction changes the region only', () async {
      final input = _square();
      final out = await _run(
        const ImagePipeline().redact(
          [const Rectangle(10, 10, 12, 12)],
          style: RedactionStyle.blur,
          padding: 0,
          sigma: 4,
        ),
        input,
      );
      final original = decode(input);
      expect(rgbAt(out, 40, 40), rgbAt(original, 40, 40));
      expect(rgbAt(out, 16, 16), isNot(rgbAt(original, 16, 16)));
    });

    test('an empty region list is a no-op', () {
      expect(const ImagePipeline().redact(const []).length, 0);
    });
  });

  group('watermark', () {
    test('opacity is honoured', () async {
      final mark = solid(10, 10, r: 0, g: 0, b: 0, png: true);
      final out = await _run(
        const ImagePipeline().watermark(
          mark,
          offset: const Point(0, 0),
          opacity: 0.5,
          widthFraction: null,
        ),
        solid(40, 40, r: 200, g: 200, b: 200, png: true),
      );
      expect(rgbAt(out, 5, 5)[0], inInclusiveRange(99, 101));
      expect(rgbAt(out, 20, 20)[0], 200);
    });

    test('anchors scale and place the mark', () async {
      final mark = solid(10, 10, r: 0, g: 0, b: 0, png: true);
      final out = await _run(
        const ImagePipeline().watermark(
          mark,
          widthFraction: 0.25,
          margin: 0,
          opacity: 1,
        ),
        solid(80, 40, r: 255, g: 255, b: 255, png: true),
      );
      // A 20x20 mark flush in the bottom-right corner: x 60..79, y 20..39.
      expect(rgbAt(out, 79, 39), [0, 0, 0]);
      expect(rgbAt(out, 60, 20), [0, 0, 0]);
      expect(rgbAt(out, 59, 19), [255, 255, 255]);
    });

    test('undecodable watermark bytes raise a typed error', () {
      expect(
        () => const ImagePipeline()
            .watermark(Uint8List.fromList([1, 2, 3]))
            .runSync(solid(8, 8)),
        throwsA(isA<UnsupportedImageException>()),
      );
    });
  });
}
