import 'dart:io';
import 'dart:ui' as ui;

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:advanced_image_processing_toolkit_example/main.dart';
import 'package:advanced_image_processing_toolkit_example/src/state/studio_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _AssetServices extends StudioServices {
  _AssetServices(this.samples);
  final Map<String, PipelineResult> samples;

  @override
  bool get detectionSupported => false;
  @override
  bool get exportSupported => false;
  @override
  bool get runsInBackground => false;
  @override
  Future<Uint8List> loadAsset(String path) async => samples[path]!.bytes;
  @override
  Future<PipelineResult> process(
          ImagePipeline pipeline, Uint8List bytes) async =>
      samples.values.firstWhere((sample) => identical(sample.bytes, bytes));
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('STUDIO_CAPTURE')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  try {
    await tester.runAsync(() async {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory('build/qa').create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    });
  } finally {
    image.dispose();
  }
}

void main() {
  final samples = <String, PipelineResult>{};
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final path in [
      'assets/sample_image.jpg',
      'assets/people_sample.jpg'
    ]) {
      samples[path] = await const ImagePipeline().downscale(2048).run(
            await File(path).readAsBytes(),
            output: const OutputFormat.jpeg(),
          );
    }
  });

  for (final size in [const Size(390, 844), const Size(1600, 1000)]) {
    testWidgets('bundled photos render at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: ToolkitStudio(
              services: _AssetServices(samples), themeMode: ThemeMode.dark)));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          MemoryImage(samples['assets/sample_image.jpg']!.bytes),
          tester.element(find.byType(Scaffold))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('live-colour-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'studio-${size.width.toInt()}');
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
          MemoryImage(samples['assets/people_sample.jpg']!.bytes),
          tester.element(find.byType(Scaffold))));
      await tester.pumpAndSettle();
      expect(find.text('An afternoon in Lagos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'privacy-${size.width.toInt()}');
    });
  }

  test('an actual serialized edit and manual redaction render successfully',
      () async {
    final source = samples['assets/people_sample.jpg']!;
    final recipe = const ImagePipeline()
        .downscale(640)
        .colorMatrix(FilterPreset.vivid.matrix)
        .brightness(0.05)
        .contrast(1.1)
        .saturation(0.9)
        .temperature(0.1)
        .tint(-0.1)
        .exposure(0.5)
        .autoEnhance()
        .sharpen()
        .blur(0.5)
        .vignette(strength: 0.3)
        .grain(amount: 0.1)
        .kuwahara(radius: 2)
        .oilPaint(radius: 1)
        .watercolor(radius: 2)
        .sketch()
        .redact([const Rect.fromLTWH(250, 130, 150, 150).toRectangle()]);
    final restored = ImagePipeline.fromJson(recipe.toJson());
    final result =
        await restored.run(source.bytes, output: const OutputFormat.jpeg());
    expect(result.width, 640);
    expect(result.height, greaterThan(0));
    expect(result.bytes, isNot(source.bytes));
    expect(result.format, EncodedFormat.jpeg);
    expect(result.processingTime, greaterThan(Duration.zero));
  });
}
