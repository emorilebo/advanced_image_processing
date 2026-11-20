// Pipeline operations. Internal: users compose these through the fluent
// `ImagePipeline` API, and they round-trip through JSON for saved recipes.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'codec_guard.dart';
import 'color_matrix.dart';
import 'cube_lut.dart';
import 'errors.dart';
import 'kernels.dart' as k;
import 'options.dart';

/// Returns [image] as tightly packed 8-bit RGBA, converting only if needed.
img.Image ensureRgba8(img.Image image) {
  if (image.format == img.Format.uint8 &&
      image.numChannels == 4 &&
      !image.hasPalette &&
      image.toUint8List().length == image.width * image.height * 4) {
    return image;
  }
  return image.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
}

/// One step in a pipeline. Receives and returns 8-bit RGBA images.
sealed class ImageOp {
  const ImageOp();

  /// Stable identifier used in JSON.
  String get type;

  /// Short human-readable description, e.g. `contrast(1.2)`.
  String describe();

  /// Whether [toJson] can represent this op.
  bool get isSerializable => true;

  Map<String, Object?> toJson();

  /// Applies the op. May mutate [image] in place or return a new image.
  img.Image apply(img.Image image);

  static ImageOp fromJson(Map<String, Object?> json) {
    final type = json['type'];
    double d(String key) => (json[key]! as num).toDouble();
    int i(String key) => (json[key]! as num).toInt();
    return switch (type) {
      'colorMatrix' => ColorMatrixOp(
        ColorMatrix.fromJson(json['matrix']! as List<Object?>),
        json['label'] as String? ?? 'colorMatrix',
      ),
      'gamma' => GammaOp(d('gamma')),
      'exposure' => ExposureOp(d('stops')),
      'levels' => LevelsOp(i('black'), i('white'), d('gamma')),
      'posterize' => PosterizeOp(i('levels')),
      'threshold' => ThresholdOp(i('level')),
      'autoLevels' => AutoLevelsOp(d('clip')),
      'autoWhiteBalance' => AutoWhiteBalanceOp(d('strength')),
      'lut' => LutOp(
        CubeLut.fromJson((json['lut']! as Map).cast<String, Object?>()),
        d('intensity'),
      ),
      'blur' => BlurOp(d('sigma')),
      'sharpen' => SharpenOp(d('amount'), d('sigma'), i('threshold')),
      'edges' => EdgesOp(invert: json['invert']! as bool),
      'emboss' => EmbossOp(d('strength')),
      'sketch' => SketchOp(d('sigma')),
      'vignette' => VignetteOp(d('strength'), d('radius')),
      'grain' => GrainOp(d('amount'), i('seed')),
      'pixelate' => PixelateOp(i('blockSize')),
      'kuwahara' => KuwaharaOp(i('radius')),
      'oilPaint' => OilPaintOp(i('radius'), i('levels')),
      'watercolor' => WatercolorOp(i('radius'), d('intensity')),
      'resize' => ResizeOp(
        json['width'] as int?,
        json['height'] as int?,
        ResizeFit.values.byName(json['fit']! as String),
      ),
      'downscale' => DownscaleOp(i('maxSide')),
      'rotate' => RotateOp(d('degrees')),
      'flip' => FlipOp(
        horizontal: json['horizontal']! as bool,
        vertical: json['vertical']! as bool,
      ),
      'crop' => CropOp(i('x'), i('y'), i('width'), i('height')),
      'cropAspect' => CropAspectOp(d('aspectRatio')),
      'redact' => RedactOp.fromJson(json),
      'watermark' => WatermarkOp.fromJson(json),
      _ => throw FormatException('Unknown pipeline op type "$type"'),
    };
  }
}

Uint8List _px(img.Image image) => image.toUint8List();

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

/// A colour-matrix step. Consecutive ones are fused by the executor.
final class ColorMatrixOp extends ImageOp {
  const ColorMatrixOp(this.matrix, this.label);

  final ColorMatrix matrix;
  final String label;

  @override
  String get type => 'colorMatrix';

  @override
  String describe() => label;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'label': label,
    'matrix': matrix.toJson(),
  };

  @override
  img.Image apply(img.Image image) {
    matrix.applyToRgba(_px(image));
    return image;
  }
}

abstract class _ToneOp extends ImageOp {
  const _ToneOp();

  double map(double v);

  @override
  img.Image apply(img.Image image) {
    final t = k.toneTable(map);
    k.applyChannelTables(_px(image), t, t, t);
    return image;
  }
}

final class GammaOp extends _ToneOp {
  const GammaOp(this.gamma);
  final double gamma;

  @override
  String get type => 'gamma';
  @override
  String describe() => 'gamma($gamma)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'gamma': gamma};
  @override
  double map(double v) => math.pow(v, 1 / gamma).toDouble();
}

final class ExposureOp extends _ToneOp {
  const ExposureOp(this.stops);
  final double stops;

  @override
  String get type => 'exposure';
  @override
  String describe() => 'exposure(${stops}EV)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'stops': stops};
  @override
  double map(double v) =>
      k.linearToSrgb(k.srgbToLinear(v) * math.pow(2, stops));
}

final class LevelsOp extends _ToneOp {
  const LevelsOp(this.black, this.white, this.gamma);
  final int black;
  final int white;
  final double gamma;

  @override
  String get type => 'levels';
  @override
  String describe() => 'levels($black..$white, gamma $gamma)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'black': black,
    'white': white,
    'gamma': gamma,
  };
  @override
  double map(double v) {
    final lo = black / 255, hi = white / 255;
    final x = ((v - lo) / (hi - lo)).clamp(0.0, 1.0);
    return math.pow(x, 1 / gamma).toDouble();
  }
}

final class PosterizeOp extends _ToneOp {
  const PosterizeOp(this.levels);
  final int levels;

  @override
  String get type => 'posterize';
  @override
  String describe() => 'posterize($levels)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'levels': levels};
  @override
  double map(double v) => (v * (levels - 1)).round() / (levels - 1);
}

final class ThresholdOp extends ImageOp {
  const ThresholdOp(this.level);
  final int level;

  @override
  String get type => 'threshold';
  @override
  String describe() => 'threshold($level)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'level': level};
  @override
  img.Image apply(img.Image image) {
    k.threshold(_px(image), level);
    return image;
  }
}

final class AutoLevelsOp extends ImageOp {
  const AutoLevelsOp(this.clip);
  final double clip;

  @override
  String get type => 'autoLevels';
  @override
  String describe() => 'autoLevels(clip ${clip * 100}%)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'clip': clip};
  @override
  img.Image apply(img.Image image) {
    final px = _px(image);
    final bounds = k.histogramBounds(px, clip);
    if (bounds == null) return image;
    final (lo, hi) = bounds;
    LevelsOp(lo, hi, 1).apply(image);
    return image;
  }
}

final class AutoWhiteBalanceOp extends ImageOp {
  const AutoWhiteBalanceOp(this.strength);
  final double strength;

  @override
  String get type => 'autoWhiteBalance';
  @override
  String describe() => 'autoWhiteBalance($strength)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'strength': strength};
  @override
  img.Image apply(img.Image image) {
    final px = _px(image);
    final gains = k.greyWorldGains(px);
    if (gains == null) return image;
    final (r, g, b) = gains;
    double mix(double gain) => 1 + (gain - 1) * strength;
    ColorMatrix.channelGains(mix(r), mix(g), mix(b)).applyToRgba(px);
    return image;
  }
}

final class LutOp extends ImageOp {
  const LutOp(this.lut, this.intensity);
  final CubeLut lut;
  final double intensity;

  @override
  String get type => 'lut';
  @override
  String describe() => 'lut(${lut.title ?? '${lut.size}^3'}, $intensity)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'intensity': intensity,
    'lut': lut.toJson(),
  };
  @override
  img.Image apply(img.Image image) {
    lut.applyToRgba(_px(image), intensity: intensity);
    return image;
  }
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

final class BlurOp extends ImageOp {
  const BlurOp(this.sigma);
  final double sigma;

  @override
  String get type => 'blur';
  @override
  String describe() => 'blur(sigma $sigma)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'sigma': sigma};
  @override
  img.Image apply(img.Image image) {
    k.gaussianBlur(_px(image), image.width, image.height, sigma);
    return image;
  }
}

final class SharpenOp extends ImageOp {
  const SharpenOp(this.amount, this.sigma, this.threshold);
  final double amount;
  final double sigma;
  final int threshold;

  @override
  String get type => 'sharpen';
  @override
  String describe() => 'sharpen($amount, sigma $sigma)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'amount': amount,
    'sigma': sigma,
    'threshold': threshold,
  };
  @override
  img.Image apply(img.Image image) {
    k.unsharpMask(
      _px(image),
      image.width,
      image.height,
      sigma: sigma,
      amount: amount,
      threshold: threshold,
    );
    return image;
  }
}

final class EdgesOp extends ImageOp {
  const EdgesOp({required this.invert});
  final bool invert;

  @override
  String get type => 'edges';
  @override
  String describe() => invert ? 'edges(inverted)' : 'edges';
  @override
  Map<String, Object?> toJson() => {'type': type, 'invert': invert};
  @override
  img.Image apply(img.Image image) {
    k.sobelEdges(_px(image), image.width, image.height, invert: invert);
    return image;
  }
}

final class EmbossOp extends ImageOp {
  const EmbossOp(this.strength);
  final double strength;

  @override
  String get type => 'emboss';
  @override
  String describe() => 'emboss($strength)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'strength': strength};
  @override
  img.Image apply(img.Image image) {
    k.emboss(_px(image), image.width, image.height, strength: strength);
    return image;
  }
}

final class SketchOp extends ImageOp {
  const SketchOp(this.sigma);
  final double sigma;

  @override
  String get type => 'sketch';
  @override
  String describe() => 'sketch(sigma $sigma)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'sigma': sigma};
  @override
  img.Image apply(img.Image image) {
    k.pencilSketch(_px(image), image.width, image.height, sigma: sigma);
    return image;
  }
}

// ---------------------------------------------------------------------------
// Artistic
// ---------------------------------------------------------------------------

final class VignetteOp extends ImageOp {
  const VignetteOp(this.strength, this.radius);
  final double strength;
  final double radius;

  @override
  String get type => 'vignette';
  @override
  String describe() => 'vignette($strength, radius $radius)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'strength': strength,
    'radius': radius,
  };
  @override
  img.Image apply(img.Image image) {
    k.vignette(
      _px(image),
      image.width,
      image.height,
      strength: strength,
      radius: radius,
    );
    return image;
  }
}

final class GrainOp extends ImageOp {
  const GrainOp(this.amount, this.seed);
  final double amount;
  final int seed;

  @override
  String get type => 'grain';
  @override
  String describe() => 'grain($amount)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'amount': amount,
    'seed': seed,
  };
  @override
  img.Image apply(img.Image image) {
    k.grain(_px(image), amount: amount, seed: seed);
    return image;
  }
}

final class PixelateOp extends ImageOp {
  const PixelateOp(this.blockSize);
  final int blockSize;

  @override
  String get type => 'pixelate';
  @override
  String describe() => 'pixelate($blockSize px)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'blockSize': blockSize};
  @override
  img.Image apply(img.Image image) {
    k.pixelateBounds(_px(image), image.width, (
      left: 0,
      top: 0,
      right: image.width,
      bottom: image.height,
    ), blockSize);
    return image;
  }
}

final class KuwaharaOp extends ImageOp {
  const KuwaharaOp(this.radius);
  final int radius;

  @override
  String get type => 'kuwahara';
  @override
  String describe() => 'kuwahara(radius $radius)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'radius': radius};
  @override
  img.Image apply(img.Image image) {
    k.kuwahara(_px(image), image.width, image.height, radius);
    return image;
  }
}

final class OilPaintOp extends ImageOp {
  const OilPaintOp(this.radius, this.levels);
  final int radius;
  final int levels;

  @override
  String get type => 'oilPaint';
  @override
  String describe() => 'oilPaint(radius $radius, $levels levels)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'radius': radius,
    'levels': levels,
  };
  @override
  img.Image apply(img.Image image) {
    k.oilPaint(
      _px(image),
      image.width,
      image.height,
      radius: radius,
      levels: levels,
    );
    return image;
  }
}

final class WatercolorOp extends ImageOp {
  const WatercolorOp(this.radius, this.intensity);
  final int radius;
  final double intensity;

  @override
  String get type => 'watercolor';
  @override
  String describe() => 'watercolor(radius $radius, $intensity)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'radius': radius,
    'intensity': intensity,
  };

  @override
  img.Image apply(img.Image image) {
    final px = _px(image);
    final w = image.width, h = image.height;
    final original = Uint8List.fromList(px);
    // 1. Flat washes of colour with crisp edges.
    k.kuwahara(px, w, h, radius);
    ColorMatrix.saturation(1.15).applyToRgba(px);
    // 2. Pigment pooling: darken slightly along edges.
    final edges = Uint8List.fromList(px);
    k.sobelEdges(edges, w, h, invert: true);
    for (var i = 0; i < px.length; i += 4) {
      final f = 0.78 + 0.22 * (edges[i] / 255.0);
      px[i] = k.clamp8(px[i] * f);
      px[i + 1] = k.clamp8(px[i + 1] * f);
      px[i + 2] = k.clamp8(px[i + 2] * f);
    }
    // 3. Blend with the original by intensity.
    final t = intensity.clamp(0.0, 1.0);
    if (t < 1) {
      for (var i = 0; i < px.length; i++) {
        px[i] = k.clamp8(original[i] + (px[i] - original[i]) * t);
      }
    }
    return image;
  }
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

img.Image _resizeTo(img.Image image, int width, int height) {
  if (width == image.width && height == image.height) return image;
  final shrinking = width <= image.width && height <= image.height;
  return img.copyResize(
    image,
    width: width,
    height: height,
    interpolation: shrinking
        ? img.Interpolation.average
        : img.Interpolation.cubic,
  );
}

final class ResizeOp extends ImageOp {
  const ResizeOp(this.width, this.height, this.fit);
  final int? width;
  final int? height;
  final ResizeFit fit;

  @override
  String get type => 'resize';
  @override
  String describe() =>
      'resize(${width ?? 'auto'}x${height ?? 'auto'}, ${fit.name})';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'width': width,
    'height': height,
    'fit': fit.name,
  };

  @override
  img.Image apply(img.Image image) {
    final sw = image.width, sh = image.height;
    final tw = width, th = height;
    if (tw == null && th == null) return image;
    if (tw == null || th == null) {
      final scale = tw != null ? tw / sw : th! / sh;
      return _resizeTo(
        image,
        math.max(1, tw ?? (sw * scale).round()),
        math.max(1, th ?? (sh * scale).round()),
      );
    }
    switch (fit) {
      case ResizeFit.fill:
        return _resizeTo(image, tw, th);
      case ResizeFit.contain:
        final scale = math.min(tw / sw, th / sh);
        return _resizeTo(
          image,
          math.max(1, (sw * scale).round()),
          math.max(1, (sh * scale).round()),
        );
      case ResizeFit.cover:
        final scale = math.max(tw / sw, th / sh);
        final scaled = _resizeTo(
          image,
          math.max(tw, (sw * scale).round()),
          math.max(th, (sh * scale).round()),
        );
        return img.copyCrop(
          scaled,
          x: (scaled.width - tw) ~/ 2,
          y: (scaled.height - th) ~/ 2,
          width: tw,
          height: th,
        );
    }
  }
}

final class DownscaleOp extends ImageOp {
  const DownscaleOp(this.maxSide);
  final int maxSide;

  @override
  String get type => 'downscale';
  @override
  String describe() => 'downscale(max $maxSide px)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'maxSide': maxSide};
  @override
  img.Image apply(img.Image image) {
    final longest = math.max(image.width, image.height);
    if (longest <= maxSide) return image;
    final scale = maxSide / longest;
    return _resizeTo(
      image,
      math.max(1, (image.width * scale).round()),
      math.max(1, (image.height * scale).round()),
    );
  }
}

final class RotateOp extends ImageOp {
  const RotateOp(this.degrees);
  final double degrees;

  @override
  String get type => 'rotate';
  @override
  String describe() => 'rotate($degrees°)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'degrees': degrees};
  @override
  img.Image apply(img.Image image) {
    if (degrees % 360 == 0) return image;
    final rightAngle = degrees % 90 == 0;
    return img.copyRotate(
      image,
      angle: degrees,
      interpolation: rightAngle
          ? img.Interpolation.nearest
          : img.Interpolation.linear,
    );
  }
}

final class FlipOp extends ImageOp {
  const FlipOp({required this.horizontal, required this.vertical});
  final bool horizontal;
  final bool vertical;

  @override
  String get type => 'flip';
  @override
  String describe() =>
      'flip(${[if (horizontal) 'h', if (vertical) 'v'].join('+')})';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'horizontal': horizontal,
    'vertical': vertical,
  };
  @override
  img.Image apply(img.Image image) {
    if (horizontal && vertical) {
      return img.flip(image, direction: img.FlipDirection.both);
    }
    if (horizontal) {
      return img.flip(image, direction: img.FlipDirection.horizontal);
    }
    if (vertical) {
      return img.flip(image, direction: img.FlipDirection.vertical);
    }
    return image;
  }
}

final class CropOp extends ImageOp {
  const CropOp(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  String get type => 'crop';
  @override
  String describe() => 'crop($x,$y ${width}x$height)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
  @override
  img.Image apply(img.Image image) {
    final x0 = x.clamp(0, image.width);
    final y0 = y.clamp(0, image.height);
    final x1 = (x + width).clamp(0, image.width);
    final y1 = (y + height).clamp(0, image.height);
    if (x1 <= x0 || y1 <= y0) {
      throw ImageProcessingException(
        'Crop ($x, $y, ${width}x$height) lies outside the '
        '${image.width}x${image.height} image',
      );
    }
    return img.copyCrop(image, x: x0, y: y0, width: x1 - x0, height: y1 - y0);
  }
}

final class CropAspectOp extends ImageOp {
  const CropAspectOp(this.aspectRatio);
  final double aspectRatio;

  @override
  String get type => 'cropAspect';
  @override
  String describe() => 'cropToAspect($aspectRatio)';
  @override
  Map<String, Object?> toJson() => {'type': type, 'aspectRatio': aspectRatio};
  @override
  img.Image apply(img.Image image) {
    final current = image.width / image.height;
    if ((current - aspectRatio).abs() < 1e-3) return image;
    final w = current > aspectRatio
        ? (image.height * aspectRatio).round()
        : image.width;
    final h = current > aspectRatio
        ? image.height
        : (image.width / aspectRatio).round();
    return img.copyCrop(
      image,
      x: (image.width - w) ~/ 2,
      y: (image.height - h) ~/ 2,
      width: math.max(1, w),
      height: math.max(1, h),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy and composition
// ---------------------------------------------------------------------------

final class RedactOp extends ImageOp {
  RedactOp({
    required List<math.Rectangle<double>> regions,
    required this.style,
    required this.padding,
    required this.color,
    this.blockSize,
    this.sigma,
  }) : regions = List.unmodifiable(regions);

  factory RedactOp.fromJson(Map<String, Object?> json) => RedactOp(
    regions: (json['regions']! as List<Object?>).map((r) {
      final v = (r! as List<Object?>)
          .map((n) => (n! as num).toDouble())
          .toList();
      return math.Rectangle<double>(v[0], v[1], v[2], v[3]);
    }).toList(),
    style: RedactionStyle.values.byName(json['style']! as String),
    padding: (json['padding']! as num).toDouble(),
    color: (json['color']! as num).toInt(),
    blockSize: (json['blockSize'] as num?)?.toInt(),
    sigma: (json['sigma'] as num?)?.toDouble(),
  );

  final List<math.Rectangle<double>> regions;
  final RedactionStyle style;
  final double padding;
  final int color;
  final int? blockSize;
  final double? sigma;

  @override
  String get type => 'redact';
  @override
  String describe() => 'redact(${regions.length} regions, ${style.name})';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'regions': [
      for (final r in regions) [r.left, r.top, r.width, r.height],
    ],
    'style': style.name,
    'padding': padding,
    'color': color,
    if (blockSize != null) 'blockSize': blockSize,
    if (sigma != null) 'sigma': sigma,
  };

  @override
  img.Image apply(img.Image image) {
    final px = _px(image);
    final w = image.width, h = image.height;
    for (final r in regions) {
      final padX = r.width * padding, padY = r.height * padding;
      final left = math.max(0, (r.left - padX).floor());
      final top = math.max(0, (r.top - padY).floor());
      final right = math.min(w, (r.left + r.width + padX).ceil());
      final bottom = math.min(h, (r.top + r.height + padY).ceil());
      if (right <= left || bottom <= top) continue;
      final bounds = (left: left, top: top, right: right, bottom: bottom);
      final longSide = math.max(right - left, bottom - top);
      switch (style) {
        case RedactionStyle.pixelate:
          k.pixelateBounds(
            px,
            w,
            bounds,
            blockSize ?? math.max(6, (longSide / 8).ceil()),
          );
        case RedactionStyle.blur:
          k.blurBounds(px, w, h, bounds, sigma ?? math.max(4.0, longSide / 6));
        case RedactionStyle.fill:
          k.fillBounds(px, w, bounds, color);
      }
    }
    return image;
  }
}

final class WatermarkOp extends ImageOp {
  WatermarkOp({
    required this.bytes,
    required this.anchor,
    required this.margin,
    required this.opacity,
    this.widthFraction,
    this.offset,
  });

  factory WatermarkOp.fromJson(Map<String, Object?> json) {
    final offset = json['offset'] as List<Object?>?;
    return WatermarkOp(
      bytes: base64Decode(json['bytes']! as String),
      anchor: WatermarkAnchor.values.byName(json['anchor']! as String),
      margin: (json['margin']! as num).toDouble(),
      opacity: (json['opacity']! as num).toDouble(),
      widthFraction: (json['widthFraction'] as num?)?.toDouble(),
      offset: offset == null
          ? null
          : math.Point<int>(offset[0]! as int, offset[1]! as int),
    );
  }

  final Uint8List bytes;
  final WatermarkAnchor anchor;
  final double margin;
  final double opacity;
  final double? widthFraction;
  final math.Point<int>? offset;

  @override
  String get type => 'watermark';
  @override
  String describe() => offset == null
      ? 'watermark(${anchor.name}, opacity $opacity)'
      : 'watermark(at ${offset!.x},${offset!.y}, opacity $opacity)';
  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'bytes': base64Encode(bytes),
    'anchor': anchor.name,
    'margin': margin,
    'opacity': opacity,
    if (widthFraction != null) 'widthFraction': widthFraction,
    if (offset != null) 'offset': [offset!.x, offset!.y],
  };

  @override
  img.Image apply(img.Image image) {
    final decoded = guardCodec(
      'Watermark bytes are not a decodable image',
      () => img.decodeImage(bytes),
    );
    if (decoded == null) {
      throw const UnsupportedImageException(
        'Watermark bytes are not a decodable image',
      );
    }
    var mark = ensureRgba8(img.bakeOrientation(decoded));
    final fraction = widthFraction;
    if (fraction != null && fraction > 0) {
      final tw = math.max(1, (image.width * fraction).round());
      final th = math.max(1, (mark.height * tw / mark.width).round());
      mark = ensureRgba8(_resizeTo(mark, tw, th));
    }
    final int x, y;
    final o = offset;
    if (o != null) {
      x = o.x;
      y = o.y;
    } else {
      final m = (math.min(image.width, image.height) * margin).round();
      final col = anchor.index % 3; // 0 left, 1 centre, 2 right
      final row = anchor.index ~/ 3; // 0 top, 1 centre, 2 bottom
      x = switch (col) {
        0 => m,
        1 => (image.width - mark.width) ~/ 2,
        _ => image.width - mark.width - m,
      };
      y = switch (row) {
        0 => m,
        1 => (image.height - mark.height) ~/ 2,
        _ => image.height - mark.height - m,
      };
    }
    k.blendOver(
      _px(image),
      image.width,
      image.height,
      _px(mark),
      mark.width,
      mark.height,
      x,
      y,
      opacity.clamp(0.0, 1.0),
    );
    return image;
  }
}

/// A user-supplied transform. Not JSON-serialisable.
final class CustomOp extends ImageOp {
  const CustomOp(this.name, this.transform);
  final String name;
  final img.Image Function(img.Image image) transform;

  @override
  String get type => 'custom';
  @override
  String describe() => 'custom($name)';
  @override
  bool get isSerializable => false;
  @override
  Map<String, Object?> toJson() => throw UnsupportedError(
    'Custom op "$name" wraps a Dart function and cannot be serialised',
  );
  @override
  img.Image apply(img.Image image) => transform(image);
}
