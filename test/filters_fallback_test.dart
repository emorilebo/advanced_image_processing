import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:advanced_image_processing_toolkit/src/filters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('advanced_image_processing_toolkit/filters');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        log.add(methodCall);
        // Simulate native failure/missing plugin
        if (methodCall.method == 'applyGrayscale') {
          throw PlatformException(code: 'UNAVAILABLE', message: 'Native implementation not available');
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('applyGrayscale falls back to Dart implementation when native call fails', () async {
    // Create a simple 2x2 image
    // This is not a real JPEG, but the fallback expects a decode-able image.
    // For unit testing the *logic* of fallback, we might need a mocking strategy for the Dart implementation itself
    // or provide a minimal valid image.
    // However, looking at the implementation, it catches the exception and calls _applyGrayscaleDart.
    // _applyGrayscaleDart tries to decode. If it fails (null), it returns original bytes.
    // So if we pass dummy bytes, it should return dummy bytes, but we verify the channel was invoked.

    final Uint8List testData = Uint8List.fromList([0, 1, 2, 3]);
    
    final result = await ImageFilters.applyGrayscale(testData);

    // Verify channel was called
    expect(log, hasLength(1));
    expect(log.first.method, 'applyGrayscale');
    expect(log.first.arguments, {'imageData': testData});

    // Verify result is returned (even if it's the original data because decode failed)
    expect(result, equals(testData));
  });
}
