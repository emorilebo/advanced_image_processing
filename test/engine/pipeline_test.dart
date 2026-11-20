import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/fixtures.dart';

img.Image _rotate180(img.Image image) => img.copyRotate(image, angle: 180);

void main() {
  group('formats', () {
    test('JPEG in, JPEG out', () async {
      final r = await const ImagePipeline().grayscale().run(solid(40, 30));
      expect(r.format, EncodedFormat.jpeg);
      expect(img.findFormatForData(r.bytes), img.ImageFormat.jpg);
      expect((r.width, r.height), (40, 30));
    });

    test('PNG keeps transparency', () async {
      final r = await const ImagePipeline().sepia().run(
        halfTransparent(20, 10),
      );
      expect(r.format, EncodedFormat.png);
      final out = decode(r.bytes);
      expect(out.getPixel(2, 5).a, 0);
      expect(out.getPixel(15, 5).a, 255);
    });

    test('opaque PNG drops the unused alpha channel', () async {
      final r = await const ImagePipeline()
          .contrast(1.2)
          .run(solid(16, 16, png: true));
      expect(decode(r.bytes).numChannels, 3);
    });

    test('forced JPEG flattens transparency onto the background', () async {
      final r = await const ImagePipeline().run(
        halfTransparent(20, 10),
        output: const OutputFormat.jpeg(quality: 95, background: 0xFF00FF00),
      );
      expect(r.format, EncodedFormat.jpeg);
      final left = rgbAt(decode(r.bytes), 2, 5);
      expect(left[1], greaterThan(200)); // green background shows through
      expect(left[0], lessThan(60));
    });

    test('forced PNG from JPEG', () async {
      final r = await const ImagePipeline().run(
        solid(8, 8),
        output: const OutputFormat.png(compression: 1),
      );
      expect(img.findFormatForData(r.bytes), img.ImageFormat.png);
    });
  });

  group('safety', () {
    test('undecodable input throws UnsupportedImageException', () {
      expect(
        () => const ImagePipeline().run(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<UnsupportedImageException>()),
      );
    });

    test('oversized input is refused from the header', () {
      expect(
        () => const ImagePipeline().runSync(
          solid(100, 100),
          maxInputPixels: 9999,
        ),
        throwsA(
          isA<ImageTooLargeException>()
              .having((e) => e.width, 'width', 100)
              .having((e) => e.maxPixels, 'maxPixels', 9999),
        ),
      );
    });

    test('builders validate arguments', () {
      const p = ImagePipeline();
      expect(() => p.brightness(2), throwsArgumentError);
      expect(() => p.posterize(1), throwsArgumentError);
      expect(() => p.resize(), throwsArgumentError);
      expect(() => p.crop(0, 0, 0, 10), throwsArgumentError);
      expect(() => p.blur(double.nan), throwsArgumentError);
    });

    test('crop entirely outside the image throws at run time', () {
      expect(
        () =>
            const ImagePipeline().crop(500, 500, 10, 10).runSync(solid(20, 20)),
        throwsA(isA<ImageProcessingException>()),
      );
    });
  });

  group('metadata', () {
    Uint8List exifJpeg({int orientation = 1}) {
      final image = img.Image(width: 60, height: 30);
      img.fill(image, color: img.ColorRgb8(10, 120, 200));
      image.exif.imageIfd.make = 'TestCam';
      image.exif.imageIfd.orientation = orientation;
      image.exif.gpsIfd.gpsLatitudeRef = 'N';
      image.exif.gpsIfd.gpsLatitude = 9.0765;
      image.exif.gpsIfd.gpsLongitudeRef = 'E';
      image.exif.gpsIfd.gpsLongitude = 7.3986;
      return img.encodeJpg(image);
    }

    test('strips everything by default', () async {
      final out = decode((await const ImagePipeline().run(exifJpeg())).bytes);
      expect(out.exif.imageIfd.hasMake, isFalse);
      expect(out.exif.gpsIfd.hasGPSLatitude, isFalse);
    });

    test('keepWithoutLocation keeps camera data but drops GPS', () async {
      final r = await const ImagePipeline().run(
        exifJpeg(),
        metadata: MetadataPolicy.keepWithoutLocation,
      );
      final out = decode(r.bytes);
      expect(out.exif.imageIfd.make, 'TestCam');
      expect(out.exif.gpsIfd.hasGPSLatitude, isFalse);
    });

    test('keep preserves GPS', () async {
      final r = await const ImagePipeline().run(
        exifJpeg(),
        metadata: MetadataPolicy.keep,
      );
      expect(decode(r.bytes).exif.gpsIfd.hasGPSLatitude, isTrue);
    });

    test('EXIF orientation is baked into pixels', () async {
      final r = await const ImagePipeline().run(
        exifJpeg(orientation: 6),
        metadata: MetadataPolicy.keep,
      );
      expect((r.width, r.height), (30, 60));
      final out = decode(r.bytes);
      expect(
        !out.exif.imageIfd.hasOrientation || out.exif.imageIfd.orientation == 1,
        isTrue,
      );
    });
  });

  group('composition', () {
    test('builders are immutable', () {
      const base = ImagePipeline();
      final a = base.contrast(1.1);
      final b = a.blur(2);
      expect(base.length, 0);
      expect(a.length, 1);
      expect(b.steps, ['contrast(1.1)', 'blur(sigma 2.0)']);
    });

    test('previewMatrix fuses colour steps and is null otherwise', () {
      final colourOnly = const ImagePipeline().contrast(1.2).saturation(0.5);
      expect(
        colourOnly.previewMatrix,
        ColorMatrix.contrast(1.2).then(ColorMatrix.saturation(0.5)),
      );
      expect(colourOnly.blur(1).previewMatrix, isNull);
      expect(const ImagePipeline().previewMatrix, ColorMatrix.identity);
    });

    test('fused colour steps match a single equivalent matrix', () async {
      final input = ramp(64, 8);
      final chained = const ImagePipeline()
          .contrast(1.3)
          .saturation(1.4)
          .hue(25);
      final single = const ImagePipeline().colorMatrix(chained.previewMatrix!);
      expect((await chained.run(input)).bytes, (await single.run(input)).bytes);
    });

    test('then() concatenates', () {
      final p = const ImagePipeline().grayscale().then(
        const ImagePipeline().blur(1),
      );
      expect(p.length, 2);
    });

    test('JSON round-trip reproduces identical output', () async {
      final pipeline = const ImagePipeline()
          .downscale(48)
          .autoLevels()
          .contrast(1.1)
          .exposure(0.3)
          .vignette(strength: 0.4)
          .grain(amount: 0.1, seed: 9)
          .redact([const Rectangle(2, 2, 10, 10)], style: RedactionStyle.fill)
          .lut(CubeLut.identity(size: 5), intensity: 0.5)
          .cropToAspect(1);
      final restored = ImagePipeline.fromJson(
        (jsonDecode(jsonEncode(pipeline.toJson())) as Map)
            .cast<String, Object?>(),
      );
      final input = ramp(64, 40);
      expect(restored.steps, pipeline.steps);
      expect(
        (await restored.run(input)).bytes,
        (await pipeline.run(input)).bytes,
      );
    });

    test('custom steps run but cannot be serialised', () async {
      final p = const ImagePipeline().custom('rotate180', _rotate180);
      expect(p.isSerializable, isFalse);
      expect(p.toJson, throwsUnsupportedError);
      final r = await p.run(solid(10, 4));
      expect((r.width, r.height), (10, 4));
    });

    test('unknown JSON versions and op types are rejected', () {
      expect(
        () => ImagePipeline.fromJson({'version': 99, 'ops': <Object?>[]}),
        throwsFormatException,
      );
      expect(
        () => ImagePipeline.fromJson({
          'version': 1,
          'ops': [
            {'type': 'teleport'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('execution', () {
    test('background, inline and sync runs agree', () async {
      final p = const ImagePipeline().sharpen().vignette();
      final input = ramp(50, 20);
      final bg = await p.run(input);
      final inline = await p.run(input, background: false);
      final sync = p.runSync(input);
      expect(bg.bytes, inline.bytes);
      expect(bg.bytes, sync.bytes);
    });

    test('runAll keeps input order across workers', () async {
      final inputs = [for (var w = 10; w < 17; w++) solid(w, 5)];
      final results = await const ImagePipeline().invert().runAll(
        inputs,
        concurrency: 3,
      );
      expect([for (final r in results) r.width], [10, 11, 12, 13, 14, 15, 16]);
    });

    test('result reports processing time', () async {
      final r = await const ImagePipeline().run(solid(8, 8));
      expect(r.processingTime, greaterThan(Duration.zero));
      expect(r.toString(), contains('8x8 jpeg'));
    });
  });
}
