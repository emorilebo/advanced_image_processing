import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'codec_guard.dart';
import 'color_matrix.dart';
import 'cube_lut.dart';
import 'errors.dart';
import 'kernels.dart' as k;
import 'ops.dart';
import 'options.dart';
import 'runner.dart';

/// The default ceiling on input size: 64 megapixels covers 48-50 MP phone
/// sensors while refusing decompression bombs.
const int defaultMaxInputPixels = 64 * 1000 * 1000;

/// The encoded output of a pipeline run.
final class PipelineResult {
  /// Creates a result.
  const PipelineResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.processingTime,
  });

  /// The encoded image.
  final Uint8List bytes;

  /// Output width in pixels.
  final int width;

  /// Output height in pixels.
  final int height;

  /// The format [bytes] is encoded in.
  final EncodedFormat format;

  /// Wall time spent decoding, processing and encoding (excludes isolate
  /// start-up).
  final Duration processingTime;

  @override
  String toString() =>
      'PipelineResult(${width}x$height ${format.name}, '
      '${bytes.length} bytes, ${processingTime.inMilliseconds} ms)';
}

/// An immutable, reusable recipe of image operations.
///
/// Build it once, apply it to any number of images:
///
/// ```dart
/// final look = const ImagePipeline()
///     .autoLevels()
///     .contrast(1.1)
///     .vignette(strength: 0.3)
///     .downscale(2048);
///
/// final result = await look.run(bytes);
/// ```
///
/// A run decodes the image once, applies every step on raw pixels, and
/// encodes once. Consecutive colour steps are fused into a single pass. On
/// Android, iOS and desktop the work happens on a background isolate, so the
/// UI never janks.
///
/// Every builder method returns a new pipeline; the original is untouched,
/// which makes pipelines safe to share and store as constants or presets.
final class ImagePipeline {
  /// An empty pipeline. Running it still normalises orientation, strips
  /// metadata and re-encodes, which is useful on its own.
  const ImagePipeline() : _ops = const [];

  const ImagePipeline._(this._ops);

  /// Restores a pipeline saved with [toJson].
  ///
  /// Throws [FormatException] for unknown versions or op types.
  factory ImagePipeline.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != 1) {
      throw FormatException('Unsupported pipeline version: $version');
    }
    final ops = (json['ops']! as List<Object?>)
        .map((o) => ImageOp.fromJson((o! as Map).cast<String, Object?>()))
        .toList(growable: false);
    return ImagePipeline._(List.unmodifiable(ops));
  }

  final List<ImageOp> _ops;

  ImagePipeline _add(ImageOp op) =>
      ImagePipeline._(List.unmodifiable([..._ops, op]));

  // -------------------------------------------------------------------------
  // Colour (fused into one pass, previewable live with ColorFilter.matrix)
  // -------------------------------------------------------------------------

  /// Shifts brightness by [amount] in `-1.0..1.0`.
  ImagePipeline brightness(double amount) {
    _checkRange(amount, -1, 1, 'amount');
    return _matrix(ColorMatrix.brightness(amount), 'brightness($amount)');
  }

  /// Scales contrast. `1.0` is neutral.
  ImagePipeline contrast(double factor) {
    _checkRange(factor, 0, 4, 'factor');
    return _matrix(ColorMatrix.contrast(factor), 'contrast($factor)');
  }

  /// Scales saturation. `1.0` is neutral, `0` is greyscale.
  ImagePipeline saturation(double factor) {
    _checkRange(factor, 0, 4, 'factor');
    return _matrix(ColorMatrix.saturation(factor), 'saturation($factor)');
  }

  /// Rotates hue by [degrees].
  ImagePipeline hue(double degrees) =>
      _matrix(ColorMatrix.hueRotate(degrees), 'hue($degrees°)');

  /// Desaturates; [amount] `1.0` is full greyscale.
  ImagePipeline grayscale([double amount = 1.0]) {
    _checkRange(amount, 0, 1, 'amount');
    return _matrix(ColorMatrix.grayscale(amount), 'grayscale($amount)');
  }

  /// Sepia tone; [amount] `1.0` is full sepia.
  ImagePipeline sepia([double amount = 1.0]) {
    _checkRange(amount, 0, 1, 'amount');
    return _matrix(ColorMatrix.sepia(amount), 'sepia($amount)');
  }

  /// Inverts colours.
  ImagePipeline invert() => _matrix(ColorMatrix.invert(), 'invert');

  /// Warms (positive) or cools (negative), `-1.0..1.0`.
  ImagePipeline temperature(double amount) {
    _checkRange(amount, -1, 1, 'amount');
    return _matrix(ColorMatrix.temperature(amount), 'temperature($amount)');
  }

  /// Magenta (positive) or green (negative) tint, `-1.0..1.0`.
  ImagePipeline tint(double amount) {
    _checkRange(amount, -1, 1, 'amount');
    return _matrix(ColorMatrix.tint(amount), 'tint($amount)');
  }

  /// Applies an arbitrary [ColorMatrix].
  ImagePipeline colorMatrix(
    ColorMatrix matrix, {
    String label = 'colorMatrix',
  }) => _matrix(matrix, label);

  ImagePipeline _matrix(ColorMatrix m, String label) =>
      _add(ColorMatrixOp(m, label));

  // -------------------------------------------------------------------------
  // Tone
  // -------------------------------------------------------------------------

  /// Photographic exposure in stops (EV), computed in linear light.
  /// `+1` doubles the light, `-1` halves it.
  ImagePipeline exposure(double stops) {
    _checkRange(stops, -5, 5, 'stops');
    return _add(ExposureOp(stops));
  }

  /// Gamma correction. Values above `1` brighten mid-tones.
  ImagePipeline gamma(double gamma) {
    _checkRange(gamma, 0.1, 10, 'gamma');
    return _add(GammaOp(gamma));
  }

  /// Maps [black]..[white] to the full range, with optional mid-tone [gamma].
  ImagePipeline levels({int black = 0, int white = 255, double gamma = 1.0}) {
    if (black < 0 || white > 255 || white - black < 1) {
      throw ArgumentError('levels needs 0 <= black < white <= 255');
    }
    _checkRange(gamma, 0.1, 10, 'gamma');
    return _add(LevelsOp(black, white, gamma));
  }

  /// Reduces each channel to [levels] distinct values.
  ImagePipeline posterize(int levels) {
    _checkRange(levels, 2, 256, 'levels');
    return _add(PosterizeOp(levels));
  }

  /// Pure black and white at luminance [level].
  ImagePipeline threshold([int level = 128]) {
    _checkRange(level, 0, 255, 'level');
    return _add(ThresholdOp(level));
  }

  /// Stretches the tonal range so the darkest and brightest [clip] fraction
  /// of pixels hit black and white. Fixes flat, hazy and underexposed photos.
  ImagePipeline autoLevels({double clip = 0.005}) {
    _checkRange(clip, 0, 0.2, 'clip');
    return _add(AutoLevelsOp(clip));
  }

  /// Neutralises colour casts with the grey-world assumption. [strength]
  /// `0..1` controls how far towards neutral to go.
  ImagePipeline autoWhiteBalance({double strength = 1.0}) {
    _checkRange(strength, 0, 1, 'strength');
    return _add(AutoWhiteBalanceOp(strength));
  }

  /// One-tap enhancement: [autoLevels] followed by a gentle saturation lift.
  ImagePipeline autoEnhance() => autoLevels().saturation(1.08);

  /// Applies a `.cube` colour grade, blended by [intensity].
  ImagePipeline lut(CubeLut lut, {double intensity = 1.0}) {
    _checkRange(intensity, 0, 1, 'intensity');
    return _add(LutOp(lut, intensity));
  }

  // -------------------------------------------------------------------------
  // Detail
  // -------------------------------------------------------------------------

  /// Gaussian blur. Cost does not grow with [sigma].
  ImagePipeline blur(double sigma) {
    _checkRange(sigma, 0, 500, 'sigma');
    return _add(BlurOp(sigma));
  }

  /// Unsharp-mask sharpening.
  ImagePipeline sharpen({
    double amount = 0.8,
    double sigma = 1.2,
    int threshold = 2,
  }) {
    _checkRange(amount, 0, 5, 'amount');
    _checkRange(sigma, 0.1, 50, 'sigma');
    _checkRange(threshold, 0, 255, 'threshold');
    return _add(SharpenOp(amount, sigma, threshold));
  }

  /// Sobel edge detection. With [invert], dark lines on white.
  ImagePipeline edges({bool invert = false}) => _add(EdgesOp(invert: invert));

  /// Emboss relief.
  ImagePipeline emboss({double strength = 1.0}) {
    _checkRange(strength, 0, 10, 'strength');
    return _add(EmbossOp(strength));
  }

  // -------------------------------------------------------------------------
  // Artistic
  // -------------------------------------------------------------------------

  /// Darkens towards the corners. [radius] is where falloff starts (0..1).
  ImagePipeline vignette({double strength = 0.5, double radius = 0.5}) {
    _checkRange(strength, 0, 1, 'strength');
    _checkRange(radius, 0, 1, 'radius');
    return _add(VignetteOp(strength, radius));
  }

  /// Deterministic film grain. Same [seed], same grain.
  ImagePipeline grain({double amount = 0.15, int seed = 42}) {
    _checkRange(amount, 0, 1, 'amount');
    return _add(GrainOp(amount, seed));
  }

  /// Mosaic of [blockSize]-pixel squares over the whole image.
  ImagePipeline pixelate(int blockSize) {
    _checkRange(blockSize, 2, 4096, 'blockSize');
    return _add(PixelateOp(blockSize));
  }

  /// Edge-preserving Kuwahara smoothing, a painterly look. O(pixels).
  ImagePipeline kuwahara({int radius = 4}) {
    _checkRange(radius, 1, 64, 'radius');
    return _add(KuwaharaOp(radius));
  }

  /// Oil-paint effect (dominant intensity per neighbourhood).
  ImagePipeline oilPaint({int radius = 4, int levels = 20}) {
    _checkRange(radius, 1, 32, 'radius');
    _checkRange(levels, 2, 256, 'levels');
    return _add(OilPaintOp(radius, levels));
  }

  /// Watercolour: flat washes, pooled edges, lifted colour.
  ImagePipeline watercolor({int radius = 5, double intensity = 1.0}) {
    _checkRange(radius, 1, 64, 'radius');
    _checkRange(intensity, 0, 1, 'intensity');
    return _add(WatercolorOp(radius, intensity));
  }

  /// Pencil sketch. Larger [sigma] gives broader strokes.
  ImagePipeline sketch({double sigma = 6}) {
    _checkRange(sigma, 0.5, 100, 'sigma');
    return _add(SketchOp(sigma));
  }

  // -------------------------------------------------------------------------
  // Geometry
  // -------------------------------------------------------------------------

  /// Resizes. With one side set, the other follows the aspect ratio. With
  /// both set, [fit] decides between letterbox, crop and stretch.
  ImagePipeline resize({
    int? width,
    int? height,
    ResizeFit fit = ResizeFit.contain,
  }) {
    if (width == null && height == null) {
      throw ArgumentError('resize needs a width, a height, or both');
    }
    if ((width != null && width < 1) || (height != null && height < 1)) {
      throw ArgumentError('resize dimensions must be positive');
    }
    return _add(ResizeOp(width, height, fit));
  }

  /// Shrinks so the longest side is at most [maxSide]. Never upscales.
  ///
  /// Put this first: every later step then works on fewer pixels.
  ImagePipeline downscale(int maxSide) {
    _checkRange(maxSide, 1, 1 << 16, 'maxSide');
    return _add(DownscaleOp(maxSide));
  }

  /// Rotates clockwise by [degrees]. Right angles are lossless.
  ImagePipeline rotate(double degrees) => _add(RotateOp(degrees));

  /// Mirrors the image.
  ImagePipeline flip({bool horizontal = true, bool vertical = false}) =>
      _add(FlipOp(horizontal: horizontal, vertical: vertical));

  /// Crops to a rectangle, clipped to the image bounds.
  ImagePipeline crop(int x, int y, int width, int height) {
    if (width < 1 || height < 1) {
      throw ArgumentError('crop width and height must be positive');
    }
    return _add(CropOp(x, y, width, height));
  }

  /// Centre-crops to [aspectRatio] (width / height), e.g. `1` or `4 / 5`.
  ImagePipeline cropToAspect(double aspectRatio) {
    _checkRange(aspectRatio, 0.01, 100, 'aspectRatio');
    return _add(CropAspectOp(aspectRatio));
  }

  // -------------------------------------------------------------------------
  // Privacy and composition
  // -------------------------------------------------------------------------

  /// Hides [regions] (in pixel coordinates of the upright image at this
  /// point in the pipeline). Pair with `ObjectRecognition` to blur faces or
  /// text automatically.
  ///
  /// Each region grows by [padding] (a fraction of its size) on every side.
  /// [blockSize] and [sigma] default to values scaled to each region.
  ///
  /// Pixelation and blur can be partially reversed by modern models. Use
  /// [RedactionStyle.fill] for text, documents and anything sensitive.
  ImagePipeline redact(
    Iterable<math.Rectangle<num>> regions, {
    RedactionStyle style = RedactionStyle.pixelate,
    double padding = 0.1,
    int? blockSize,
    double? sigma,
    int color = 0xFF000000,
  }) {
    _checkRange(padding, 0, 2, 'padding');
    if (blockSize != null) _checkRange(blockSize, 2, 4096, 'blockSize');
    if (sigma != null) _checkRange(sigma, 0.5, 500, 'sigma');
    final rects = [
      for (final r in regions)
        math.Rectangle<double>(
          r.left.toDouble(),
          r.top.toDouble(),
          r.width.toDouble(),
          r.height.toDouble(),
        ),
    ];
    if (rects.isEmpty) return this;
    return _add(
      RedactOp(
        regions: rects,
        style: style,
        padding: padding,
        color: color,
        blockSize: blockSize,
        sigma: sigma,
      ),
    );
  }

  /// Composites a logo or mark. By default it is scaled to [widthFraction]
  /// of the image width and placed at [anchor] with a [margin] that is a
  /// fraction of the shorter side, so it looks the same at any resolution.
  /// Pass [offset] to place it at exact pixel coordinates instead.
  ImagePipeline watermark(
    Uint8List bytes, {
    WatermarkAnchor anchor = WatermarkAnchor.bottomRight,
    double margin = 0.03,
    double opacity = 0.85,
    double? widthFraction = 0.2,
    math.Point<int>? offset,
  }) {
    _checkRange(opacity, 0, 1, 'opacity');
    _checkRange(margin, 0, 0.5, 'margin');
    if (widthFraction != null) {
      _checkRange(widthFraction, 0.001, 1, 'widthFraction');
    }
    return _add(
      WatermarkOp(
        bytes: Uint8List.fromList(bytes),
        anchor: anchor,
        margin: margin,
        opacity: opacity,
        widthFraction: widthFraction,
        offset: offset,
      ),
    );
  }

  /// Escape hatch: any `package:image` transform. It receives 8-bit RGBA and
  /// may return any image. Custom steps make the pipeline non-serialisable,
  /// and [transform] must be a top-level or static function (or a closure
  /// over sendable values) so it can cross to the background isolate.
  ImagePipeline custom(
    String name,
    img.Image Function(img.Image image) transform,
  ) => _add(CustomOp(name, transform));

  // -------------------------------------------------------------------------
  // Composition and inspection
  // -------------------------------------------------------------------------

  /// Appends every step of [next].
  ImagePipeline then(ImagePipeline next) => next._ops.isEmpty
      ? this
      : ImagePipeline._(List.unmodifiable([..._ops, ...next._ops]));

  /// Number of steps.
  int get length => _ops.length;

  /// Whether there are no steps.
  bool get isEmpty => _ops.isEmpty;

  /// Human-readable steps, e.g. `['contrast(1.2)', 'blur(sigma 2.0)']`.
  List<String> get steps => [for (final op in _ops) op.describe()];

  /// The single fused colour matrix this pipeline is equivalent to, or
  /// `null` if it contains any non-colour step.
  ///
  /// Use it for zero-cost live previews:
  /// `ColorFiltered(colorFilter: ColorFilter.matrix(m.values), child: ...)`.
  /// The exported pixels match the preview to within rounding.
  ColorMatrix? get previewMatrix {
    var m = ColorMatrix.identity;
    for (final op in _ops) {
      if (op is! ColorMatrixOp) return null;
      m = m.then(op.matrix);
    }
    return m;
  }

  /// Whether [toJson] will succeed (false if a [custom] step is present).
  bool get isSerializable => _ops.every((op) => op.isSerializable);

  /// Serialises the recipe (not any image) to JSON-compatible maps.
  Map<String, Object?> toJson() => {
    'version': 1,
    'ops': [for (final op in _ops) op.toJson()],
  };

  // -------------------------------------------------------------------------
  // Execution
  // -------------------------------------------------------------------------

  /// Decodes [input], applies every step and encodes the result.
  ///
  /// Runs on a background isolate unless [background] is false (or on the
  /// web, where it always runs inline).
  ///
  /// Throws [UnsupportedImageException] for undecodable input and
  /// [ImageTooLargeException] when the header declares more than
  /// [maxInputPixels].
  Future<PipelineResult> run(
    Uint8List input, {
    OutputFormat output = const OutputFormat.original(),
    MetadataPolicy metadata = MetadataPolicy.strip,
    int maxInputPixels = defaultMaxInputPixels,
    bool background = true,
  }) {
    final config = _RunConfig(output, metadata, maxInputPixels);
    final ops = _ops;
    if (!background) {
      return Future.sync(() => _execute(input, ops, config));
    }
    return runInBackground(() => _execute(input, ops, config));
  }

  /// [run], returning only the encoded bytes.
  Future<Uint8List> apply(
    Uint8List input, {
    OutputFormat output = const OutputFormat.original(),
    MetadataPolicy metadata = MetadataPolicy.strip,
  }) async => (await run(input, output: output, metadata: metadata)).bytes;

  /// Synchronous [run] on the current isolate. Use when you are already off
  /// the UI thread, e.g. inside your own isolate or a server.
  PipelineResult runSync(
    Uint8List input, {
    OutputFormat output = const OutputFormat.original(),
    MetadataPolicy metadata = MetadataPolicy.strip,
    int maxInputPixels = defaultMaxInputPixels,
  }) => _execute(input, _ops, _RunConfig(output, metadata, maxInputPixels));

  /// Applies the pipeline to many images, spread over [concurrency]
  /// background isolates. Results keep the order of [inputs]. The first
  /// failure fails the whole batch.
  Future<List<PipelineResult>> runAll(
    List<Uint8List> inputs, {
    OutputFormat output = const OutputFormat.original(),
    MetadataPolicy metadata = MetadataPolicy.strip,
    int maxInputPixels = defaultMaxInputPixels,
    int concurrency = 2,
  }) async {
    _checkRange(concurrency, 1, 64, 'concurrency');
    if (inputs.isEmpty) return const [];
    final config = _RunConfig(output, metadata, maxInputPixels);
    final ops = _ops;
    final workers = supportsBackgroundIsolates
        ? math.min(concurrency, inputs.length)
        : 1;
    final slices = List.generate(workers, (_) => <int>[]);
    for (var i = 0; i < inputs.length; i++) {
      slices[i % workers].add(i);
    }
    final results = List<PipelineResult?>.filled(inputs.length, null);
    await Future.wait([
      for (final slice in slices)
        runInBackground(() {
          return [for (final i in slice) _execute(inputs[i], ops, config)];
        }).then((done) {
          for (var j = 0; j < slice.length; j++) {
            results[slice[j]] = done[j];
          }
        }),
    ]);
    return results.cast<PipelineResult>();
  }

  @override
  String toString() => 'ImagePipeline(${steps.join(' -> ')})';
}

final class _RunConfig {
  const _RunConfig(this.output, this.metadata, this.maxInputPixels);
  final OutputFormat output;
  final MetadataPolicy metadata;
  final int maxInputPixels;
}

PipelineResult _execute(Uint8List input, List<ImageOp> ops, _RunConfig config) {
  final stopwatch = Stopwatch()..start();
  final decoder = guardCodec(
    'Input is not a readable image',
    () => img.findDecoderForData(input),
  );
  if (decoder == null) {
    throw UnsupportedImageException(
      'Input (${input.length} bytes) is not a recognised image format',
    );
  }
  final info = guardCodec(
    'Could not read the image header',
    () => decoder.startDecode(input),
  );
  if (info == null) {
    throw const UnsupportedImageException('Could not read the image header');
  }
  if (info.width * info.height > config.maxInputPixels) {
    throw ImageTooLargeException(
      width: info.width,
      height: info.height,
      maxPixels: config.maxInputPixels,
    );
  }
  final sourceFormat = decoder.format;
  final decoded = guardCodec(
    'Failed to decode ${sourceFormat.name} data',
    () => decoder.decode(input, frame: 0),
  );
  if (decoded == null) {
    throw UnsupportedImageException(
      'Failed to decode ${sourceFormat.name} data',
    );
  }

  // Pixels are always made upright. (package:image already does this for
  // JPEG while decoding; this covers the other formats.)
  var image = decoded;
  if (image.exif.imageIfd.hasOrientation &&
      image.exif.imageIfd.orientation != 1) {
    image = img.bakeOrientation(image);
  }
  final exif = image.exif;
  image = ensureRgba8(image);

  // Consecutive colour-matrix steps are composed and applied in one pass.
  ColorMatrix? pending;
  for (final op in ops) {
    if (op is ColorMatrixOp) {
      pending = pending?.then(op.matrix) ?? op.matrix;
      continue;
    }
    if (pending != null) {
      _applyMatrix(image, pending);
      pending = null;
    }
    image = ensureRgba8(op.apply(image));
  }
  if (pending != null) _applyMatrix(image, pending);

  var out = image;
  final px = out.toUint8List();
  final translucent = k.hasTranslucency(px);
  final target =
      config.output.format ??
      switch (sourceFormat) {
        img.ImageFormat.jpg => EncodedFormat.jpeg,
        img.ImageFormat.png => EncodedFormat.png,
        _ => translucent ? EncodedFormat.png : EncodedFormat.jpeg,
      };

  out.exif = _exifFor(exif, config.metadata);

  final Uint8List bytes;
  switch (target) {
    case EncodedFormat.jpeg:
      if (translucent) k.flattenOnto(px, config.output.background);
      bytes = img.encodeJpg(out, quality: config.output.quality.clamp(1, 100));
    case EncodedFormat.png:
      if (!translucent) {
        // Opaque PNGs encode a third smaller without the alpha channel.
        final exifData = out.exif;
        out = out.convert(numChannels: 3);
        out.exif = exifData;
      }
      bytes = img.encodePng(out, level: config.output.compression.clamp(0, 9));
  }
  stopwatch.stop();
  return PipelineResult(
    bytes: bytes,
    width: out.width,
    height: out.height,
    format: target,
    processingTime: stopwatch.elapsed,
  );
}

img.ExifData _exifFor(img.ExifData source, MetadataPolicy policy) {
  switch (policy) {
    case MetadataPolicy.strip:
      return img.ExifData();
    case MetadataPolicy.keep:
      return img.ExifData.from(source);
    case MetadataPolicy.keepWithoutLocation:
      final copy = img.ExifData.from(source);
      final ifd0 = copy.imageIfd;
      ifd0.sub.directories.remove('gps');
      ifd0.data.remove(0x8825); // GPSInfo IFD pointer
      return copy;
  }
}

void _applyMatrix(img.Image image, ColorMatrix matrix) {
  if (!matrix.isIdentity) matrix.applyToRgba(image.toUint8List());
}

void _checkRange(num value, num min, num max, String name) {
  if (value.isNaN || value < min || value > max) {
    throw ArgumentError.value(value, name, 'must be between $min and $max');
  }
}
