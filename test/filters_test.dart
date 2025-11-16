import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageFilters', () {
    test('applyGrayscale returns modified image data', () async {
      final testImageData = Uint8List.fromList(List.filled(100, 255));
      
      final result = await ImageFilters.applyGrayscale(testImageData);
      
      expect(result, isNotNull);
      expect(result, isA<Uint8List>());
    });

    test('applyBlur returns modified image data', () async {
      final testImageData = Uint8List.fromList(List.filled(100, 255));
      
      final result = await ImageFilters.applyBlur(testImageData, 5.0);
      
      expect(result, isNotNull);
      expect(result, isA<Uint8List>());
    });
  });
} 