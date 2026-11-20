import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A solid-colour RGB image encoded as JPEG or PNG.
Uint8List solid(
  int width,
  int height, {
  int r = 200,
  int g = 120,
  int b = 60,
  bool png = false,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return png ? img.encodePng(image) : img.encodeJpg(image, quality: 95);
}

/// A horizontal grey ramp (black on the left, white on the right) as PNG.
Uint8List ramp(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final v = (x * 255 / (width - 1)).round();
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return img.encodePng(image);
}

/// A PNG with a transparent left half and an opaque red right half.
Uint8List halfTransparent(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (x < width ~/ 2) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        image.setPixelRgba(x, y, 255, 0, 0, 255);
      }
    }
  }
  return img.encodePng(image);
}

/// A low-contrast, slightly noisy PNG for tone tests: values in 90..160.
Uint8List flatNoisy(int width, int height, {int seed = 7}) {
  final image = img.Image(width: width, height: height);
  var s = seed;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final v = 90 + (s % 71);
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return img.encodePng(image);
}

/// Decodes [bytes] (throws if undecodable).
img.Image decode(Uint8List bytes) => img.decodeImage(bytes)!;

/// RGB of the pixel at ([x], [y]).
List<int> rgbAt(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
}
