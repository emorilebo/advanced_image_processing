import 'dart:async';

import 'package:flutter/foundation.dart';

import 'advanced_image_processing_toolkit_platform_interface.dart';
import 'src/platform_support.dart' as platform;

export 'src/filters.dart';
export 'src/augmented_reality.dart';
// ML Kit depends on `dart:io`; on the web we export a stub that throws
// `UnsupportedError` so consumer apps still compile.
export 'src/object_recognition.dart'
    if (dart.library.html) 'src/object_recognition_web_stub.dart';

/// Entry point for the Advanced Image Processing Toolkit.
///
/// Provides:
/// - Image filters (grayscale, blur, brightness, sepia, invert, vignette,
///   watercolor, oil-painting, contrast, saturation, watermark)
/// - Geometric transforms (resize, rotate, crop, flip)
/// - ML-powered detection (objects, faces, text, pose) via Google ML Kit
/// - Augmented-reality method channels (consumer app must add ARKit/ARCore)
class AdvancedImageProcessingToolkit {
  AdvancedImageProcessingToolkit._();

  /// Toolkit version. Kept in sync with `pubspec.yaml`.
  static const String version = '0.2.0';

  static bool _isInitialized = false;

  /// Initializes the toolkit. Safe to call multiple times.
  ///
  /// Returns `true` on success. AR is silently disabled on platforms where
  /// it cannot run (web, desktop) regardless of [enableAR].
  static Future<bool> initialize({
    bool enableObjectDetection = true,
    bool enableAR = true,
  }) async {
    if (enableAR && !isARSupported()) {
      debugPrint(
        'AdvancedImageProcessingToolkit: AR requested but not supported on '
        'this platform — continuing without AR.',
      );
    }
    _isInitialized = true;
    return true;
  }

  /// Whether [initialize] has completed.
  static bool get isInitialized => _isInitialized;

  /// Returns the native platform version (e.g. "Android 14", "iOS 17.4").
  ///
  /// Returns `null` on platforms where the plugin is not registered.
  static Future<String?> getPlatformVersion() {
    return AdvancedImageProcessingToolkitPlatform.instance.getPlatformVersion();
  }

  /// Whether AR features can run on this device.
  ///
  /// Returns `true` only on Android and iOS. Note: this does NOT check whether
  /// the consumer app has added `arkit_plugin` / `arcore_flutter_plugin` —
  /// AR calls will fail at runtime if those are missing.
  static bool isARSupported() {
    if (kIsWeb) return false;
    return platform.isAndroid || platform.isIOS;
  }
}
