import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 0.2.x sent every call through this channel first, though nothing native
  // handled it. 0.3.0 must not touch it at all.
  const legacyChannel = MethodChannel(
    'advanced_image_processing_toolkit/filters',
  );
  final channelCalls = <MethodCall>[];

  setUp(() {
    channelCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(legacyChannel, (call) async {
          channelCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(legacyChannel, null);
    expect(channelCalls, isEmpty, reason: 'no platform-channel round trips');
  });

  final photo = solid(60, 40);

  test('every 0.2.x method still works and keeps dimensions', () async {
    final calls = <String, Future<Uint8List> Function()>{
      'applyGrayscale': () => ImageFilters.applyGrayscale(photo),
      'applyBlur': () => ImageFilters.applyBlur(photo, 3),
      'adjustBrightness': () => ImageFilters.adjustBrightness(photo, 0.2),
      'applySepia': () => ImageFilters.applySepia(photo),
      'applyInvert': () => ImageFilters.applyInvert(photo),
      'applyVignette': () => ImageFilters.applyVignette(photo),
      'applyWatercolor': () => ImageFilters.applyWatercolor(photo, radius: 3),
      'applyOilPainting': () => ImageFilters.applyOilPainting(photo, radius: 2),
      'applyFlip': () => ImageFilters.applyFlip(photo, vertical: true),
      'adjustContrast': () => ImageFilters.adjustContrast(photo, 1.3),
      'adjustSaturation': () => ImageFilters.adjustSaturation(photo, 0.4),
    };
    for (final c in calls.entries) {
      final out = decode(await c.value());
      expect((out.width, out.height), (60, 40), reason: c.key);
    }
  });

  test('geometric transforms', () async {
    final resized = decode(
      await ImageFilters.applyResize(photo, width: 30, height: 30),
    );
    expect((resized.width, resized.height), (30, 30));
    final rotated = decode(await ImageFilters.applyRotate(photo, 90));
    expect((rotated.width, rotated.height), (40, 60));
    final cropped = decode(await ImageFilters.applyCrop(photo, 10, 10, 20, 15));
    expect((cropped.width, cropped.height), (20, 15));
  });

  test(
    'regression: brightness +0.5 brightens without blowing out to white',
    () async {
      final grey = solid(10, 10, r: 100, g: 100, b: 100, png: true);
      final brighter = rgbAt(
        decode(await ImageFilters.adjustBrightness(grey, 0.5)),
        5,
        5,
      );
      expect(brighter[0], inInclusiveRange(220, 230));
      final darker = rgbAt(
        decode(await ImageFilters.adjustBrightness(grey, -0.2)),
        5,
        5,
      );
      expect(darker[0], inInclusiveRange(45, 52));
    },
  );

  test('regression: watermark opacity is applied', () async {
    final base = solid(40, 40, r: 255, g: 255, b: 255, png: true);
    final mark = solid(10, 10, r: 0, g: 0, b: 0, png: true);
    final out = decode(
      await ImageFilters.applyWatermark(base, mark, x: 5, y: 5, opacity: 0.25),
    );
    expect(rgbAt(out, 8, 8)[0], inInclusiveRange(189, 193));
  });

  test('regression: PNG input keeps its alpha channel', () async {
    final out = await ImageFilters.applyGrayscale(halfTransparent(20, 10));
    expect(img.findFormatForData(out), img.ImageFormat.png);
    expect(decode(out).getPixel(1, 1).a, 0);
  });

  test('undecodable input is returned unchanged, as in 0.2.x', () async {
    final junk = Uint8List.fromList([0, 1, 2, 3]);
    expect(await ImageFilters.applyGrayscale(junk), same(junk));
    expect(await ImageFilters.applyResize(photo), same(photo));
  });
}
