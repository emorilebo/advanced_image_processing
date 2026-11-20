import 'dart:math' as math;
import 'dart:typed_data';

/// A 4x5 colour matrix, the same model Flutter's `ColorFilter.matrix` uses.
///
/// Rows are R, G, B, A. Each row is `[r, g, b, a, offset]`, and the offset
/// column is in unnormalised `0..255` space, exactly like Flutter's. That
/// shared convention is what makes previews honest: the matrix you show live
/// with `ColorFiltered` is the matrix the pipeline applies on export.
///
/// Matrices compose with [then]. Consecutive colour operations in an
/// `ImagePipeline` are fused into one matrix, so ten colour tweaks cost one
/// pass over the pixels instead of ten.
final class ColorMatrix {
  /// Creates a matrix from 20 row-major values.
  ColorMatrix(List<double> values)
    : _m = List<double>.unmodifiable(_checked(values));

  const ColorMatrix._(this._m);

  /// The matrix that changes nothing.
  static const ColorMatrix identity = ColorMatrix._(<double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  // Rec. 709 luma weights.
  static const double _lr = 0.2126;
  static const double _lg = 0.7152;
  static const double _lb = 0.0722;

  final List<double> _m;

  /// The 20 row-major values. Pass these straight to `ColorFilter.matrix`.
  List<double> get values => _m;

  /// Whether this matrix leaves every pixel unchanged.
  bool get isIdentity => this == identity;

  /// Shifts brightness by [amount] in `-1.0..1.0` (`0` is neutral).
  factory ColorMatrix.brightness(double amount) {
    final o = 255.0 * amount;
    return ColorMatrix._rgbScaleOffset(1, 1, 1, o, o, o);
  }

  /// Scales contrast around mid-grey. `1.0` is neutral, `0` is flat grey.
  factory ColorMatrix.contrast(double factor) {
    final o = 127.5 * (1 - factor);
    return ColorMatrix._rgbScaleOffset(factor, factor, factor, o, o, o);
  }

  /// Scales saturation, preserving Rec. 709 luminance. `1.0` is neutral,
  /// `0` is greyscale, values above `1` boost colour.
  factory ColorMatrix.saturation(double factor) {
    final s = factor;
    final r = (1 - s) * _lr;
    final g = (1 - s) * _lg;
    final b = (1 - s) * _lb;
    return ColorMatrix._(
      List<double>.unmodifiable(<double>[
        r + s, g, b, 0, 0, //
        r, g + s, b, 0, 0, //
        r, g, b + s, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  /// Rotates hue by [degrees] (luminance-preserving, as in SVG `hueRotate`).
  factory ColorMatrix.hueRotate(double degrees) {
    final rad = degrees * math.pi / 180;
    final c = math.cos(rad);
    final s = math.sin(rad);
    return ColorMatrix._(
      List<double>.unmodifiable(<double>[
        0.213 + c * 0.787 - s * 0.213,
        0.715 - c * 0.715 - s * 0.715,
        0.072 - c * 0.072 + s * 0.928,
        0, 0, //
        0.213 - c * 0.213 + s * 0.143,
        0.715 + c * 0.285 + s * 0.140,
        0.072 - c * 0.072 - s * 0.283,
        0, 0, //
        0.213 - c * 0.213 - s * 0.787,
        0.715 - c * 0.715 + s * 0.715,
        0.072 + c * 0.928 + s * 0.072,
        0, 0, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  /// Desaturates towards Rec. 709 luminance. [amount] `1.0` is full greyscale.
  factory ColorMatrix.grayscale([double amount = 1.0]) {
    final a = 1 - amount.clamp(0.0, 1.0);
    return ColorMatrix._(
      List<double>.unmodifiable(<double>[
        _lr + (1 - _lr) * a, _lg - _lg * a, _lb - _lb * a, 0, 0, //
        _lr - _lr * a, _lg + (1 - _lg) * a, _lb - _lb * a, 0, 0, //
        _lr - _lr * a, _lg - _lg * a, _lb + (1 - _lb) * a, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  /// Sepia tone (CSS filter definition). [amount] `1.0` is full sepia.
  factory ColorMatrix.sepia([double amount = 1.0]) {
    final a = 1 - amount.clamp(0.0, 1.0);
    return ColorMatrix._(
      List<double>.unmodifiable(<double>[
        0.393 + 0.607 * a, 0.769 - 0.769 * a, 0.189 - 0.189 * a, 0, 0, //
        0.349 - 0.349 * a, 0.686 + 0.314 * a, 0.168 - 0.168 * a, 0, 0, //
        0.272 - 0.272 * a, 0.534 - 0.534 * a, 0.131 + 0.869 * a, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  /// Inverts the colour channels (alpha is untouched).
  factory ColorMatrix.invert() =>
      ColorMatrix._rgbScaleOffset(-1, -1, -1, 255, 255, 255);

  /// Warms (positive) or cools (negative) white balance. Range `-1.0..1.0`.
  factory ColorMatrix.temperature(double amount) {
    final t = amount.clamp(-1.0, 1.0);
    return ColorMatrix._rgbScaleOffset(
      1 + 0.15 * t,
      1 + 0.02 * t,
      1 - 0.15 * t,
      0,
      0,
      0,
    );
  }

  /// Shifts tint towards magenta (positive) or green (negative). Range
  /// `-1.0..1.0`.
  factory ColorMatrix.tint(double amount) {
    final t = amount.clamp(-1.0, 1.0);
    return ColorMatrix._rgbScaleOffset(
      1 + 0.04 * t,
      1 - 0.15 * t,
      1 + 0.04 * t,
      0,
      0,
      0,
    );
  }

  /// Multiplies each channel by a gain, e.g. for white balance.
  factory ColorMatrix.channelGains(double red, double green, double blue) =>
      ColorMatrix._rgbScaleOffset(red, green, blue, 0, 0, 0);

  factory ColorMatrix._rgbScaleOffset(
    double sr,
    double sg,
    double sb,
    double or,
    double og,
    double ob,
  ) {
    return ColorMatrix._(
      List<double>.unmodifiable(<double>[
        sr, 0, 0, 0, or, //
        0, sg, 0, 0, og, //
        0, 0, sb, 0, ob, //
        0, 0, 0, 1, 0, //
      ]),
    );
  }

  /// Restores a matrix from [toJson] output.
  factory ColorMatrix.fromJson(List<Object?> json) =>
      ColorMatrix(json.map((v) => (v! as num).toDouble()).toList());

  /// Returns the matrix that applies `this` first and then [next].
  ColorMatrix then(ColorMatrix next) {
    final a = _m;
    final b = next._m;
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      final r = row * 5;
      for (var col = 0; col < 5; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += b[r + k] * a[k * 5 + col];
        }
        out[r + col] = col == 4 ? sum + b[r + 4] : sum;
      }
    }
    return ColorMatrix._(List<double>.unmodifiable(out));
  }

  /// Blends between [identity] (`t = 0`) and this matrix (`t = 1`).
  ColorMatrix withStrength(double t) => lerp(identity, this, t);

  /// Linearly interpolates two matrices.
  static ColorMatrix lerp(ColorMatrix a, ColorMatrix b, double t) {
    final out = List<double>.generate(
      20,
      (i) => a._m[i] + (b._m[i] - a._m[i]) * t,
    );
    return ColorMatrix._(List<double>.unmodifiable(out));
  }

  /// Applies the matrix in place to a tightly packed RGBA8888 buffer.
  void applyToRgba(Uint8List rgba) {
    final m = _m;
    final m0 = m[0], m1 = m[1], m2 = m[2], m3 = m[3], m4 = m[4];
    final m5 = m[5], m6 = m[6], m7 = m[7], m8 = m[8], m9 = m[9];
    final m10 = m[10], m11 = m[11], m12 = m[12], m13 = m[13], m14 = m[14];
    final m15 = m[15], m16 = m[16], m17 = m[17], m18 = m[18], m19 = m[19];
    final touchesAlpha =
        m15 != 0 || m16 != 0 || m17 != 0 || m18 != 1 || m19 != 0;
    final n = rgba.length;
    for (var i = 0; i < n; i += 4) {
      final r = rgba[i].toDouble();
      final g = rgba[i + 1].toDouble();
      final b = rgba[i + 2].toDouble();
      final a = rgba[i + 3].toDouble();
      rgba[i] = _clamp8(m0 * r + m1 * g + m2 * b + m3 * a + m4);
      rgba[i + 1] = _clamp8(m5 * r + m6 * g + m7 * b + m8 * a + m9);
      rgba[i + 2] = _clamp8(m10 * r + m11 * g + m12 * b + m13 * a + m14);
      if (touchesAlpha) {
        rgba[i + 3] = _clamp8(m15 * r + m16 * g + m17 * b + m18 * a + m19);
      }
    }
  }

  /// Serialises to a plain list of 20 numbers.
  List<double> toJson() => List<double>.of(_m);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ColorMatrix) return false;
    for (var i = 0; i < 20; i++) {
      if ((_m[i] - other._m[i]).abs() > 1e-9) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_m.map((v) => (v * 1e6).round()));

  @override
  String toString() => 'ColorMatrix($_m)';

  static List<double> _checked(List<double> values) {
    if (values.length != 20) {
      throw ArgumentError.value(
        values.length,
        'values.length',
        'A colour matrix needs exactly 20 values (4 rows x 5 columns)',
      );
    }
    return values;
  }
}

int _clamp8(double v) {
  if (v <= 0) return 0;
  if (v >= 255) return 255;
  return (v + 0.5).toInt();
}
