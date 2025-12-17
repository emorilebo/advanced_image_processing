import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'advanced_image_processing_toolkit_platform_interface.dart';

/// A web implementation of the AdvancedImageProcessingToolkit plugin.
class AdvancedImageProcessingToolkitWeb extends AdvancedImageProcessingToolkitPlatform {
  /// Constructs a AdvancedImageProcessingToolkitWeb
  AdvancedImageProcessingToolkitWeb();

  static void registerWith(Registrar registrar) {
    AdvancedImageProcessingToolkitPlatform.instance = AdvancedImageProcessingToolkitWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    const version = kIsWeb ? 'Web' : 'Unknown';
    return version;
  }
} 