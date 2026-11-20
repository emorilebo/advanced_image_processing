import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _invert2 = '''
# A 2x2x2 cube that inverts colours.
TITLE "Invert"
LUT_3D_SIZE 2
DOMAIN_MIN 0.0 0.0 0.0
DOMAIN_MAX 1.0 1.0 1.0
1 1 1
0 1 1
1 0 1
0 0 1
1 1 0
0 1 0
1 0 0
0 0 0
''';

void main() {
  group('CubeLut.parse', () {
    test('reads header and table', () {
      final lut = CubeLut.parse(_invert2);
      expect(lut.title, 'Invert');
      expect(lut.size, 2);
      expect(lut.is3d, isTrue);
      expect(lut.domainMax, [1, 1, 1]);
    });

    test('3D invert table inverts pixels with trilinear interpolation', () {
      final px = Uint8List.fromList([0, 128, 255, 255, 40, 200, 90, 10]);
      CubeLut.parse(_invert2).applyToRgba(px);
      expect(px, [255, 127, 0, 255, 215, 55, 165, 10]);
    });

    test('intensity blends with the original', () {
      final px = Uint8List.fromList([0, 0, 0, 255]);
      CubeLut.parse(_invert2).applyToRgba(px, intensity: 0.5);
      expect(px.sublist(0, 3), [128, 128, 128]);
      final untouched = Uint8List.fromList([12, 34, 56, 255]);
      CubeLut.parse(_invert2).applyToRgba(untouched, intensity: 0);
      expect(untouched, [12, 34, 56, 255]);
    });

    test('identity cube changes nothing beyond rounding', () {
      final px = Uint8List.fromList(
        List.generate(256 * 4, (i) => i % 4 == 3 ? 255 : (i ~/ 4) % 256),
      );
      final before = Uint8List.fromList(px);
      CubeLut.identity(size: 33).applyToRgba(px);
      for (var i = 0; i < px.length; i++) {
        expect((px[i] - before[i]).abs(), lessThanOrEqualTo(1));
      }
    });

    test('1D tables map channels independently', () {
      const src = 'LUT_1D_SIZE 2\n0 0 0\n1 0.5 1\n';
      final lut = CubeLut.parse(src);
      expect(lut.is3d, isFalse);
      final px = Uint8List.fromList([255, 255, 128, 255]);
      lut.applyToRgba(px);
      expect(px.sublist(0, 3), [255, 128, 128]);
    });

    test('rejects malformed files', () {
      expect(() => CubeLut.parse('1 2 3'), throwsFormatException);
      expect(
        () => CubeLut.parse('LUT_3D_SIZE 2\n0 0 0\n'),
        throwsFormatException,
      );
      expect(
        () => CubeLut.parse('LUT_3D_SIZE 2\nLUT_1D_SIZE 2\n'),
        throwsFormatException,
      );
      expect(
        () => CubeLut.parse('LUT_3D_SIZE 2\n0 0 x\n'),
        throwsFormatException,
      );
      expect(() => CubeLut.parse('LUT_3D_SIZE 1\n'), throwsFormatException);
    });

    test('refuses absurd sizes before allocating', () {
      expect(() => CubeLut.parse('LUT_3D_SIZE 4096\n'), throwsFormatException);
    });

    test('JSON round-trip preserves behaviour', () {
      final lut = CubeLut.parse(_invert2);
      final restored = CubeLut.fromJson(lut.toJson());
      final a = Uint8List.fromList([30, 60, 90, 255]);
      final b = Uint8List.fromList([30, 60, 90, 255]);
      lut.applyToRgba(a);
      restored.applyToRgba(b);
      expect(a, b);
      expect(restored.title, 'Invert');
    });
  });
}
