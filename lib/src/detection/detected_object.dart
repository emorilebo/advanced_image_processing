import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// The ML Kit detectors [DetectedObject]s can come from.
enum DetectorType {
  /// Generic objects with coarse category labels.
  object,

  /// Human faces, with smile and eye-open probabilities.
  face,

  /// Human body pose (33 landmarks).
  pose,

  /// Printed and handwritten text (OCR), Latin script.
  text;

  /// Every detector.
  static const Set<DetectorType> all = {object, face, pose, text};
}

/// A single detection from `ObjectRecognition`.
@immutable
class DetectedObject {
  /// Creates a detection.
  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.additionalData,
    this.type,
  });

  /// Restores a detection from [toMap] output.
  factory DetectedObject.fromMap(Map<dynamic, dynamic> map) {
    final typeName = map['type'] as String?;
    return DetectedObject(
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      boundingBox: Rect.fromLTWH(
        (map['left'] as num).toDouble(),
        (map['top'] as num).toDouble(),
        (map['width'] as num).toDouble(),
        (map['height'] as num).toDouble(),
      ),
      additionalData: (map['additionalData'] as Map?)?.cast<String, dynamic>(),
      type: typeName == null ? null : DetectorType.values.byName(typeName),
    );
  }

  /// Display label: "Face", "Text", "Person", or an object category.
  final String label;

  /// Confidence in `[0.0, 1.0]`. ML Kit reports none for faces and text, so
  /// those are `1.0`; pose uses the mean landmark likelihood.
  final double confidence;

  /// Bounding box in the upright source image's pixel coordinates.
  final Rect boundingBox;

  /// Detector-specific data (landmarks, recognised text, probabilities).
  final Map<String, dynamic>? additionalData;

  /// Which detector produced this, or `null` for detections restored from
  /// maps written before 0.3.0.
  final DetectorType? type;

  /// [boundingBox] as a `dart:math` rectangle, the type
  /// `ImagePipeline.redact` accepts.
  math.Rectangle<double> get region => boundingBox.toRectangle();

  /// Serialises to a plain map.
  Map<String, dynamic> toMap() => {
    'label': label,
    'confidence': confidence,
    'left': boundingBox.left,
    'top': boundingBox.top,
    'width': boundingBox.width,
    'height': boundingBox.height,
    if (additionalData != null) 'additionalData': additionalData,
    if (type != null) 'type': type!.name,
  };

  @override
  String toString() =>
      'DetectedObject($label ${(confidence * 100).round()}% at $boundingBox)';
}

/// The output of `ObjectRecognition.redactFromPath`.
@immutable
class RedactionResult {
  /// Creates a result.
  const RedactionResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.regions,
  });

  /// The redacted, re-encoded image (metadata stripped by default).
  final Uint8List bytes;

  /// Output width in pixels.
  final int width;

  /// Output height in pixels.
  final int height;

  /// What was found and hidden. Empty means nothing matched and the image
  /// was only re-encoded.
  final List<DetectedObject> regions;
}

/// Converts Flutter rectangles to the `dart:math` type the engine uses.
extension RectToRectangle on Rect {
  /// This rectangle as a `dart:math` [math.Rectangle].
  math.Rectangle<double> toRectangle() =>
      math.Rectangle<double>(left, top, width, height);
}
