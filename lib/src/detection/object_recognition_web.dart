// Web build of ObjectRecognition. Google ML Kit is Android/iOS only, so
// every detection method throws [UnsupportedError]. The data classes in
// detected_object.dart still work, so shared UI code compiles everywhere.

import 'dart:typed_data';

import '../engine/options.dart';
import 'detected_object.dart';

/// ML Kit detection is not available on the web; every call throws
/// [UnsupportedError].
class ObjectRecognition {
  ObjectRecognition._();

  static Never _unsupported() => throw UnsupportedError(
    'ObjectRecognition uses Google ML Kit, which runs on Android and iOS only.',
  );

  /// Not supported on the web.
  static Future<List<DetectedObject>> detectObjectsFromPath(
    String imagePath, {
    Set<DetectorType> detectors = DetectorType.all,
  }) async => _unsupported();

  /// Not supported on the web.
  static Future<List<DetectedObject>> detectObjectsFromBytes(
    Uint8List bytes,
    Object metadata, {
    Set<DetectorType> detectors = DetectorType.all,
  }) async => _unsupported();

  /// Not supported on the web.
  static Future<List<DetectedObject>> detectObjects(
    String imagePath, {
    Set<DetectorType> detectors = DetectorType.all,
  }) async => _unsupported();

  /// Not supported on the web.
  static Future<List<DetectedObject>> detectFaces(String imagePath) async =>
      _unsupported();

  /// Not supported on the web.
  static Future<List<DetectedObject>> recognizeText(String imagePath) async =>
      _unsupported();

  /// Not supported on the web.
  static Future<RedactionResult> redactFromPath(
    String imagePath, {
    Set<DetectorType> targets = const {DetectorType.face},
    RedactionStyle style = RedactionStyle.pixelate,
    double padding = 0.15,
    OutputFormat output = const OutputFormat.original(),
    MetadataPolicy metadata = MetadataPolicy.strip,
  }) async => _unsupported();

  /// No-op on the web.
  static Future<void> dispose() async {}
}
