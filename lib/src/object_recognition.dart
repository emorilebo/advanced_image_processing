import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ObjectRecognition');

/// A single detection produced by [ObjectRecognition.detectObjects].
@immutable
class DetectedObject {
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.additionalData,
  });

  /// Display label (e.g. "Face", "Text", an object category, "Person").
  final String label;

  /// Confidence score in `[0.0, 1.0]`.
  final double confidence;

  /// Bounding box in the source image's pixel coordinates.
  final Rect boundingBox;

  /// Detector-specific extra data (landmarks, recognised text, …).
  final Map<String, dynamic>? additionalData;

  factory DetectedObject.fromMap(Map<dynamic, dynamic> map) {
    return DetectedObject(
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      boundingBox: Rect.fromLTWH(
        (map['left'] as num).toDouble(),
        (map['top'] as num).toDouble(),
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      ),
      additionalData:
          (map['additionalData'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
      'left': boundingBox.left,
      'top': boundingBox.top,
      'width': boundingBox.width,
      'height': boundingBox.height,
      if (additionalData != null) 'additionalData': additionalData,
    };
  }
}

/// ML Kit-powered detection of objects, faces, text, and human pose.
///
/// Call [dispose] when the app is shutting down to release native ML Kit
/// resources.
class ObjectRecognition {
  ObjectRecognition._();

  static final _objectDetector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  static final _textRecognizer = TextRecognizer();

  static final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  static final _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.base,
    ),
  );

  /// Detects objects, faces, text, and pose in [imagePath].
  ///
  /// ML Kit's `InputImage.fromBytes` requires you to know the image's exact
  /// width/height/stride/format upfront, so the safe, portable entry-point
  /// takes a **file path**. Use [detectObjectsFromBytes] if you have raw
  /// bytes and you know the metadata.
  static Future<List<DetectedObject>> detectObjectsFromPath(
    String imagePath,
  ) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    return _runAllDetectors(inputImage);
  }

  /// Detects objects, faces, text, and pose in raw image bytes.
  ///
  /// You MUST provide accurate [metadata] — ML Kit cannot infer width,
  /// height, or stride from the byte buffer alone.
  static Future<List<DetectedObject>> detectObjectsFromBytes(
    Uint8List bytes,
    InputImageMetadata metadata,
  ) async {
    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
    return _runAllDetectors(inputImage);
  }

  /// Convenience alias for [detectObjectsFromPath] (back-compat).
  static Future<List<DetectedObject>> detectObjects(String imagePath) =>
      detectObjectsFromPath(imagePath);

  static Future<List<DetectedObject>> _runAllDetectors(
    InputImage inputImage,
  ) async {
    final detections = <DetectedObject>[];

    try {
      final objects = await _objectDetector.processImage(inputImage);
      for (final object in objects) {
        final firstLabel = object.labels.isNotEmpty ? object.labels.first : null;
        detections.add(DetectedObject(
          label: firstLabel?.text ?? 'Object',
          confidence: firstLabel?.confidence ?? 0.0,
          boundingBox: object.boundingBox,
          additionalData: {
            'trackingId': object.trackingId,
            'labels': object.labels
                .map((l) => {'text': l.text, 'confidence': l.confidence})
                .toList(),
          },
        ));
      }
    } catch (e) {
      _logger.warning('Object detector failed: $e');
    }

    try {
      final faces = await _faceDetector.processImage(inputImage);
      for (final face in faces) {
        detections.add(DetectedObject(
          label: 'Face',
          confidence: face.headEulerAngleY != null ? 1.0 : 0.8,
          boundingBox: face.boundingBox,
          additionalData: {
            'smilingProbability': face.smilingProbability,
            'leftEyeOpenProbability': face.leftEyeOpenProbability,
            'rightEyeOpenProbability': face.rightEyeOpenProbability,
            'headEulerAngleY': face.headEulerAngleY,
            'headEulerAngleZ': face.headEulerAngleZ,
            'landmarkCount': face.landmarks.length,
          },
        ));
      }
    } catch (e) {
      _logger.warning('Face detector failed: $e');
    }

    try {
      final poses = await _poseDetector.processImage(inputImage);
      for (final pose in poses) {
        detections.add(DetectedObject(
          label: 'Person',
          confidence: 0.9,
          boundingBox: _calculatePoseBoundingBox(pose),
          additionalData: {
            'landmarks': pose.landmarks.entries
                .map((e) => {
                      'type': e.key.toString(),
                      'x': e.value.x,
                      'y': e.value.y,
                      'likelihood': e.value.likelihood,
                    })
                .toList(),
          },
        ));
      }
    } catch (e) {
      _logger.warning('Pose detector failed: $e');
    }

    try {
      final text = await _textRecognizer.processImage(inputImage);
      for (final block in text.blocks) {
        detections.add(DetectedObject(
          label: 'Text',
          confidence: 0.9,
          boundingBox: block.boundingBox,
          additionalData: {
            'text': block.text,
            'lines': block.lines.map((l) => l.text).toList(),
          },
        ));
      }
    } catch (e) {
      _logger.warning('Text recognizer failed: $e');
    }

    _logger.info('Detected ${detections.length} regions');
    return detections;
  }

  /// Releases ML Kit resources. Safe to call multiple times.
  static Future<void> dispose() async {
    await Future.wait([
      _objectDetector.close(),
      _textRecognizer.close(),
      _faceDetector.close(),
      _poseDetector.close(),
    ]);
  }

  static Rect _calculatePoseBoundingBox(Pose pose) {
    if (pose.landmarks.isEmpty) {
      return const Rect.fromLTWH(0, 0, 0, 0);
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;

    for (final landmark in pose.landmarks.values) {
      if (landmark.x < minX) minX = landmark.x;
      if (landmark.y < minY) minY = landmark.y;
      if (landmark.x > maxX) maxX = landmark.x;
      if (landmark.y > maxY) maxY = landmark.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
