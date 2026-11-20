import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'advanced_image_processing_toolkit_platform_interface.dart';

/// An implementation of [AdvancedImageProcessingToolkitPlatform] that uses method channels.
class MethodChannelAdvancedImageProcessingToolkit
    extends AdvancedImageProcessingToolkitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'advanced_image_processing_toolkit',
  );

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
