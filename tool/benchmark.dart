// Compares the 0.2.x processing path with the 0.3.0 pipeline.
//
// Run AOT-compiled for realistic numbers (JIT is several times slower):
//
//   dart compile exe tool/benchmark.dart -o /tmp/aipt_bench
//   /tmp/aipt_bench [path/to/photo.jpg]
//
// With no argument the bundled sample photo is upscaled to 4000 px wide
// (about 10.7 MP, a typical phone photo). The 0.2.x path is reproduced
// faithfully: every filter call decoded the JPEG, ran a package:image
// operation, and re-encoded at JPEG quality 100. (On device 0.2.x also paid
// a failed platform-channel round trip per call, which this pure-Dart
// benchmark cannot include, so the real gap is larger.)

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/engine.dart';
import 'package:advanced_image_processing_toolkit/src/engine/kernels.dart'
    as kernels;
import 'package:image/image.dart' as img;

const _runs = 3;

void main(List<String> args) {
  final source = args.isNotEmpty
      ? args.first
      : 'example/assets/sample_image.jpg';
  var input = File(source).readAsBytesSync();
  if (args.isEmpty) {
    final decoded = img.decodeJpg(input)!;
    input = img.encodeJpg(
      img.copyResize(
        decoded,
        width: 4000,
        interpolation: img.Interpolation.cubic,
      ),
      quality: 92,
    );
  }
  final info = img.decodeJpg(input)!;
  final mp = (info.width * info.height / 1e6).toStringAsFixed(1);
  stdout.writeln(
    'Input: ${info.width}x${info.height} ($mp MP), '
    '${(input.length / 1024 / 1024).toStringAsFixed(1)} MB JPEG',
  );
  stdout.writeln(
    'Machine: ${Platform.operatingSystem} '
    '${Platform.operatingSystemVersion.split(' ').take(2).join(' ')}, '
    '${Platform.numberOfProcessors} cores, Dart ${Platform.version.split(' ').first}',
  );
  stdout.writeln('Median of $_runs runs.\n');

  // 1. A five-step look.
  final legacyChain = [
    (img.Image i) => img.adjustColor(i, contrast: 1.2),
    (img.Image i) => img.adjustColor(i, saturation: 1.3),
    (img.Image i) => img.sepia(i, amount: 0.3),
    _legacyVignette,
    (img.Image i) => img.gaussianBlur(i, radius: 2),
  ];
  final pipeline = const ImagePipeline()
      .contrast(1.2)
      .saturation(1.3)
      .sepia(0.3)
      .vignette()
      .blur(2);
  final legacyMs = _median(() {
    var bytes = input;
    for (final step in legacyChain) {
      bytes = img.encodeJpg(step(img.decodeImage(bytes)!));
    }
    return bytes;
  });
  final pipelineMs = _median(() => pipeline.runSync(input).bytes);
  _row(
    '5-step look (contrast, saturation, sepia, vignette, blur)',
    legacyMs,
    pipelineMs,
  );

  // 2. Same look on a downscaled copy (the recommended pattern).
  final fastMs = _median(
    () => const ImagePipeline()
        .downscale(2048)
        .then(pipeline)
        .runSync(input)
        .bytes,
  );
  _row('  same look, downscale(2048) first', legacyMs, fastMs);

  // 3. Blur cost versus radius.
  final decoded = img.decodeJpg(input)!;
  final rgba = decoded.convert(numChannels: 4);
  for (final radius in [4, 16, 48]) {
    final old = _median(() {
      img.gaussianBlur(img.Image.from(decoded), radius: radius);
      return Uint8List(0);
    });
    // package:image uses sigma = 2/3 radius; match it for a like-for-like blur.
    final now = _median(() {
      final copy = img.Image.from(rgba);
      kernels.gaussianBlur(
        copy.toUint8List(),
        copy.width,
        copy.height,
        radius * 2 / 3,
      );
      return Uint8List(0);
    });
    _row('Gaussian blur, radius $radius (pixels only, no codec)', old, now);
  }

  // 4. Oil paint on a 2 MP image.
  final twoMp = img.copyResize(decoded, width: 1732);
  final oilOld = _median(() {
    _legacyOilPaint(img.Image.from(twoMp), 4, 20);
    return Uint8List(0);
  });
  final twoMpJpeg = img.encodeJpg(twoMp);
  final oilNew = _median(
    () => const ImagePipeline().oilPaint().runSync(twoMpJpeg).bytes,
  );
  _row('Oil paint r=4, 2 MP (0.3.0 includes decode + encode)', oilOld, oilNew);
}

int _median(Uint8List Function() body) {
  final times = <int>[];
  for (var i = 0; i < _runs; i++) {
    final sw = Stopwatch()..start();
    body();
    times.add(sw.elapsedMilliseconds);
  }
  times.sort();
  return times[times.length ~/ 2];
}

void _row(String label, int beforeMs, int afterMs) {
  final speedup = beforeMs / max(afterMs, 1);
  stdout.writeln(
    '${label.padRight(58)} '
    '0.2.x ${beforeMs.toString().padLeft(6)} ms   '
    '0.3.0 ${afterMs.toString().padLeft(6)} ms   '
    '${speedup.toStringAsFixed(1)}x',
  );
}

// The 0.2.x vignette, verbatim.
img.Image _legacyVignette(img.Image image) {
  final width = image.width;
  final height = image.height;
  final centerX = width / 2;
  final centerY = height / 2;
  final maxDistance = sqrt(centerX * centerX + centerY * centerY);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final distance =
          sqrt(pow(x - centerX, 2) + pow(y - centerY, 2)) / maxDistance;
      final factor = 1 - (distance * distance * 0.5 * 0.5);
      final pixel = image.getPixel(x, y);
      image.setPixelRgba(
        x,
        y,
        (pixel.r * factor).round(),
        (pixel.g * factor).round(),
        (pixel.b * factor).round(),
        pixel.a,
      );
    }
  }
  return image;
}

// The 0.2.x oil painting, verbatim.
img.Image _legacyOilPaint(img.Image image, int radius, int levels) {
  final width = image.width;
  final height = image.height;
  final result = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var maxIntensity = 0;
      var maxCount = 0;
      var r = 0, g = 0, b = 0;
      for (var ky = -radius; ky <= radius; ky++) {
        for (var kx = -radius; kx <= radius; kx++) {
          final px = x + kx;
          final py = y + ky;
          if (px >= 0 && px < width && py >= 0 && py < height) {
            final pixel = image.getPixel(px, py);
            final intensity =
                ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3)
                    .round();
            final level = (intensity * levels / 255).round();
            if (level > maxIntensity) {
              maxIntensity = level;
              maxCount = 1;
              r = pixel.r.toInt();
              g = pixel.g.toInt();
              b = pixel.b.toInt();
            } else if (level == maxIntensity) {
              maxCount++;
              r += pixel.r.toInt();
              g += pixel.g.toInt();
              b += pixel.b.toInt();
            }
          }
        }
      }
      result.setPixelRgba(
        x,
        y,
        (r / maxCount).round(),
        (g / maxCount).round(),
        (b / maxCount).round(),
        255,
      );
    }
  }
  return result;
}
