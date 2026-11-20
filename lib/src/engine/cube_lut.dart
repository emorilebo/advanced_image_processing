import 'dart:convert';
import 'dart:typed_data';

/// A colour look-up table in the Adobe/Resolve `.cube` format.
///
/// `.cube` is the interchange format colourists export from DaVinci Resolve,
/// Premiere, Photoshop and most grading tools, so this lets an app ship a
/// "film look" designed by a professional instead of a hand-tuned matrix.
///
/// Both 3D (`LUT_3D_SIZE`) and 1D (`LUT_1D_SIZE`) tables are supported. 3D
/// tables are sampled with trilinear interpolation.
final class CubeLut {
  CubeLut._({
    required this.size,
    required this.is3d,
    required Float32List table,
    this.title,
    List<double> domainMin = const [0, 0, 0],
    List<double> domainMax = const [1, 1, 1],
  }) : _table = table,
       domainMin = List<double>.unmodifiable(domainMin),
       domainMax = List<double>.unmodifiable(domainMax);

  /// Parses the text of a `.cube` file.
  ///
  /// Throws [FormatException] if the file is malformed or the number of
  /// table rows does not match the declared size.
  factory CubeLut.parse(String source) {
    String? title;
    int? size3d;
    int? size1d;
    var domainMin = const <double>[0, 0, 0];
    var domainMax = const <double>[1, 1, 1];
    final values = <double>[];

    final lines = const LineSplitter().convert(source);
    for (var lineNo = 0; lineNo < lines.length; lineNo++) {
      final line = lines[lineNo].trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      final keyword = parts.first.toUpperCase();
      switch (keyword) {
        case 'TITLE':
          final match = RegExp(r'"(.*)"').firstMatch(line);
          title = match?.group(1) ?? parts.skip(1).join(' ');
        case 'LUT_3D_SIZE':
          size3d = _parseSize(parts, lineNo, max: _max3dSize);
        case 'LUT_1D_SIZE':
          size1d = _parseSize(parts, lineNo, max: _max1dSize);
        case 'DOMAIN_MIN':
          domainMin = _parseTriple(parts.skip(1).toList(), lineNo);
        case 'DOMAIN_MAX':
          domainMax = _parseTriple(parts.skip(1).toList(), lineNo);
        case 'LUT_3D_INPUT_RANGE' || 'LUT_1D_INPUT_RANGE':
          if (parts.length != 3) {
            throw FormatException('Invalid input range on line ${lineNo + 1}');
          }
          final lo = _parseDouble(parts[1], lineNo);
          final hi = _parseDouble(parts[2], lineNo);
          domainMin = [lo, lo, lo];
          domainMax = [hi, hi, hi];
        default:
          if (parts.length != 3) {
            throw FormatException(
              'Unrecognised .cube line ${lineNo + 1}: "$line"',
            );
          }
          values.addAll(_parseTriple(parts, lineNo));
      }
    }

    if (size3d != null && size1d != null) {
      throw const FormatException(
        'A .cube file cannot declare both LUT_3D_SIZE and LUT_1D_SIZE',
      );
    }
    final is3d = size3d != null;
    final size = size3d ?? size1d;
    if (size == null) {
      throw const FormatException(
        'Missing LUT_3D_SIZE or LUT_1D_SIZE declaration',
      );
    }
    final expectedRows = is3d ? size * size * size : size;
    if (values.length != expectedRows * 3) {
      throw FormatException(
        'Expected $expectedRows table rows for size $size, '
        'found ${values.length ~/ 3}',
      );
    }
    return CubeLut._(
      size: size,
      is3d: is3d,
      table: Float32List.fromList(values),
      title: title,
      domainMin: domainMin,
      domainMax: domainMax,
    );
  }

  /// An identity 3D table of the given [size]: applying it changes nothing
  /// beyond rounding. Useful for tests and as a starting point.
  factory CubeLut.identity({int size = 17}) {
    if (size < 2) throw ArgumentError.value(size, 'size', 'must be >= 2');
    final table = Float32List(size * size * size * 3);
    var i = 0;
    for (var b = 0; b < size; b++) {
      for (var g = 0; g < size; g++) {
        for (var r = 0; r < size; r++) {
          table[i++] = r / (size - 1);
          table[i++] = g / (size - 1);
          table[i++] = b / (size - 1);
        }
      }
    }
    return CubeLut._(size: size, is3d: true, table: table, title: 'Identity');
  }

  /// Restores a table from [toJson] output.
  factory CubeLut.fromJson(Map<String, Object?> json) {
    final bytes = base64Decode(json['table']! as String);
    return CubeLut._(
      size: json['size']! as int,
      is3d: json['is3d']! as bool,
      table: Float32List.sublistView(Uint8List.fromList(bytes)),
      title: json['title'] as String?,
      domainMin: _doubles(json['domainMin'], fallback: const [0, 0, 0]),
      domainMax: _doubles(json['domainMax'], fallback: const [1, 1, 1]),
    );
  }

  /// Edge length of the table (e.g. 33 for a 33x33x33 cube).
  final int size;

  /// `true` for a 3D table, `false` for a per-channel 1D table.
  final bool is3d;

  /// The `TITLE` declared in the file, if any.
  final String? title;

  /// Input domain lower bound per channel (usually `0`).
  final List<double> domainMin;

  /// Input domain upper bound per channel (usually `1`).
  final List<double> domainMax;

  final Float32List _table;

  /// Applies the table in place to a tightly packed RGBA8888 buffer.
  ///
  /// [intensity] blends between the original (`0`) and the full look (`1`).
  void applyToRgba(Uint8List rgba, {double intensity = 1.0}) {
    final t = intensity.clamp(0.0, 1.0);
    if (t == 0) return;
    if (is3d) {
      _apply3d(rgba, t);
    } else {
      _apply1d(rgba, t);
    }
  }

  void _apply3d(Uint8List rgba, double t) {
    final n = size;
    final maxIndex = n - 1;
    final lut = _table;
    // Precompute per-channel lattice index and fraction for every 8-bit
    // input value. This moves all division out of the pixel loop.
    final idx = List<Int32List>.generate(3, (_) => Int32List(256));
    final frac = List<Float64List>.generate(3, (_) => Float64List(256));
    for (var c = 0; c < 3; c++) {
      final lo = domainMin[c];
      final span = domainMax[c] - lo;
      for (var v = 0; v < 256; v++) {
        var x = ((v / 255.0) - lo) / (span == 0 ? 1 : span) * maxIndex;
        if (x < 0) x = 0;
        if (x > maxIndex) x = maxIndex.toDouble();
        var i0 = x.floor();
        if (i0 >= maxIndex) i0 = maxIndex - 1;
        idx[c][v] = i0;
        frac[c][v] = x - i0;
      }
    }
    final rIdx = idx[0], gIdx = idx[1], bIdx = idx[2];
    final rFrac = frac[0], gFrac = frac[1], bFrac = frac[2];
    final strideG = n * 3;
    final strideB = n * n * 3;

    for (var p = 0; p < rgba.length; p += 4) {
      final r = rgba[p], g = rgba[p + 1], b = rgba[p + 2];
      final fr = rFrac[r], fg = gFrac[g], fb = bFrac[b];
      final base = rIdx[r] * 3 + gIdx[g] * strideG + bIdx[b] * strideB;
      for (var c = 0; c < 3; c++) {
        final o = base + c;
        final c000 = lut[o];
        final c100 = lut[o + 3];
        final c010 = lut[o + strideG];
        final c110 = lut[o + strideG + 3];
        final c001 = lut[o + strideB];
        final c101 = lut[o + strideB + 3];
        final c011 = lut[o + strideB + strideG];
        final c111 = lut[o + strideB + strideG + 3];
        final c00 = c000 + (c100 - c000) * fr;
        final c10 = c010 + (c110 - c010) * fr;
        final c01 = c001 + (c101 - c001) * fr;
        final c11 = c011 + (c111 - c011) * fr;
        final c0 = c00 + (c10 - c00) * fg;
        final c1 = c01 + (c11 - c01) * fg;
        final mapped = (c0 + (c1 - c0) * fb) * 255.0;
        final src = rgba[p + c];
        rgba[p + c] = _clamp8(src + (mapped - src) * t);
      }
    }
  }

  void _apply1d(Uint8List rgba, double t) {
    final maxIndex = size - 1;
    final tables = List<Uint8List>.generate(3, (_) => Uint8List(256));
    for (var c = 0; c < 3; c++) {
      final lo = domainMin[c];
      final span = domainMax[c] - lo;
      for (var v = 0; v < 256; v++) {
        var x = ((v / 255.0) - lo) / (span == 0 ? 1 : span) * maxIndex;
        if (x < 0) x = 0;
        if (x > maxIndex) x = maxIndex.toDouble();
        var i0 = x.floor();
        if (i0 >= maxIndex) i0 = maxIndex - 1;
        final f = x - i0;
        final a = _table[i0 * 3 + c];
        final b = _table[(i0 + 1) * 3 + c];
        final mapped = (a + (b - a) * f) * 255.0;
        tables[c][v] = _clamp8(v + (mapped - v) * t);
      }
    }
    final tr = tables[0], tg = tables[1], tb = tables[2];
    for (var p = 0; p < rgba.length; p += 4) {
      rgba[p] = tr[rgba[p]];
      rgba[p + 1] = tg[rgba[p + 1]];
      rgba[p + 2] = tb[rgba[p + 2]];
    }
  }

  /// Serialises the table (base64 float32) so a pipeline holding it can be
  /// saved as a recipe.
  Map<String, Object?> toJson() => {
    'size': size,
    'is3d': is3d,
    if (title != null) 'title': title,
    'domainMin': domainMin,
    'domainMax': domainMax,
    'table': base64Encode(
      _table.buffer.asUint8List(_table.offsetInBytes, _table.lengthInBytes),
    ),
  };

  @override
  String toString() =>
      'CubeLut(${title ?? 'untitled'}, ${is3d ? '3D' : '1D'} size $size)';

  // Largest sizes accepted. Real-world cubes are 17, 33 or 65; the caps stop
  // a hostile file from forcing a multi-hundred-megabyte allocation.
  static const int _max3dSize = 129;
  static const int _max1dSize = 65536;

  static int _parseSize(List<String> parts, int lineNo, {required int max}) {
    final size = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (size == null || size < 2 || size > max) {
      throw FormatException('Invalid LUT size on line ${lineNo + 1}');
    }
    return size;
  }

  static List<double> _parseTriple(List<String> parts, int lineNo) {
    if (parts.length != 3) {
      throw FormatException('Expected 3 values on line ${lineNo + 1}');
    }
    return parts.map((p) => _parseDouble(p, lineNo)).toList();
  }

  static double _parseDouble(String s, int lineNo) {
    final v = double.tryParse(s);
    if (v == null || v.isNaN || v.isInfinite) {
      throw FormatException('Invalid number "$s" on line ${lineNo + 1}');
    }
    return v;
  }

  static List<double> _doubles(
    Object? json, {
    required List<double> fallback,
  }) => json == null
      ? fallback
      : (json as List<Object?>).map((v) => (v! as num).toDouble()).toList();
}

int _clamp8(double v) {
  if (v <= 0) return 0;
  if (v >= 255) return 255;
  return (v + 0.5).toInt();
}
