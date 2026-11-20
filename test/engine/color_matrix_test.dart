import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/engine.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _px(List<int> rgba) => Uint8List.fromList(rgba);

void main() {
  group('ColorMatrix', () {
    test('identity leaves pixels unchanged', () {
      final px = _px([10, 20, 30, 255, 200, 100, 0, 128]);
      ColorMatrix.identity.applyToRgba(px);
      expect(px, [10, 20, 30, 255, 200, 100, 0, 128]);
      expect(ColorMatrix.identity.isIdentity, isTrue);
    });

    test('rejects a wrong number of values', () {
      expect(() => ColorMatrix(List.filled(19, 0)), throwsArgumentError);
    });

    test('brightness offset is in 0..255 space like Flutter ColorFilter', () {
      final px = _px([100, 100, 100, 255]);
      ColorMatrix.brightness(0.2).applyToRgba(px);
      expect(px.sublist(0, 3), [151, 151, 151]);
      expect(ColorMatrix.brightness(0.2).values[4], closeTo(51, 1e-9));
    });

    test('contrast pivots around mid-grey', () {
      final px = _px([127, 127, 127, 255, 200, 200, 200, 255]);
      ColorMatrix.contrast(2).applyToRgba(px);
      expect(px[0], 127);
      expect(px[4], 255);
    });

    test('saturation 0 equals full grayscale', () {
      final a = _px([200, 40, 90, 255]);
      final b = _px([200, 40, 90, 255]);
      ColorMatrix.saturation(0).applyToRgba(a);
      ColorMatrix.grayscale().applyToRgba(b);
      expect(a, b);
      expect(a[0], a[1]);
      expect(a[1], a[2]);
    });

    test('invert twice is identity', () {
      final m = ColorMatrix.invert().then(ColorMatrix.invert());
      expect(m.isIdentity, isTrue);
    });

    test('then() equals applying matrices in sequence', () {
      // Mid-range values, so no step clips. (Fused matrices skip the
      // intermediate clipping a sequence would do, exactly like the GPU.)
      final a = ColorMatrix.contrast(1.1);
      final b = ColorMatrix.hueRotate(20);
      final c = ColorMatrix.sepia(0.3);
      final sequential = _px([150, 100, 90, 255, 90, 140, 120, 255]);
      a.applyToRgba(sequential);
      b.applyToRgba(sequential);
      c.applyToRgba(sequential);
      final fused = _px([150, 100, 90, 255, 90, 140, 120, 255]);
      a.then(b).then(c).applyToRgba(fused);
      for (var i = 0; i < fused.length; i++) {
        // Sequential rounding vs one fused pass may differ by a level or two.
        expect((fused[i] - sequential[i]).abs(), lessThanOrEqualTo(2));
      }
    });

    test('alpha is untouched unless the matrix addresses it', () {
      final px = _px([10, 20, 30, 77]);
      ColorMatrix.sepia().applyToRgba(px);
      expect(px[3], 77);
    });

    test('withStrength(0) is identity and withStrength(1) is the matrix', () {
      final m = ColorMatrix.saturation(1.6);
      expect(m.withStrength(0).isIdentity, isTrue);
      expect(m.withStrength(1), m);
    });

    test('JSON round-trip', () {
      final m = ColorMatrix.temperature(0.4).then(ColorMatrix.tint(-0.2));
      expect(ColorMatrix.fromJson(m.toJson()), m);
      expect(ColorMatrix.fromJson(m.toJson()).hashCode, m.hashCode);
    });

    test('values are immutable', () {
      expect(() => ColorMatrix.identity.values[0] = 2, throwsUnsupportedError);
    });
  });
}
