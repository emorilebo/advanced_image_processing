/// Fast, private, on-device image processing for Flutter.
///
/// - [ImagePipeline]: chain any number of operations; decode once, encode
///   once, on a background isolate.
/// - [FilterPreset] and [ColorMatrix]: looks you can preview live on the
///   GPU and export pixel-identically.
/// - [CubeLut]: professional `.cube` colour grades.
/// - [ObjectRecognition]: ML Kit faces, text, pose and objects, plus
///   one-call redaction.
/// - Widgets: [ImageCompareSlider], [DetectionOverlay].
/// - [ImageFilters]: one-call filters, kept for 0.2.x code.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'advanced_image_processing_toolkit_platform_interface.dart';
import 'src/platform_support.dart' as platform;

export 'engine.dart';
export 'src/augmented_reality.dart';
export 'src/detection/detected_object.dart';
// ML Kit needs dart:io; the web build gets a stub that throws.
export 'src/detection/object_recognition.dart'
    if (dart.library.js_interop) 'src/detection/object_recognition_web.dart';
export 'src/filters.dart';
export 'src/widgets/color_matrix_filter.dart';
export 'src/widgets/detection_overlay.dart';
export 'src/widgets/image_compare_slider.dart';

/// Toolkit-level information and setup.
class AdvancedImageProcessingToolkit {
  AdvancedImageProcessingToolkit._();

  /// Toolkit version. Kept in sync with `pubspec.yaml`.
  static const String version = '0.3.0';

  static bool _isInitialized = false;

  /// Marks the toolkit as initialised. Optional: every API works without
  /// it. Detectors are created lazily on first use.
  static Future<bool> initialize({
    bool enableObjectDetection = true,
    @Deprecated('AR support is deprecated and will be removed in 0.4.0.')
    bool enableAR = false,
  }) async {
    _isInitialized = true;
    return true;
  }

  /// Whether [initialize] has been called.
  static bool get isInitialized => _isInitialized;

  /// The native platform version, e.g. "Android 14" or "iOS 17.4".
  static Future<String?> getPlatformVersion() =>
      AdvancedImageProcessingToolkitPlatform.instance.getPlatformVersion();

  /// Whether ML Kit detection can run here (Android and iOS).
  static bool get isDetectionSupported =>
      !kIsWeb && (platform.isAndroid || platform.isIOS);

  /// Whether pipelines run on a background isolate here (everything except
  /// the web).
  static bool get runsInBackground => !kIsWeb;

  /// Whether the OS could host AR. See [AugmentedReality].
  @Deprecated('AR support is deprecated and will be removed in 0.4.0.')
  static bool isARSupported() =>
      !kIsWeb && (platform.isAndroid || platform.isIOS);
}
