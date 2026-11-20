import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'engine/errors.dart';
import 'engine/options.dart';
import 'engine/pipeline.dart';

final _logger = Logger('ImageFilters');

/// One-call filters: each decodes the image, applies a single operation and
/// encodes the result, on a background isolate.
///
/// For more than one operation, build an [ImagePipeline] instead. It decodes
/// and encodes once, so a five-step edit costs one round trip, not five.
///
/// Output keeps the input format (JPEG stays JPEG, PNG keeps transparency),
/// photos are rotated upright from their EXIF orientation, and metadata
/// including GPS is stripped.
///
/// For compatibility with 0.2.x, these methods never throw on bad image
/// data: undecodable or oversized input is logged and returned unchanged.
/// [ImagePipeline] throws typed exceptions instead.
class ImageFilters {
  ImageFilters._();

  static Future<Uint8List> _run(
    Uint8List input,
    ImagePipeline pipeline,
    String name,
  ) async {
    try {
      return await pipeline.apply(input);
    } on ImageProcessingException catch (e) {
      _logger.warning('$name: ${e.message}. Returning the input unchanged.');
      return input;
    }
  }

  /// Converts to greyscale.
  static Future<Uint8List> applyGrayscale(Uint8List imageData) =>
      _run(imageData, const ImagePipeline().grayscale(), 'applyGrayscale');

  /// Gaussian blur with standard deviation [sigma] in pixels.
  static Future<Uint8List> applyBlur(Uint8List imageData, double sigma) => _run(
    imageData,
    const ImagePipeline().blur(sigma.clamp(0, 500)),
    'applyBlur',
  );

  /// Shifts brightness by [factor] in `-1.0..1.0` (`0` is neutral).
  static Future<Uint8List> adjustBrightness(
    Uint8List imageBytes,
    double factor,
  ) => _run(
    imageBytes,
    const ImagePipeline().brightness(factor.clamp(-1, 1)),
    'adjustBrightness',
  );

  /// Sepia tone.
  static Future<Uint8List> applySepia(Uint8List imageBytes) =>
      _run(imageBytes, const ImagePipeline().sepia(), 'applySepia');

  /// Inverts colours.
  static Future<Uint8List> applyInvert(Uint8List imageBytes) =>
      _run(imageBytes, const ImagePipeline().invert(), 'applyInvert');

  /// Darkens the corners. [intensity] is the corner darkening (`0..1`);
  /// [radius] is where the falloff starts (`0..1` of centre-to-corner).
  static Future<Uint8List> applyVignette(
    Uint8List imageBytes, {
    double intensity = 0.5,
    double radius = 0.5,
  }) => _run(
    imageBytes,
    const ImagePipeline().vignette(
      strength: intensity.clamp(0, 1),
      radius: radius.clamp(0, 1),
    ),
    'applyVignette',
  );

  /// Watercolour effect. [intensity] blends from original (`0`) to full
  /// effect (`1`).
  static Future<Uint8List> applyWatercolor(
    Uint8List imageBytes, {
    int radius = 5,
    double intensity = 0.5,
  }) => _run(
    imageBytes,
    const ImagePipeline().watercolor(
      radius: radius.clamp(1, 64),
      intensity: intensity.clamp(0, 1),
    ),
    'applyWatercolor',
  );

  /// Oil-paint effect: [radius] is the brush size, [levels] the number of
  /// intensity buckets.
  static Future<Uint8List> applyOilPainting(
    Uint8List imageBytes, {
    int radius = 4,
    int levels = 20,
  }) => _run(
    imageBytes,
    const ImagePipeline().oilPaint(
      radius: radius.clamp(1, 32),
      levels: levels.clamp(2, 256),
    ),
    'applyOilPainting',
  );

  /// Resizes. With one side given the other follows the aspect ratio; with
  /// both, the image is stretched to exactly that size (as in 0.2.x). Use
  /// [ImagePipeline.resize] for contain/cover fitting.
  static Future<Uint8List> applyResize(
    Uint8List imageBytes, {
    int? width,
    int? height,
  }) {
    if ((width == null && height == null) ||
        (width != null && width < 1) ||
        (height != null && height < 1)) {
      _logger.warning('applyResize: invalid size $width x $height');
      return Future.value(imageBytes);
    }
    return _run(
      imageBytes,
      const ImagePipeline().resize(
        width: width,
        height: height,
        fit: ResizeFit.fill,
      ),
      'applyResize',
    );
  }

  /// Rotates clockwise by [angle] degrees.
  static Future<Uint8List> applyRotate(Uint8List imageBytes, double angle) =>
      _run(imageBytes, const ImagePipeline().rotate(angle), 'applyRotate');

  /// Crops to the rectangle at ([x], [y]) of [width] x [height], clipped to
  /// the image.
  static Future<Uint8List> applyCrop(
    Uint8List imageBytes,
    int x,
    int y,
    int width,
    int height,
  ) {
    if (width < 1 || height < 1) {
      _logger.warning('applyCrop: invalid size $width x $height');
      return Future.value(imageBytes);
    }
    return _run(
      imageBytes,
      const ImagePipeline().crop(x, y, width, height),
      'applyCrop',
    );
  }

  /// Mirrors horizontally and/or vertically.
  static Future<Uint8List> applyFlip(
    Uint8List imageBytes, {
    bool horizontal = true,
    bool vertical = false,
  }) => _run(
    imageBytes,
    const ImagePipeline().flip(horizontal: horizontal, vertical: vertical),
    'applyFlip',
  );

  /// Scales contrast. `1.0` is neutral.
  static Future<Uint8List> adjustContrast(
    Uint8List imageBytes,
    double contrast,
  ) => _run(
    imageBytes,
    const ImagePipeline().contrast(contrast.clamp(0, 4)),
    'adjustContrast',
  );

  /// Scales saturation. `1.0` is neutral, `0` is greyscale.
  static Future<Uint8List> adjustSaturation(
    Uint8List imageBytes,
    double saturation,
  ) => _run(
    imageBytes,
    const ImagePipeline().saturation(saturation.clamp(0, 4)),
    'adjustSaturation',
  );

  /// Composites [watermarkImageBytes] at pixel ([x], [y]) at its native
  /// size with the given [opacity]. Use [ImagePipeline.watermark] for
  /// anchored, resolution-independent placement.
  static Future<Uint8List> applyWatermark(
    Uint8List baseImageBytes,
    Uint8List watermarkImageBytes, {
    int x = 0,
    int y = 0,
    double opacity = 0.5,
  }) => _run(
    baseImageBytes,
    const ImagePipeline().watermark(
      watermarkImageBytes,
      offset: math.Point(x, y),
      opacity: opacity.clamp(0, 1),
      widthFraction: null,
    ),
    'applyWatermark',
  );
}
