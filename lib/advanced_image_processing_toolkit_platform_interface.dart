import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'advanced_image_processing_toolkit_method_channel.dart';

abstract class AdvancedImageProcessingToolkitPlatform
    extends PlatformInterface {
  /// Constructs a AdvancedImageProcessingToolkitPlatform.
  AdvancedImageProcessingToolkitPlatform() : super(token: _token);

  static final Object _token = Object();

  static AdvancedImageProcessingToolkitPlatform _instance =
      MethodChannelAdvancedImageProcessingToolkit();

  /// The default instance of [AdvancedImageProcessingToolkitPlatform] to use.
  ///
  /// Defaults to [MethodChannelAdvancedImageProcessingToolkit].
  static AdvancedImageProcessingToolkitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AdvancedImageProcessingToolkitPlatform] when
  /// they register themselves.
  static set instance(AdvancedImageProcessingToolkitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
