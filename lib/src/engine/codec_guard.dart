// Internal: not exported.

import 'errors.dart';

/// Runs a codec call on untrusted bytes. Malformed input can make decoders
/// throw arbitrary errors (`RangeError`, `FormatException`, ...); those are
/// reported as [UnsupportedImageException] so callers handle one type.
/// Resource exhaustion is never masked.
T guardCodec<T>(String message, T Function() body) {
  try {
    return body();
  } on ImageProcessingException {
    rethrow;
  } on OutOfMemoryError {
    rethrow;
  } on StackOverflowError {
    rethrow;
  } catch (e) {
    throw UnsupportedImageException('$message ($e)');
  }
}
