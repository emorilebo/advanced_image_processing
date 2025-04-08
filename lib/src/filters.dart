import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:image/image.dart' as img;
import 'dart:math';

final _logger = Logger('ImageFilters');

/// Provides various image filtering capabilities
///
/// Current filters include:
/// - Grayscale conversion
/// - Gaussian blur
/// - Brightness adjustment
/// - Sepia tone
/// - Invert colors
/// - Edge detection
/// - Emboss effect
///
/// Upcoming filters in future releases:
/// - Vignette effect
/// - Color manipulation (HSL adjustments, tinting)
/// - Artistic filters (watercolor, oil painting, sketch)
/// - Custom filter chains
class ImageFilters {
  static const MethodChannel _channel = MethodChannel('advanced_image_processing_toolkit/filters');

  /// Applies grayscale filter to the provided image data
  static Future<Uint8List> applyGrayscale(Uint8List imageData) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('applyGrayscale', {
        'imageData': imageData,
      });
      
      if (result != null) {
        _logger.info('Grayscale filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applyGrayscaleDart(imageData);
    } catch (e) {
      _logger.warning('Failed to apply grayscale filter using native implementation: $e');
      return _applyGrayscaleDart(imageData);
    }
  }
  
  /// Dart implementation of grayscale filter
  static Uint8List _applyGrayscaleDart(Uint8List imageData) {
    _logger.info('Using Dart implementation for grayscale filter');
    final image = img.decodeImage(imageData);
    if (image == null) return imageData;
    
    final grayscale = img.grayscale(image);
    return Uint8List.fromList(img.encodeJpg(grayscale));
  }

  /// Applies Gaussian blur with specified sigma value
  static Future<Uint8List> applyBlur(Uint8List imageData, double sigma) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('applyBlur', {
        'imageData': imageData,
        'sigma': sigma,
      });
      
      if (result != null) {
        _logger.info('Blur filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applyBlurDart(imageData, sigma);
    } catch (e) {
      _logger.warning('Failed to apply blur filter using native implementation: $e');
      return _applyBlurDart(imageData, sigma);
    }
  }
  
  /// Dart implementation of blur filter
  static Uint8List _applyBlurDart(Uint8List imageData, double sigma) {
    _logger.info('Using Dart implementation for blur filter');
    final image = img.decodeImage(imageData);
    if (image == null) return imageData;
    
    final blurred = img.gaussianBlur(image, radius: sigma.toInt());
    return Uint8List.fromList(img.encodeJpg(blurred));
  }

  /// Adjusts the brightness of the image
  static Future<Uint8List> adjustBrightness(
    Uint8List imageBytes,
    double factor,
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'adjustBrightness',
        {
          'imageBytes': imageBytes,
          'factor': factor,
        },
      );
      
      if (result != null) {
        _logger.info('Brightness adjusted successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _adjustBrightnessDart(imageBytes, factor);
    } catch (e) {
      _logger.warning('Failed to adjust brightness using native implementation: $e');
      return _adjustBrightnessDart(imageBytes, factor);
    }
  }
  
  /// Dart implementation of brightness adjustment
  static Uint8List _adjustBrightnessDart(Uint8List imageBytes, double factor) {
    _logger.info('Using Dart implementation for brightness adjustment');
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    
    // Convert factor to a range between -100 and 100 as expected by img.adjustColor
    final adjustmentValue = (factor * 100).toInt();
    _logger.info('Applying brightness adjustment with value: $adjustmentValue');
    
    final adjusted = img.adjustColor(image, brightness: adjustmentValue);
    return Uint8List.fromList(img.encodeJpg(adjusted));
  }
  
  /// Applies sepia tone filter to the image
  static Future<Uint8List> applySepia(Uint8List imageBytes) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'applySepia',
        {'imageBytes': imageBytes},
      );
      
      if (result != null) {
        _logger.info('Sepia filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applySepiaFilter(imageBytes);
    } catch (e) {
      _logger.warning('Failed to apply sepia filter using native implementation: $e');
      return _applySepiaFilter(imageBytes);
    }
  }
  
  /// Dart implementation of sepia filter
  static Uint8List _applySepiaFilter(Uint8List imageBytes) {
    _logger.info('Using Dart implementation for sepia filter');
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    
    final sepia = img.sepia(image);
    return Uint8List.fromList(img.encodeJpg(sepia));
  }
  
  /// Inverts the colors of the image
  static Future<Uint8List> applyInvert(Uint8List imageBytes) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'applyInvert',
        {'imageBytes': imageBytes},
      );
      
      if (result != null) {
        _logger.info('Invert filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applyInvertFilter(imageBytes);
    } catch (e) {
      _logger.warning('Failed to apply invert filter using native implementation: $e');
      return _applyInvertFilter(imageBytes);
    }
  }
  
  /// Dart implementation of invert filter
  static Uint8List _applyInvertFilter(Uint8List imageBytes) {
    _logger.info('Using Dart implementation for invert filter');
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    
    final inverted = img.invert(image);
    return Uint8List.fromList(img.encodeJpg(inverted));
  }

  /// Applies a vignette effect to the image
  static Future<Uint8List> applyVignette(
    Uint8List imageBytes,
    {double intensity = 0.5, double radius = 0.5}
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'applyVignette',
        {
          'imageBytes': imageBytes,
          'intensity': intensity,
          'radius': radius,
        },
      );
      
      if (result != null) {
        _logger.info('Vignette filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applyVignetteDart(imageBytes, intensity, radius);
    } catch (e) {
      _logger.warning('Failed to apply vignette filter using native implementation: $e');
      return _applyVignetteDart(imageBytes, intensity, radius);
    }
  }
  
  /// Dart implementation of vignette filter
  static Uint8List _applyVignetteDart(
    Uint8List imageBytes,
    double intensity,
    double radius,
  ) {
    _logger.info('Using Dart implementation for vignette filter');
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    
    final width = image.width;
    final height = image.height;
    final centerX = width / 2;
    final centerY = height / 2;
    final maxDistance = sqrt(centerX * centerX + centerY * centerY);
    
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final distance = sqrt(
          pow(x - centerX, 2) + pow(y - centerY, 2)
        ) / maxDistance;
        
        final factor = 1 - (distance * distance * intensity * radius);
        final pixel = image.getPixel(x, y);
        
        image.setPixelRgba(
          x,
          y,
          (pixel.r * factor).round(),
          (pixel.g * factor).round(),
          (pixel.b * factor).round(),
          pixel.a,
        );
      }
    }
    
    return Uint8List.fromList(img.encodeJpg(image));
  }

  /// Applies a watercolor effect to the image
  static Future<Uint8List> applyWatercolor(
    Uint8List imageBytes,
    {int radius = 5, double intensity = 0.5}
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'applyWatercolor',
        {
          'imageBytes': imageBytes,
          'radius': radius,
          'intensity': intensity,
        },
      );
      
      if (result != null) {
        _logger.info('Watercolor filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applyWatercolorDart(imageBytes, radius, intensity);
    } catch (e) {
      _logger.warning('Failed to apply watercolor filter using native implementation: $e');
      return _applyWatercolorDart(imageBytes, radius, intensity);
    }
  }
  
  /// Dart implementation of watercolor filter
  static Uint8List _applyWatercolorDart(
    Uint8List imageBytes,
    int radius,
    double intensity,
  ) {
    _logger.info('Using Dart implementation for watercolor filter');
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    
    // Apply blur for edge preservation instead of bilateral filter
    final blurred = img.gaussianBlur(image, radius: radius);
    
    // Enhance colors and contrast for watercolor effect
    final enhanced = img.adjustColor(
      blurred,
      saturation: 1.2,
      contrast: 1.1,
    );
    
    return Uint8List.fromList(img.encodeJpg(enhanced));
  }

  /// Applies an oil painting effect to the image
  static Future<Uint8List> applyOilPainting(
    Uint8List imageBytes,
    {int radius = 4, int levels = 20}
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'applyOilPainting',
        {
          'imageBytes': imageBytes,
          'radius': radius,
          'levels': levels,
        },
      );
      
      if (result != null) {
        _logger.info('Oil painting filter applied successfully using native implementation');
        return result;
      }
      
      // Fallback to Dart implementation
      return _applyOilPaintingDart(imageBytes, radius, levels);
    } catch (e) {
      _logger.warning('Failed to apply oil painting filter using native implementation: $e');
      return _applyOilPaintingDart(imageBytes, radius, levels);
    }
  }
  
  /// Dart implementation of oil painting filter
  static Uint8List _applyOilPaintingDart(
    Uint8List imageBytes,
    int radius,
    int levels,
  ) {
    _logger.info('Using Dart implementation for oil painting filter');
    final image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;
    
    final width = image.width;
    final height = image.height;
    final result = img.Image(width: width, height: height);
    
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var maxIntensity = 0;
        var maxCount = 0;
        var r = 0, g = 0, b = 0;
        
        for (var ky = -radius; ky <= radius; ky++) {
          for (var kx = -radius; kx <= radius; kx++) {
            final px = x + kx;
            final py = y + ky;
            
            if (px >= 0 && px < width && py >= 0 && py < height) {
              final pixel = image.getPixel(px, py);
              final intensity = ((pixel.r.toInt() + pixel.g.toInt() + pixel.b.toInt()) / 3).round();
              final level = (intensity * levels / 255).round();
              
              if (level > maxIntensity) {
                maxIntensity = level;
                maxCount = 1;
                r = pixel.r.toInt();
                g = pixel.g.toInt();
                b = pixel.b.toInt();
              } else if (level == maxIntensity) {
                maxCount++;
                r += pixel.r.toInt();
                g += pixel.g.toInt();
                b += pixel.b.toInt();
              }
            }
          }
        }
        
        result.setPixelRgba(
          x,
          y,
          (r / maxCount).round(),
          (g / maxCount).round(),
          (b / maxCount).round(),
          255,
        );
      }
    }
    
    return Uint8List.fromList(img.encodeJpg(result));
  }
} 