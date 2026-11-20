import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart'
    hide DetectedObject;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';

import '../engine/options.dart';
import '../engine/pipeline.dart';
import 'detected_object.dart';

final _logger = Logger('ObjectRecognition');

/// On-device detection of objects, faces, text and human pose, powered by
/// Google ML Kit (Android and iOS).
///
/// Only the detectors you ask for are created and run, and they run
/// concurrently. Call [dispose] to release native resources; detectors are
/// recreated on next use.
class ObjectRecognition {
  ObjectRecognition._();

  static ObjectDetector? _object;
  static FaceDetector? _face;
  static PoseDetector? _pose;
  static TextRecognizer? _text;

  static ObjectDetector get _objectDetector => _object ??= ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  static FaceDetector get _faceDetector => _face ??= FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      minFaceSize: 0.05,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  static PoseDetector get _poseDetector => _pose ??= PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.single),
  );

  static TextRecognizer get _textRecognizer => _text ??= TextRecognizer();

  /// Runs [detectors] on the image file at [imagePath].
  ///
  /// File input lets ML Kit read the image's real size and EXIF rotation,
  /// so this is the reliable entry point. Use [detectObjectsFromBytes] only
  /// for raw camera frames whose metadata you know.
  static Future<List<DetectedObject>> detectObjectsFromPath(
    String imagePath, {
    Set<DetectorType> detectors = DetectorType.all,
  }) => _run(InputImage.fromFile(File(imagePath)), detectors);

  /// Runs [detectors] on raw pixel bytes (e.g. a camera frame).
  ///
  /// [metadata] must be accurate: ML Kit cannot infer width, height, stride
  /// or format from a buffer.
  static Future<List<DetectedObject>> detectObjectsFromBytes(
    Uint8List bytes,
    InputImageMetadata metadata, {
    Set<DetectorType> detectors = DetectorType.all,
  }) => _run(InputImage.fromBytes(bytes: bytes, metadata: metadata), detectors);

  /// Alias of [detectObjectsFromPath], kept for 0.2.x callers.
  static Future<List<DetectedObject>> detectObjects(
    String imagePath, {
    Set<DetectorType> detectors = DetectorType.all,
  }) => detectObjectsFromPath(imagePath, detectors: detectors);

  /// Faces only.
  static Future<List<DetectedObject>> detectFaces(String imagePath) =>
      detectObjectsFromPath(imagePath, detectors: const {DetectorType.face});

  /// Text blocks only. Each result's `additionalData['text']` holds the text.
  static Future<List<DetectedObject>> recognizeText(String imagePath) =>
      detectObjectsFromPath(imagePath, detectors: const {DetectorType.text});

  /// Finds [targets] in the photo at [imagePath] and hides them, entirely
  /// on device. Faces by default; add [DetectorType.text] to hide name
  /// tags, plates and documents.
  ///
  /// The output is re-encoded with EXIF (including GPS) stripped unless
  /// [metadata] says otherwise. For text, prefer [RedactionStyle.fill]:
  /// pixelated text can be partially recovered.
  static Future<RedactionResult> redactFromPath(
    String imagePath, {
    Set<DetectorType> targets = const {DetectorType.face},
    RedactionStyle style = RedactionStyle.pixelate,
    double padding = 0.15,
    OutputFormat output = const OutputFormat.original(),
    MetadataPolicy metadata = MetadataPolicy.strip,
  }) async {
    final found = await detectObjectsFromPath(imagePath, detectors: targets);
    final bytes = await File(imagePath).readAsBytes();
    final result = await const ImagePipeline()
        .redact(found.map((d) => d.region), style: style, padding: padding)
        .run(bytes, output: output, metadata: metadata);
    return RedactionResult(
      bytes: result.bytes,
      width: result.width,
      height: result.height,
      regions: List.unmodifiable(found),
    );
  }

  /// Releases every native detector. Safe to call repeatedly; later calls
  /// to detection methods recreate what they need.
  static Future<void> dispose() async {
    final closing = <Future<void>>[
      if (_object != null) _object!.close(),
      if (_face != null) _face!.close(),
      if (_pose != null) _pose!.close(),
      if (_text != null) _text!.close(),
    ];
    _object = null;
    _face = null;
    _pose = null;
    _text = null;
    await Future.wait(closing);
  }

  static Future<List<DetectedObject>> _run(
    InputImage input,
    Set<DetectorType> detectors,
  ) async {
    final batches = await Future.wait([
      for (final type in detectors)
        switch (type) {
          DetectorType.object => _guard(type, () => _objects(input)),
          DetectorType.face => _guard(type, () => _faces(input)),
          DetectorType.pose => _guard(type, () => _poses(input)),
          DetectorType.text => _guard(type, () => _texts(input)),
        },
    ]);
    final all = [for (final batch in batches) ...batch];
    _logger.fine('Detected ${all.length} regions');
    return all;
  }

  /// One failing detector (e.g. a model still downloading) must not sink
  /// the others, so failures are logged and yield no detections.
  static Future<List<DetectedObject>> _guard(
    DetectorType type,
    Future<List<DetectedObject>> Function() body,
  ) async {
    try {
      return await body();
    } catch (e) {
      _logger.warning('${type.name} detector failed: $e');
      return const [];
    }
  }

  static Future<List<DetectedObject>> _objects(InputImage input) async {
    final objects = await _objectDetector.processImage(input);
    return [
      for (final o in objects)
        DetectedObject(
          type: DetectorType.object,
          label: o.labels.isNotEmpty ? o.labels.first.text : 'Object',
          confidence: o.labels.isNotEmpty ? o.labels.first.confidence : 0.0,
          boundingBox: o.boundingBox,
          additionalData: {
            'trackingId': o.trackingId,
            'labels': [
              for (final l in o.labels)
                {'text': l.text, 'confidence': l.confidence},
            ],
          },
        ),
    ];
  }

  static Future<List<DetectedObject>> _faces(InputImage input) async {
    final faces = await _faceDetector.processImage(input);
    return [
      for (final f in faces)
        DetectedObject(
          type: DetectorType.face,
          label: 'Face',
          confidence: 1.0,
          boundingBox: f.boundingBox,
          additionalData: {
            'smilingProbability': f.smilingProbability,
            'leftEyeOpenProbability': f.leftEyeOpenProbability,
            'rightEyeOpenProbability': f.rightEyeOpenProbability,
            'headEulerAngleY': f.headEulerAngleY,
            'headEulerAngleZ': f.headEulerAngleZ,
            'landmarkCount': f.landmarks.length,
          },
        ),
    ];
  }

  static Future<List<DetectedObject>> _poses(InputImage input) async {
    final poses = await _poseDetector.processImage(input);
    return [
      for (final p in poses)
        if (p.landmarks.isNotEmpty)
          DetectedObject(
            type: DetectorType.pose,
            label: 'Person',
            confidence:
                p.landmarks.values
                    .map((l) => l.likelihood)
                    .reduce((a, b) => a + b) /
                p.landmarks.length,
            boundingBox: _poseBounds(p),
            additionalData: {
              'landmarks': [
                for (final e in p.landmarks.entries)
                  {
                    'type': e.key.name,
                    'x': e.value.x,
                    'y': e.value.y,
                    'likelihood': e.value.likelihood,
                  },
              ],
            },
          ),
    ];
  }

  static Future<List<DetectedObject>> _texts(InputImage input) async {
    final text = await _textRecognizer.processImage(input);
    return [
      for (final block in text.blocks)
        DetectedObject(
          type: DetectorType.text,
          label: 'Text',
          confidence: 1.0,
          boundingBox: block.boundingBox,
          additionalData: {
            'text': block.text,
            'lines': [for (final l in block.lines) l.text],
          },
        ),
    ];
  }

  static Rect _poseBounds(Pose pose) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final l in pose.landmarks.values) {
      if (l.x < minX) minX = l.x;
      if (l.y < minY) minY = l.y;
      if (l.x > maxX) maxX = l.x;
      if (l.y > maxY) maxY = l.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
