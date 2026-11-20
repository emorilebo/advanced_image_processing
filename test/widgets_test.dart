import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 400, height: 200, child: child)),
);

void main() {
  group('ImageCompareSlider', () {
    testWidgets('shows both sides and follows taps and drags', (tester) async {
      final positions = <double>[];
      await tester.pumpWidget(
        _host(
          ImageCompareSlider(
            before: const ColoredBox(
              color: Color(0xFFFF0000),
              key: Key('before'),
            ),
            after: const ColoredBox(
              color: Color(0xFF0000FF),
              key: Key('after'),
            ),
            onChanged: positions.add,
          ),
        ),
      );
      expect(find.byKey(const Key('before')), findsOneWidget);
      expect(find.byKey(const Key('after')), findsOneWidget);

      final box = tester.getRect(find.byType(ImageCompareSlider));
      await tester.tapAt(box.centerLeft + const Offset(100, 0));
      expect(positions.last, closeTo(0.25, 0.01));

      await tester.dragFrom(box.center, const Offset(80, 0));
      expect(positions.last, closeTo(0.7, 0.02));
    });

    testWidgets('is exposed to assistive technology as adjustable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ImageCompareSlider(
            before: SizedBox.expand(),
            after: SizedBox.expand(),
            initialPosition: 0.4,
          ),
        ),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Before and after comparison'),
      );
      expect(node.value, '40%');
      expect(node.label, 'Before and after comparison');
      handle.dispose();
    });
  });

  group('DetectionOverlay', () {
    test('mapRect honours BoxFit.contain letterboxing', () {
      // 200x100 image in a 400x400 box: scaled x2, centred vertically.
      final r = DetectionOverlay.mapRect(
        const Rect.fromLTWH(50, 25, 100, 50),
        imageSize: const Size(200, 100),
        widgetSize: const Size(400, 400),
      );
      expect(r, const Rect.fromLTWH(100, 150, 200, 100));
    });

    test('mapRect honours BoxFit.cover cropping', () {
      // 200x100 image covering a 100x100 box: scaled /1, centre 100 px shown.
      final r = DetectionOverlay.mapRect(
        const Rect.fromLTWH(50, 0, 100, 100),
        imageSize: const Size(200, 100),
        widgetSize: const Size(100, 100),
        fit: BoxFit.cover,
      );
      expect(r, const Rect.fromLTWH(0, 0, 100, 100));
    });

    testWidgets('paints over its child without errors', (tester) async {
      await tester.pumpWidget(
        _host(
          const DetectionOverlay(
            imageSize: Size(400, 200),
            detections: [
              DetectedObject(
                label: 'Text',
                confidence: 1,
                boundingBox: Rect.fromLTWH(10, 10, 120, 30),
                type: DetectorType.text,
                additionalData: {'text': 'A long line of recognised text'},
              ),
              DetectedObject(
                label: 'Face',
                confidence: 1,
                boundingBox: Rect.fromLTWH(300, 100, 60, 60),
                type: DetectorType.face,
              ),
            ],
            child: ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('default labels describe each detector', () {
      const text = DetectedObject(
        label: 'Text',
        confidence: 1,
        boundingBox: Rect.zero,
        type: DetectorType.text,
        additionalData: {'text': 'Hello\nworld'},
      );
      const object = DetectedObject(
        label: 'Plant',
        confidence: 0.87,
        boundingBox: Rect.zero,
        type: DetectorType.object,
      );
      expect(DetectionOverlay.defaultLabelFor(text), 'Hello world');
      expect(DetectionOverlay.defaultLabelFor(object), 'Plant 87%');
    });
  });
}
