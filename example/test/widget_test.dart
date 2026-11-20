import 'dart:async';
import 'dart:convert';

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:advanced_image_processing_toolkit_example/main.dart';
import 'package:advanced_image_processing_toolkit_example/src/state/studio_services.dart';
import 'package:advanced_image_processing_toolkit_example/src/widgets/recipe_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ioAAAAASUVORK5CYII=');

class FakeServices extends StudioServices {
  bool nativeDetection = false;
  bool nativeExport = true;
  bool failLoad = false;
  bool failPick = false;
  bool failProcess = false;
  bool failSave = false;
  bool failPlatform = false;
  int width = 1600;
  int height = 1067;
  int redactions = 0;
  int saves = 0;
  PickedPhoto? picked;
  Completer<PipelineResult>? pending;
  final recipes = <ImagePipeline>[];
  Set<DetectorType>? receivedTargets;
  RedactionStyle? receivedStyle;

  @override
  bool get detectionSupported => nativeDetection;
  @override
  bool get exportSupported => nativeExport;
  @override
  bool get runsInBackground => nativeExport;
  @override
  Future<String> platformVersion() async {
    if (failPlatform) throw StateError('platform unavailable');
    return 'Test device 1.0';
  }

  @override
  Future<Uint8List> loadAsset(String path) async {
    if (failLoad) throw StateError('asset unavailable');
    return _pixel;
  }

  @override
  Future<PickedPhoto?> pickPhoto() async {
    if (failPick) throw StateError('picker unavailable');
    return picked;
  }

  PipelineResult output() => PipelineResult(
      bytes: _pixel,
      width: width,
      height: height,
      format: EncodedFormat.jpeg,
      processingTime: const Duration(milliseconds: 186));

  @override
  Future<PipelineResult> process(
      ImagePipeline pipeline, Uint8List bytes) async {
    recipes.add(pipeline);
    if (failProcess) throw StateError('decode failed');
    return pending == null ? output() : pending!.future;
  }

  @override
  Future<RedactionResult> redact(
      Uint8List bytes, Set<DetectorType> targets, RedactionStyle style) async {
    redactions++;
    receivedTargets = targets;
    receivedStyle = style;
    return RedactionResult(
        bytes: _pixel,
        width: width,
        height: height,
        regions: [
          for (var i = 0; i < 3; i++)
            DetectedObject(
                type: DetectorType.face,
                label: 'Face',
                confidence: 1,
                boundingBox: Rect.fromLTWH(100.0 + i * 300, 100, 100, 150)),
          const DetectedObject(
              type: DetectorType.text,
              label: 'Text',
              confidence: 1,
              boundingBox: Rect.fromLTWH(100, 10, 200, 50)),
        ]);
  }

  @override
  Future<String> save(Uint8List bytes, String prefix) async {
    if (failSave) throw StateError('disk full');
    saves++;
    return '$prefix-test.jpg';
  }
}

Future<void> launch(WidgetTester tester, FakeServices services,
    {Size size = const Size(390, 844),
    ThemeMode theme = ThemeMode.dark,
    double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(ToolkitStudio(services: services, themeMode: theme));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets(
      'phone opens a live canvas and edits on the GPU without rendering',
      (tester) async {
    final services = FakeServices();
    await launch(tester, services);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Find your light.'), findsOneWidget);
    expect(find.byType(ImageCompareSlider), findsNothing);
    expect(services.recipes.single.steps, ['downscale(max 2048 px)']);

    final preview = find.byKey(const ValueKey('live-colour-preview'));
    final originalFilter = tester.widget<ColorFiltered>(preview).colorFilter;
    await tapVisible(tester, find.byKey(const ValueKey('preset-vivid')));
    expect(tester.widget<ColorFiltered>(preview).colorFilter,
        isNot(originalFilter));
    expect(services.recipes, hasLength(1));

    final brightness = find.byKey(const ValueKey('slider-brightness'));
    await tester.ensureVisible(brightness);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(brightness) + const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(brightness).value, greaterThan(0));
    expect(services.recipes, hasLength(1));
    expect(services.redactions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop renders effects, compares, copies a recipe and exports',
      (tester) async {
    final services = FakeServices();
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await launch(tester, services, size: const Size(1600, 1000));
    expect(find.byType(NavigationRail), findsOneWidget);
    await tapVisible(tester, find.text('Effects'));
    await tapVisible(tester, find.text('Vignette'));
    expect(services.recipes, hasLength(1));
    await tapVisible(tester, find.byKey(const ValueKey('render-button')));
    expect(find.byType(ImageCompareSlider), findsOneWidget);
    expect(find.textContaining('186 ms · background isolate'), findsOneWidget);
    expect(services.recipes.last.steps.join(' '), contains('vignette'));
    await tester.drag(find.byType(ImageCompareSlider), const Offset(130, 0));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Show result only'));
    expect(find.byType(ImageCompareSlider), findsNothing);
    await tapVisible(tester, find.byTooltip('Compare before and after'));
    await tapVisible(tester, find.text('Recipe'));
    expect(find.byType(RecipeSheet), findsOneWidget);
    await tapVisible(tester, find.text('Copy JSON'));
    expect(copied, isNotNull);
    final restored = ImagePipeline.fromJson(
        (jsonDecode(copied!) as Map).cast<String, Object?>());
    expect(restored.steps, services.recipes.last.steps);
    await tapVisible(tester, find.byTooltip('Close recipe'));
    await tapVisible(tester, find.text('Export'));
    expect(services.saves, 1);
    expect(find.text('Saved toolkit-studio-test.jpg to app documents.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'render progress locks edits and stale results cannot be exported',
      (tester) async {
    final services = FakeServices();
    await launch(tester, services, size: const Size(1600, 1000));
    services.pending = Completer<PipelineResult>();
    await tester.tap(find.byKey(const ValueKey('render-button')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Rendering your look…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('render-button')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('slider-brightness')))
            .onChanged,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Pick photo'))
            .onPressed,
        isNull);
    services.pending!.complete(services.output());
    services.pending = null;
    await tester.pumpAndSettle();
    expect(find.byType(ImageCompareSlider), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('preset-vivid')));
    expect(find.byType(ImageCompareSlider), findsNothing);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Export'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'privacy controls select targets, redact, show detections and export',
      (tester) async {
    final services = FakeServices()..nativeDetection = true;
    await launch(tester, services, size: const Size(1600, 1000));
    await tapVisible(tester, find.text('Privacy'));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Text'));
    expect(find.text('Pixelated text can be recovered; use Solid fill.'),
        findsOneWidget);
    await tapVisible(tester, find.text('Solid fill'));
    expect(find.text('Pixelated text can be recovered; use Solid fill.'),
        findsNothing);
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Faces'));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Text'));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('redact-button')))
            .onPressed,
        isNull);
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Faces'));
    await tapVisible(tester, find.widgetWithText(FilterChip, 'Text'));
    await tapVisible(tester, find.text('Redact'));
    expect(services.receivedTargets, {DetectorType.face, DetectorType.text});
    expect(services.receivedStyle, RedactionStyle.fill);
    expect(find.text('3 faces, 1 text block hidden'), findsNWidgets(2));
    expect(find.byType(ImageCompareSlider), findsOneWidget);
    await tapVisible(tester, find.text('Detections'));
    expect(
        tester
            .widget<DetectionOverlay>(find.byType(DetectionOverlay))
            .detections,
        hasLength(4));
    await tapVisible(tester, find.text('Export'));
    expect(services.saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unsupported detection offers a real manual recipe and disables export',
      (tester) async {
    final services = FakeServices()..nativeExport = false;
    await launch(tester, services);
    await tapVisible(tester, find.text('Privacy'));
    expect(find.textContaining('runs on Android and iOS'), findsOneWidget);
    await tapVisible(tester, find.text('Try manual redaction'));
    expect(services.redactions, 0);
    expect(
        services.recipes.last.toJson()['ops'].toString(), contains('redact'));
    expect(find.text('1 demo region pixelated · no automatic detection'),
        findsNWidgets(2));
    expect(find.byType(ImageCompareSlider), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Export'))
            .onPressed,
        isNull);
    expect(
        find.byTooltip(
            'File export is available in the mobile and desktop app.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load, picker, render and export failures are recoverable',
      (tester) async {
    final services = FakeServices()..failLoad = true;
    await launch(tester, services, size: const Size(1600, 1000));
    expect(find.text('Open sample'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    services.failLoad = false;
    await tapVisible(tester, find.text('Open sample'));
    expect(find.byKey(const ValueKey('live-colour-preview')), findsOneWidget);
    services.failPick = true;
    await tapVisible(tester, find.text('Pick photo'));
    expect(
        find.textContaining('We could not open that photo.'), findsOneWidget);
    services.failProcess = true;
    await tapVisible(tester, find.text('Render'));
    expect(find.textContaining('This render did not finish.'), findsOneWidget);
    services.failProcess = false;
    await tapVisible(tester, find.text('Render'));
    services.failSave = true;
    await tapVisible(tester, find.text('Export'));
    expect(
        find.textContaining('The photo could not be saved.'), findsOneWidget);
    expect(find.byType(ImageCompareSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cancelled picking preserves edits and navigation retains the photo',
      (tester) async {
    final services = FakeServices();
    await launch(tester, services, size: const Size(1600, 1000));
    await tapVisible(tester, find.byKey(const ValueKey('preset-vivid')));
    final filter = tester
        .widget<ColorFiltered>(
            find.byKey(const ValueKey('live-colour-preview')))
        .colorFilter;
    await tapVisible(tester, find.text('Pick photo'));
    expect(services.recipes, hasLength(1));
    await tapVisible(tester, find.text('About'));
    expect(find.text('0.3.0'), findsOneWidget);
    expect(find.text('Test device 1.0'), findsOneWidget);
    await tapVisible(tester, find.text('Studio'));
    expect(
        tester
            .widget<ColorFiltered>(
                find.byKey(const ValueKey('live-colour-preview')))
            .colorFilter,
        filter);
    expect(services.recipes, hasLength(1));
  });

  for (final size in [
    const Size(390, 844),
    const Size(1600, 1000),
    const Size(900, 650)
  ]) {
    for (final dimensions in [(200, 2000), (2000, 100), (8, 8)]) {
      testWidgets(
          'contains ${dimensions.$1}×${dimensions.$2} at $size in light theme',
          (tester) async {
        final services = FakeServices()
          ..width = dimensions.$1
          ..height = dimensions.$2;
        await launch(tester, services, size: size, theme: ThemeMode.light);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.text('Render'));
        expect(find.byType(ImageCompareSlider), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('large text and unavailable platform information stay readable',
      (tester) async {
    final services = FakeServices()..failPlatform = true;
    await launch(tester, services, textScale: 1.5);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('About'));
    expect(find.text('Unavailable on this device'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
