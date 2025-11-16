// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'advanced_image_processing_toolkit_platform_interface.dart';

export 'src/filters.dart';
export 'src/object_recognition.dart';
export 'src/augmented_reality.dart';

/// Main class for the Advanced Image Processing Toolkit
///
/// This toolkit provides comprehensive image processing capabilities including:
/// - Real-time image filters (grayscale, blur, brightness adjustment)
/// - Object detection and recognition
/// - Augmented reality features
///
/// Future updates will include:
/// - Enhanced image filters (sepia, vignette, artistic filters)
/// - Custom ML model support for specialized object detection
/// - Advanced AR capabilities (occlusion, lighting estimation)
/// - Web and desktop platform support
/// - Performance optimizations for real-time processing
class AdvancedImageProcessingToolkit {
  static const String version = '0.1.2';
  static bool _isInitialized = false;
  
  /// Initializes the toolkit with optional configuration
  ///
  /// [enableObjectDetection] - Whether to initialize object detection capabilities
  /// [enableAR] - Whether to initialize augmented reality capabilities
  ///
  /// Future versions will support additional parameters for:
  /// - Custom ML models
  /// - AR feature configuration
  /// - Performance optimization settings
  static Future<bool> initialize({
    bool enableObjectDetection = true,
    bool enableAR = true,
  }) async {
    try {
      // Check platform compatibility
      if (enableAR) {
        if (kIsWeb) {
          debugPrint('AR features are not available on web platform');
          enableAR = false;
        } else if (!Platform.isAndroid && !Platform.isIOS) {
          debugPrint('AR features are only available on Android and iOS');
          enableAR = false;
        }
      }
      
      // Initialize required native components
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Failed to initialize AdvancedImageProcessingToolkit: $e');
      return false;
    }
  }

  /// Checks if the toolkit is initialized
  static bool get isInitialized => _isInitialized;

  /// Gets the platform version
  ///
  /// This is primarily used for testing platform integration
  static Future<String?> getPlatformVersion() {
    return AdvancedImageProcessingToolkitPlatform.instance.getPlatformVersion();
  }
  
  /// Checks if AR is supported on the current device
  static bool isARSupported() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}
