import 'dart:ui';

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  group('FilterPreset', () {
    test('ids are unique and resolvable', () {
      final ids = FilterPreset.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(FilterPreset.all, hasLength(12));
      for (final id in ids) {
        expect(FilterPreset.byId(id)?.id, id);
      }
      expect(FilterPreset.byId('nope'), isNull);
    });

    test('colour-only presets preview exactly what they export', () {
      expect(
        FilterPreset.vivid.pipeline.previewMatrix,
        FilterPreset.vivid.matrix,
      );
      // Vignette makes the full pipeline non-previewable on the GPU.
      expect(FilterPreset.noir.pipeline.previewMatrix, isNull);
      expect(FilterPreset.noir.toColorFilter(), isA<ColorFilter>());
    });

    test('every preset renders', () async {
      final input = solid(24, 16);
      for (final p in FilterPreset.all) {
        final out = decode(await p.apply(input));
        expect((out.width, out.height), (24, 16), reason: p.id);
      }
    });
  });

  group('DetectedObject', () {
    const face = DetectedObject(
      label: 'Face',
      confidence: 1,
      boundingBox: Rect.fromLTWH(10, 20, 30, 40),
      type: DetectorType.face,
      additionalData: {'smilingProbability': 0.9},
    );

    test('map round-trip', () {
      final restored = DetectedObject.fromMap(face.toMap());
      expect(restored.label, 'Face');
      expect(restored.type, DetectorType.face);
      expect(restored.boundingBox, face.boundingBox);
      expect(restored.additionalData?['smilingProbability'], 0.9);
    });

    test('maps written by 0.2.x (no type) still load', () {
      final legacy = face.toMap()..remove('type');
      expect(DetectedObject.fromMap(legacy).type, isNull);
    });

    test('region converts to the engine rectangle', () {
      final r = face.region;
      expect([r.left, r.top, r.width, r.height], [10, 20, 30, 40]);
    });

    test('DetectorType.all covers every detector', () {
      expect(DetectorType.all, DetectorType.values.toSet());
    });
  });
}
