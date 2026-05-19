import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'platform_support.dart' as platform;

final _logger = Logger('AugmentedReality');

/// Augmented-reality method channel bindings.
///
/// This package only wires the channel calls — to actually use AR you must
/// add the platform AR plugins to your own app:
/// - iOS:     `arkit_plugin`
/// - Android: `arcore_flutter_plugin`
///
/// All methods return `false` (or no-op) on platforms where AR is not
/// supported (web, desktop) so they're safe to call unconditionally.
class AugmentedReality {
  AugmentedReality._();

  static const MethodChannel _channel =
      MethodChannel('advanced_image_processing_toolkit/augmented_reality');

  static bool _isSessionRunning = false;

  /// Whether the current platform can run AR (Android / iOS).
  ///
  /// Does NOT verify the consumer app has added ARKit/ARCore plugins — AR
  /// calls may still fail at runtime if those are missing.
  static bool isARSupported() {
    if (kIsWeb) return false;
    return platform.isAndroid || platform.isIOS;
  }

  /// Starts an AR session. Returns `true` if the session is running.
  static Future<bool> startARSession() async {
    if (!isARSupported()) {
      _logger.warning('AR is not supported on this platform');
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('startARSession');
      _isSessionRunning = result ?? false;
      return _isSessionRunning;
    } catch (e) {
      _logger.warning('Failed to start AR session: $e');
      return false;
    }
  }

  /// Stops the current AR session. Returns `true` if no session is running.
  static Future<bool> stopARSession() async {
    if (!isARSupported()) return true;
    try {
      final result = await _channel.invokeMethod<bool>('stopARSession');
      _isSessionRunning = !(result ?? false);
      return !_isSessionRunning;
    } catch (e) {
      _logger.warning('Failed to stop AR session: $e');
      return false;
    }
  }

  /// Places a 3D model at [position] (x, y, z in metres, camera-relative).
  ///
  /// [rotation] is degrees on each axis. Returns `true` if placement
  /// succeeded.
  static Future<bool> placeModel({
    required String modelPath,
    required List<double> position,
    double scale = 1.0,
    List<double> rotation = const [0.0, 0.0, 0.0],
  }) async {
    if (!isARSupported()) {
      _logger.warning('AR is not supported on this platform');
      return false;
    }
    if (!_isSessionRunning) {
      _logger.warning('AR session is not running. Call startARSession() first.');
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'placeModel',
        {
          'modelPath': modelPath,
          'position': position,
          'scale': scale,
          'rotation': rotation,
        },
      );
      return result ?? false;
    } catch (e) {
      _logger.warning('Failed to place 3D model: $e');
      return false;
    }
  }

  /// Whether an AR session is currently running.
  static bool get isSessionRunning => _isSessionRunning;
}
