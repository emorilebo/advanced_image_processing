import 'dart:typed_data';
import 'package:advanced_image_processing_toolkit/src/filters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List testImageBytes;

  setUp(() {
    // Create a simple 100x100 RED image for testing
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    testImageBytes = Uint8List.fromList(img.encodeJpg(image));
  });

  group('Geometric Transformations', () {
    test('applyResize resizes image correctly', () async {
      final resized = await ImageFilters.applyResize(testImageBytes, width: 50, height: 50);
      expect(resized, isNotEmpty);
      
      final decoded = img.decodeImage(resized)!;
      expect(decoded.width, 50);
      expect(decoded.height, 50);
    });

    test('applyRotate rotates image', () async {
      // Create a 100x50 image to test rotation dimensions
      final landscapeImage = img.Image(width: 100, height: 50);
      img.fill(landscapeImage, color: img.ColorRgb8(0, 255, 0));
      final landscapeBytes = Uint8List.fromList(img.encodeJpg(landscapeImage));

      final rotated = await ImageFilters.applyRotate(landscapeBytes, 90);
      expect(rotated, isNotEmpty);

      final decoded = img.decodeImage(rotated)!;
      // Dimensions should be swapped after 90 deg rotation
      expect(decoded.width, 50);
      expect(decoded.height, 100);
    });

    test('applyCrop returns cropped region', () async {
      final cropped = await ImageFilters.applyCrop(testImageBytes, 10, 10, 50, 50);
      expect(cropped, isNotEmpty);

      final decoded = img.decodeImage(cropped)!;
      expect(decoded.width, 50);
      expect(decoded.height, 50);
    });

    test('applyFlip works without error', () async {
      final flipped = await ImageFilters.applyFlip(testImageBytes, horizontal: true);
      expect(flipped, isNotEmpty);
      // Logic verification for flip usually requires checking pixel data, 
      // ensuring it runs without error is sufficient for basic unit testing here.
    });
  });

  group('Color Adjustments', () {
    test('adjustContrast runs successfully', () async {
      final result = await ImageFilters.adjustContrast(testImageBytes, 1.5);
      expect(result, isNotEmpty);
    });

    test('adjustSaturation runs successfully', () async {
      final result = await ImageFilters.adjustSaturation(testImageBytes, 0.5);
      expect(result, isNotEmpty);
    });
  });

  group('Watermarking', () {
    test('applyWatermark composes images', () async {
      final watermark = img.Image(width: 20, height: 20);
      img.fill(watermark, color: img.ColorRgb8(0, 0, 255));
      final watermarkBytes = Uint8List.fromList(img.encodePng(watermark));

      final result = await ImageFilters.applyWatermark(testImageBytes, watermarkBytes);
      expect(result, isNotEmpty);
      
      final decoded = img.decodeImage(result)!;
      // Should still be original size
      expect(decoded.width, 100);
      expect(decoded.height, 100);
    });
  });
}
