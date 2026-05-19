// Web stub for [ObjectRecognition]. The Google ML Kit packages depend on
// `dart:io` and cannot be compiled for the web. On the web build, all
// detection methods throw [UnsupportedError]; the `Rect`-typed
// [DetectedObject] data class is still usable.

import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

@immutable
class DetectedObject {
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.additionalData,
  });

  final String label;
  final double confidence;
  final Rect boundingBox;
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

  Map<String, dynamic> toMap() => {
        'label': label,
        'confidence': confidence,
        'left': boundingBox.left,
        'top': boundingBox.top,
        'width': boundingBox.width,
        'height': boundingBox.height,
        if (additionalData != null) 'additionalData': additionalData,
      };
}

class ObjectRecognition {
  ObjectRecognition._();

  static Never _unsupported() =>
      throw UnsupportedError('ObjectRecognition is not supported on the web.');

  static Future<List<DetectedObject>> detectObjects(String imagePath) async =>
      _unsupported();

  static Future<List<DetectedObject>> detectObjectsFromPath(
    String imagePath,
  ) async =>
      _unsupported();

  static Future<List<DetectedObject>> detectObjectsFromBytes(
    Uint8List bytes,
    Object metadata,
  ) async =>
      _unsupported();

  static Future<void> dispose() async {}
}
