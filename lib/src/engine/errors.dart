/// Base class for errors raised while running an `ImagePipeline`.
class ImageProcessingException implements Exception {
  /// Creates an exception with a human-readable [message].
  const ImageProcessingException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The input bytes are not an image format the engine can decode.
final class UnsupportedImageException extends ImageProcessingException {
  /// Creates the exception.
  const UnsupportedImageException(super.message);
}

/// The input declares more pixels than the configured `maxInputPixels`.
///
/// Raised from the image header, before any pixel memory is allocated, so a
/// hostile or accidental 20,000 x 20,000 upload cannot exhaust memory.
final class ImageTooLargeException extends ImageProcessingException {
  /// Creates the exception.
  ImageTooLargeException({
    required this.width,
    required this.height,
    required this.maxPixels,
  }) : super(
         'Image is ${width}x$height (${width * height} px), above the '
         'limit of $maxPixels px. Raise maxInputPixels if this is expected.',
       );

  /// Declared width of the rejected image.
  final int width;

  /// Declared height of the rejected image.
  final int height;

  /// The limit that was exceeded.
  final int maxPixels;
}
