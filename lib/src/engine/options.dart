/// Encoded image formats the engine can write.
enum EncodedFormat {
  /// JPEG. No alpha channel; translucent pixels are flattened.
  jpeg,

  /// PNG. Lossless, keeps alpha.
  png,
}

/// How the processed image is encoded.
final class OutputFormat {
  /// Match the input: JPEG stays JPEG and PNG stays PNG. Inputs in formats
  /// the engine cannot write (WebP, GIF, BMP, TIFF, ...) become PNG when they
  /// have transparency and JPEG otherwise.
  const OutputFormat.original({this.quality = 90, this.compression = 6})
    : format = null,
      background = 0xFFFFFFFF;

  /// Encode as JPEG at [quality] (1-100). Transparent pixels are composited
  /// over the opaque ARGB [background] colour first.
  const OutputFormat.jpeg({this.quality = 90, this.background = 0xFFFFFFFF})
    : format = EncodedFormat.jpeg,
      compression = 6;

  /// Encode as PNG with zlib [compression] (0-9).
  const OutputFormat.png({this.compression = 6})
    : format = EncodedFormat.png,
      quality = 90,
      background = 0xFFFFFFFF;

  /// The forced format, or `null` to match the input.
  final EncodedFormat? format;

  /// JPEG quality, 1-100.
  final int quality;

  /// PNG compression level, 0-9.
  final int compression;

  /// ARGB colour JPEG output is flattened onto.
  final int background;

  @override
  String toString() => switch (format) {
    null => 'OutputFormat.original',
    EncodedFormat.jpeg => 'OutputFormat.jpeg(quality: $quality)',
    EncodedFormat.png => 'OutputFormat.png(compression: $compression)',
  };
}

/// What happens to EXIF metadata (camera, timestamps, GPS) on output.
enum MetadataPolicy {
  /// Remove all metadata. The default: photos shared from an app should not
  /// leak where they were taken.
  strip,

  /// Keep camera metadata but remove the GPS block.
  keepWithoutLocation,

  /// Keep everything except the orientation tag, which is reset because
  /// pixels are always rotated upright.
  keep,
}

/// How [ImagePipeline.resize] treats a target box with both sides set.
enum ResizeFit {
  /// Scale to fit inside the box, preserving aspect ratio. Never crops.
  contain,

  /// Scale to fill the box, preserving aspect ratio, then centre-crop.
  cover,

  /// Stretch to exactly the box, ignoring aspect ratio.
  fill,
}

/// How [ImagePipeline.redact] hides a region.
enum RedactionStyle {
  /// Coarse mosaic. Looks natural for faces in casual photos.
  pixelate,

  /// Strong Gaussian blur.
  blur,

  /// Solid colour box. The only style that cannot be partially reversed;
  /// use it for text, documents and anything high-assurance.
  fill,
}

/// Where [ImagePipeline.watermark] places the mark.
enum WatermarkAnchor {
  /// Top-left corner.
  topLeft,

  /// Top edge, centred.
  topCenter,

  /// Top-right corner.
  topRight,

  /// Left edge, centred.
  centerLeft,

  /// Centre.
  center,

  /// Right edge, centred.
  centerRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Bottom edge, centred.
  bottomCenter,

  /// Bottom-right corner.
  bottomRight,
}
