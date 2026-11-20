// Pixel kernels over tightly packed RGBA8888 buffers (straight alpha).
//
// Internal to the engine. Every function here is allocation-conscious and
// linear in pixel count unless noted, so cost does not explode with radius.

import 'dart:math' as math;
import 'dart:typed_data';

/// Clamps and rounds to a byte.
int clamp8(double v) {
  if (v <= 0) return 0;
  if (v >= 255) return 255;
  return (v + 0.5).toInt();
}

/// Rec. 709 luma in integer arithmetic (weights sum to 256).
int luma(int r, int g, int b) => (54 * r + 183 * g + 19 * b) >> 8;

/// Whether any pixel is not fully opaque.
bool hasTranslucency(Uint8List px) {
  for (var i = 3; i < px.length; i += 4) {
    if (px[i] != 255) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Blur
// ---------------------------------------------------------------------------

/// Gaussian blur approximated by three successive box blurs.
///
/// Runtime is O(pixels) regardless of [sigma], unlike a direct convolution
/// which is O(pixels x radius). Translucent images are blurred in
/// premultiplied space so transparent edges do not bleed dark fringes.
void gaussianBlur(Uint8List px, int w, int h, double sigma) {
  if (sigma <= 0 || w == 0 || h == 0) return;
  final translucent = hasTranslucency(px);
  if (translucent) _premultiply(px);
  final tmp = Uint8List(px.length);
  for (final size in _boxSizesForGauss(sigma, 3)) {
    final r = (size - 1) ~/ 2;
    if (r <= 0) continue;
    _boxBlurH(px, tmp, w, h, r);
    _boxBlurV(tmp, px, w, h, r);
  }
  if (translucent) _unpremultiply(px);
}

/// Box sizes whose successive application approximates a Gaussian of
/// [sigma] (Kovesi / Kutskir).
List<int> _boxSizesForGauss(double sigma, int n) {
  final wIdeal = math.sqrt((12 * sigma * sigma / n) + 1);
  var wl = wIdeal.floor();
  if (wl.isEven) wl--;
  final wu = wl + 2;
  final mIdeal =
      (12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4);
  final m = mIdeal.round();
  return List<int>.generate(n, (i) => i < m ? wl : wu);
}

void _boxBlurH(Uint8List src, Uint8List dst, int w, int h, int r) {
  final inv = 1.0 / (2 * r + 1);
  final last = w - 1;
  for (var y = 0; y < h; y++) {
    final row = y * w * 4;
    var s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for (var k = -r; k <= r; k++) {
      final i = row + (k < 0 ? 0 : (k > last ? last : k)) * 4;
      s0 += src[i];
      s1 += src[i + 1];
      s2 += src[i + 2];
      s3 += src[i + 3];
    }
    for (var x = 0; x < w; x++) {
      final o = row + x * 4;
      dst[o] = (s0 * inv + 0.5).toInt();
      dst[o + 1] = (s1 * inv + 0.5).toInt();
      dst[o + 2] = (s2 * inv + 0.5).toInt();
      dst[o + 3] = (s3 * inv + 0.5).toInt();
      final add = x + r + 1;
      final sub = x - r;
      final ai = row + (add > last ? last : add) * 4;
      final si = row + (sub < 0 ? 0 : sub) * 4;
      s0 += src[ai] - src[si];
      s1 += src[ai + 1] - src[si + 1];
      s2 += src[ai + 2] - src[si + 2];
      s3 += src[ai + 3] - src[si + 3];
    }
  }
}

void _boxBlurV(Uint8List src, Uint8List dst, int w, int h, int r) {
  final inv = 1.0 / (2 * r + 1);
  final last = h - 1;
  final stride = w * 4;
  for (var x = 0; x < w; x++) {
    final col = x * 4;
    var s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for (var k = -r; k <= r; k++) {
      final i = col + (k < 0 ? 0 : (k > last ? last : k)) * stride;
      s0 += src[i];
      s1 += src[i + 1];
      s2 += src[i + 2];
      s3 += src[i + 3];
    }
    for (var y = 0; y < h; y++) {
      final o = col + y * stride;
      dst[o] = (s0 * inv + 0.5).toInt();
      dst[o + 1] = (s1 * inv + 0.5).toInt();
      dst[o + 2] = (s2 * inv + 0.5).toInt();
      dst[o + 3] = (s3 * inv + 0.5).toInt();
      final add = y + r + 1;
      final sub = y - r;
      final ai = col + (add > last ? last : add) * stride;
      final si = col + (sub < 0 ? 0 : sub) * stride;
      s0 += src[ai] - src[si];
      s1 += src[ai + 1] - src[si + 1];
      s2 += src[ai + 2] - src[si + 2];
      s3 += src[ai + 3] - src[si + 3];
    }
  }
}

void _premultiply(Uint8List px) {
  for (var i = 0; i < px.length; i += 4) {
    final a = px[i + 3];
    if (a == 255) continue;
    px[i] = (px[i] * a + 127) ~/ 255;
    px[i + 1] = (px[i + 1] * a + 127) ~/ 255;
    px[i + 2] = (px[i + 2] * a + 127) ~/ 255;
  }
}

void _unpremultiply(Uint8List px) {
  for (var i = 0; i < px.length; i += 4) {
    final a = px[i + 3];
    if (a == 255) continue;
    if (a == 0) {
      px[i] = 0;
      px[i + 1] = 0;
      px[i + 2] = 0;
      continue;
    }
    px[i] = math.min(255, (px[i] * 255 + (a >> 1)) ~/ a);
    px[i + 1] = math.min(255, (px[i + 1] * 255 + (a >> 1)) ~/ a);
    px[i + 2] = math.min(255, (px[i + 2] * 255 + (a >> 1)) ~/ a);
  }
}

/// Unsharp mask: adds back `amount x (original - blurred)` where the local
/// difference exceeds [threshold] (0..255), sharpening edges but not noise.
void unsharpMask(
  Uint8List px,
  int w,
  int h, {
  required double sigma,
  required double amount,
  required int threshold,
}) {
  final blurred = Uint8List.fromList(px);
  gaussianBlur(blurred, w, h, sigma);
  for (var i = 0; i < px.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      final o = px[i + c];
      final diff = o - blurred[i + c];
      if (diff.abs() >= threshold) {
        px[i + c] = clamp8(o + amount * diff);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Edges and relief
// ---------------------------------------------------------------------------

Uint8List _lumaPlane(Uint8List px, int w, int h) {
  final out = Uint8List(w * h);
  for (var p = 0, i = 0; p < out.length; p++, i += 4) {
    out[p] = luma(px[i], px[i + 1], px[i + 2]);
  }
  return out;
}

/// Sobel edge magnitude, written as greyscale. With [invert], edges are dark
/// on white, like an ink drawing.
void sobelEdges(Uint8List px, int w, int h, {required bool invert}) {
  final l = _lumaPlane(px, w, h);
  final lastX = w - 1, lastY = h - 1;
  for (var y = 0; y < h; y++) {
    final ym = (y == 0 ? 0 : y - 1) * w;
    final y0 = y * w;
    final yp = (y == lastY ? lastY : y + 1) * w;
    for (var x = 0; x < w; x++) {
      final xm = x == 0 ? 0 : x - 1;
      final xp = x == lastX ? lastX : x + 1;
      final gx =
          -l[ym + xm] -
          2 * l[y0 + xm] -
          l[yp + xm] +
          l[ym + xp] +
          2 * l[y0 + xp] +
          l[yp + xp];
      final gy =
          -l[ym + xm] -
          2 * l[ym + x] -
          l[ym + xp] +
          l[yp + xm] +
          2 * l[yp + x] +
          l[yp + xp];
      var mag = math.sqrt((gx * gx + gy * gy).toDouble());
      if (mag > 255) mag = 255;
      final v = invert ? 255 - mag.toInt() : mag.toInt();
      final o = (y0 + x) * 4;
      px[o] = v;
      px[o + 1] = v;
      px[o + 2] = v;
    }
  }
}

/// Emboss relief on luminance, centred on mid-grey.
void emboss(Uint8List px, int w, int h, {required double strength}) {
  final l = _lumaPlane(px, w, h);
  final lastX = w - 1, lastY = h - 1;
  for (var y = 0; y < h; y++) {
    final ym = (y == 0 ? 0 : y - 1) * w;
    final yp = (y == lastY ? lastY : y + 1) * w;
    final y0 = y * w;
    for (var x = 0; x < w; x++) {
      final xm = x == 0 ? 0 : x - 1;
      final xp = x == lastX ? lastX : x + 1;
      final g =
          -l[ym + xm] -
          l[ym + x] -
          l[y0 + xm] +
          l[y0 + xp] +
          l[yp + x] +
          l[yp + xp];
      final v = clamp8(128 + strength * g);
      final o = (y0 + x) * 4;
      px[o] = v;
      px[o + 1] = v;
      px[o + 2] = v;
    }
  }
}

/// Pencil sketch: colour-dodge of greyscale over its blurred negative.
void pencilSketch(Uint8List px, int w, int h, {required double sigma}) {
  final gray = _lumaPlane(px, w, h);
  final inv = Uint8List(px.length);
  for (var p = 0, i = 0; p < gray.length; p++, i += 4) {
    final v = 255 - gray[p];
    inv[i] = v;
    inv[i + 1] = v;
    inv[i + 2] = v;
    inv[i + 3] = 255;
  }
  gaussianBlur(inv, w, h, sigma);
  for (var p = 0, i = 0; p < gray.length; p++, i += 4) {
    final b = inv[i];
    final v = b >= 255 ? 255 : math.min(255, (gray[p] * 255) ~/ (255 - b));
    px[i] = v;
    px[i + 1] = v;
    px[i + 2] = v;
  }
}

// ---------------------------------------------------------------------------
// Painterly
// ---------------------------------------------------------------------------

/// Kuwahara filter: each pixel takes the mean colour of whichever of its
/// four (r+1)x(r+1) quadrants has the lowest luminance variance. Flattens
/// texture while keeping edges crisp, which reads as brushwork.
///
/// O(pixels) via sliding column sums and per-row prefix sums, so radius is
/// almost free. Extra memory is O(width), plus one copy of the source.
void kuwahara(Uint8List px, int w, int h, int r) {
  if (r <= 0) return;
  final src = Uint8List.fromList(px);
  // Five accumulated channels: R, G, B, L, L^2.
  final top = List<Float64List>.generate(5, (_) => Float64List(w));
  final bot = List<Float64List>.generate(5, (_) => Float64List(w));
  final topP = List<Float64List>.generate(5, (_) => Float64List(w + 1));
  final botP = List<Float64List>.generate(5, (_) => Float64List(w + 1));

  void addRow(List<Float64List> cols, int y, double sign) {
    final row = y * w * 4;
    for (var x = 0; x < w; x++) {
      final i = row + x * 4;
      final rr = src[i], gg = src[i + 1], bb = src[i + 2];
      final l = luma(rr, gg, bb).toDouble();
      cols[0][x] += sign * rr;
      cols[1][x] += sign * gg;
      cols[2][x] += sign * bb;
      cols[3][x] += sign * l;
      cols[4][x] += sign * l * l;
    }
  }

  void prefix(List<Float64List> cols, List<Float64List> out) {
    for (var c = 0; c < 5; c++) {
      final col = cols[c];
      final p = out[c];
      var acc = 0.0;
      for (var x = 0; x < w; x++) {
        acc += col[x];
        p[x + 1] = acc;
      }
    }
  }

  // Initial bands for y = 0: top = [0, 0], bottom = [0, min(r, h-1)].
  addRow(top, 0, 1);
  for (var y = 0; y <= math.min(r, h - 1); y++) {
    addRow(bot, y, 1);
  }

  for (var y = 0; y < h; y++) {
    if (y > 0) {
      addRow(top, y, 1);
      if (y - r - 1 >= 0) addRow(top, y - r - 1, -1);
      if (y + r < h) addRow(bot, y + r, 1);
      addRow(bot, y - 1, -1);
    }
    prefix(top, topP);
    prefix(bot, botP);
    final topRows = y - math.max(0, y - r) + 1;
    final botRows = math.min(h - 1, y + r) - y + 1;

    for (var x = 0; x < w; x++) {
      final xl = math.max(0, x - r);
      final xr = math.min(w - 1, x + r);
      var bestVar = double.infinity;
      var bestR = 0.0, bestG = 0.0, bestB = 0.0;
      for (var q = 0; q < 4; q++) {
        final useTop = q < 2;
        final a = q.isEven ? xl : x;
        final b = q.isEven ? x : xr;
        final p = useTop ? topP : botP;
        final count = (b - a + 1) * (useTop ? topRows : botRows);
        final sl = p[3][b + 1] - p[3][a];
        final sl2 = p[4][b + 1] - p[4][a];
        final mean = sl / count;
        final variance = sl2 / count - mean * mean;
        if (variance < bestVar) {
          bestVar = variance;
          bestR = (p[0][b + 1] - p[0][a]) / count;
          bestG = (p[1][b + 1] - p[1][a]) / count;
          bestB = (p[2][b + 1] - p[2][a]) / count;
        }
      }
      final o = (y * w + x) * 4;
      px[o] = clamp8(bestR);
      px[o + 1] = clamp8(bestG);
      px[o + 2] = clamp8(bestB);
    }
  }
}

/// Classic oil-paint effect: each pixel takes the average colour of the most
/// common intensity bucket in its neighbourhood.
///
/// Uses a sliding histogram along each row, so cost is
/// O(pixels x (radius + levels)) instead of O(pixels x radius^2).
void oilPaint(
  Uint8List px,
  int w,
  int h, {
  required int radius,
  required int levels,
}) {
  if (radius <= 0 || levels < 2) return;
  final src = Uint8List.fromList(px);
  final bin = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    bin[v] = math.min(levels - 1, (v * levels) >> 8);
  }
  final count = Int32List(levels);
  final sumR = Int32List(levels);
  final sumG = Int32List(levels);
  final sumB = Int32List(levels);

  for (var y = 0; y < h; y++) {
    final y0 = math.max(0, y - radius);
    final y1 = math.min(h - 1, y + radius);
    count.fillRange(0, levels, 0);
    sumR.fillRange(0, levels, 0);
    sumG.fillRange(0, levels, 0);
    sumB.fillRange(0, levels, 0);

    void column(int x, int sign) {
      for (var yy = y0; yy <= y1; yy++) {
        final i = (yy * w + x) * 4;
        final rr = src[i], gg = src[i + 1], bb = src[i + 2];
        final k = bin[luma(rr, gg, bb)];
        count[k] += sign;
        sumR[k] += sign * rr;
        sumG[k] += sign * gg;
        sumB[k] += sign * bb;
      }
    }

    for (var x = 0; x <= math.min(radius, w - 1); x++) {
      column(x, 1);
    }
    for (var x = 0; x < w; x++) {
      var best = 0;
      for (var k = 1; k < levels; k++) {
        if (count[k] > count[best]) best = k;
      }
      final n = count[best];
      final o = (y * w + x) * 4;
      if (n > 0) {
        px[o] = sumR[best] ~/ n;
        px[o + 1] = sumG[best] ~/ n;
        px[o + 2] = sumB[best] ~/ n;
      }
      final out = x - radius;
      final inn = x + radius + 1;
      if (out >= 0) column(out, -1);
      if (inn < w) column(inn, 1);
    }
  }
}

// ---------------------------------------------------------------------------
// Tone
// ---------------------------------------------------------------------------

/// Applies three 256-entry per-channel tables in place.
void applyChannelTables(
  Uint8List px,
  Uint8List tr,
  Uint8List tg,
  Uint8List tb,
) {
  for (var i = 0; i < px.length; i += 4) {
    px[i] = tr[px[i]];
    px[i + 1] = tg[px[i + 1]];
    px[i + 2] = tb[px[i + 2]];
  }
}

/// Builds a 256-entry table from [f], which maps `0..1` to `0..1`.
Uint8List toneTable(double Function(double v) f) {
  final t = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    t[v] = clamp8(f(v / 255.0) * 255.0);
  }
  return t;
}

double srgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double linearToSrgb(double c) {
  if (c <= 0) return 0;
  if (c >= 1) return 1;
  return c <= 0.0031308
      ? c * 12.92
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
}

/// Black/white points from the luminance histogram, ignoring the darkest and
/// brightest [clip] fraction of pixels. Returns `null` for flat images where
/// stretching would only amplify noise.
(int, int)? histogramBounds(Uint8List px, double clip) {
  final hist = Int32List(256);
  var total = 0;
  for (var i = 0; i < px.length; i += 4) {
    if (px[i + 3] == 0) continue;
    hist[luma(px[i], px[i + 1], px[i + 2])]++;
    total++;
  }
  if (total == 0) return null;
  final cut = (total * clip).floor();
  var lo = 0, acc = 0;
  while (lo < 255 && acc + hist[lo] <= cut) {
    acc += hist[lo];
    lo++;
  }
  var hi = 255;
  acc = 0;
  while (hi > 0 && acc + hist[hi] <= cut) {
    acc += hist[hi];
    hi--;
  }
  if (hi - lo < 16) return null;
  return (lo, hi);
}

/// Grey-world white balance gains (R, G, B), ignoring clipped pixels.
(double, double, double)? greyWorldGains(Uint8List px) {
  var sr = 0.0, sg = 0.0, sb = 0.0;
  var n = 0;
  for (var i = 0; i < px.length; i += 4) {
    final r = px[i], g = px[i + 1], b = px[i + 2];
    final l = luma(r, g, b);
    if (px[i + 3] == 0 || l < 16 || l > 240) continue;
    sr += r;
    sg += g;
    sb += b;
    n++;
  }
  if (n == 0 || sr == 0 || sg == 0 || sb == 0) return null;
  final grey = (sr + sg + sb) / 3;
  return (grey / sr, grey / sg, grey / sb);
}

/// Black-and-white threshold on luminance.
void threshold(Uint8List px, int level) {
  for (var i = 0; i < px.length; i += 4) {
    final v = luma(px[i], px[i + 1], px[i + 2]) >= level ? 255 : 0;
    px[i] = v;
    px[i + 1] = v;
    px[i + 2] = v;
  }
}

// ---------------------------------------------------------------------------
// Light and texture
// ---------------------------------------------------------------------------

/// Darkens towards the corners. [radius] (0..1) is where falloff starts as a
/// fraction of the centre-to-corner distance; [strength] is the darkening at
/// the corners.
void vignette(
  Uint8List px,
  int w,
  int h, {
  required double strength,
  required double radius,
}) {
  final cx = (w - 1) / 2, cy = (h - 1) / 2;
  final maxD = math.sqrt(cx * cx + cy * cy);
  if (maxD == 0) return;
  final inner = radius.clamp(0.0, 0.99);
  final span = 1 - inner;
  for (var y = 0; y < h; y++) {
    final dy = (y - cy) / maxD;
    final dy2 = dy * dy;
    for (var x = 0; x < w; x++) {
      final dx = (x - cx) / maxD;
      final d = math.sqrt(dx * dx + dy2);
      if (d <= inner) continue;
      var t = (d - inner) / span;
      if (t > 1) t = 1;
      t = t * t * (3 - 2 * t); // smoothstep
      final f = 1 - strength * t;
      final o = (y * w + x) * 4;
      px[o] = clamp8(px[o] * f);
      px[o + 1] = clamp8(px[o + 1] * f);
      px[o + 2] = clamp8(px[o + 2] * f);
    }
  }
}

/// Deterministic monochrome film grain. Same [seed] gives the same grain on
/// every platform, so pipelines stay reproducible.
void grain(Uint8List px, {required double amount, required int seed}) {
  var s = seed & 0xFFFFFFFF;
  if (s == 0) s = 0x9E3779B9;
  final scale = amount * 96.0;
  for (var i = 0; i < px.length; i += 4) {
    // xorshift32, twice, for a triangular distribution in [-1, 1].
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= s >> 17;
    s ^= (s << 5) & 0xFFFFFFFF;
    final u1 = s / 4294967296.0;
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= s >> 17;
    s ^= (s << 5) & 0xFFFFFFFF;
    final u2 = s / 4294967296.0;
    final n = (u1 + u2 - 1) * scale;
    px[i] = clamp8(px[i] + n);
    px[i + 1] = clamp8(px[i + 1] + n);
    px[i + 2] = clamp8(px[i + 2] + n);
  }
}

// ---------------------------------------------------------------------------
// Regions
// ---------------------------------------------------------------------------

/// Integer pixel bounds, half-open: `[left, right) x [top, bottom)`.
typedef PixelBounds = ({int left, int top, int right, int bottom});

/// Replaces each [block]x[block] cell inside [b] with its average colour.
void pixelateBounds(Uint8List px, int w, PixelBounds b, int block) {
  for (var by = b.top; by < b.bottom; by += block) {
    final ey = math.min(by + block, b.bottom);
    for (var bx = b.left; bx < b.right; bx += block) {
      final ex = math.min(bx + block, b.right);
      var r = 0, g = 0, bl = 0, a = 0;
      for (var y = by; y < ey; y++) {
        for (var x = bx; x < ex; x++) {
          final i = (y * w + x) * 4;
          r += px[i];
          g += px[i + 1];
          bl += px[i + 2];
          a += px[i + 3];
        }
      }
      final n = (ey - by) * (ex - bx);
      final ar = r ~/ n, ag = g ~/ n, ab = bl ~/ n, aa = a ~/ n;
      for (var y = by; y < ey; y++) {
        for (var x = bx; x < ex; x++) {
          final i = (y * w + x) * 4;
          px[i] = ar;
          px[i + 1] = ag;
          px[i + 2] = ab;
          px[i + 3] = aa;
        }
      }
    }
  }
}

/// Fills [b] with an opaque ARGB [color].
void fillBounds(Uint8List px, int w, PixelBounds b, int color) {
  final a = (color >> 24) & 0xFF;
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final bl = color & 0xFF;
  for (var y = b.top; y < b.bottom; y++) {
    for (var x = b.left; x < b.right; x++) {
      final i = (y * w + x) * 4;
      px[i] = r;
      px[i + 1] = g;
      px[i + 2] = bl;
      px[i + 3] = a;
    }
  }
}

/// Gaussian-blurs only the pixels inside [b]. Surrounding pixels feed the
/// blur (so it blends naturally) but are not modified.
void blurBounds(Uint8List px, int w, int h, PixelBounds b, double sigma) {
  final pad = (sigma * 3).ceil();
  final x0 = math.max(0, b.left - pad), y0 = math.max(0, b.top - pad);
  final x1 = math.min(w, b.right + pad), y1 = math.min(h, b.bottom + pad);
  final sw = x1 - x0, sh = y1 - y0;
  if (sw <= 0 || sh <= 0) return;
  final sub = Uint8List(sw * sh * 4);
  for (var y = 0; y < sh; y++) {
    final from = ((y0 + y) * w + x0) * 4;
    sub.setRange(y * sw * 4, (y + 1) * sw * 4, px, from);
  }
  gaussianBlur(sub, sw, sh, sigma);
  for (var y = b.top; y < b.bottom; y++) {
    final from = ((y - y0) * sw + (b.left - x0)) * 4;
    final to = (y * w + b.left) * 4;
    px.setRange(to, to + (b.right - b.left) * 4, sub, from);
  }
}

// ---------------------------------------------------------------------------
// Compositing
// ---------------------------------------------------------------------------

/// Composites [src] over [dst] at ([ox], [oy]) with straight-alpha "over"
/// blending, scaled by [opacity].
void blendOver(
  Uint8List dst,
  int dw,
  int dh,
  Uint8List src,
  int sw,
  int sh,
  int ox,
  int oy,
  double opacity,
) {
  final x0 = math.max(0, ox), y0 = math.max(0, oy);
  final x1 = math.min(dw, ox + sw), y1 = math.min(dh, oy + sh);
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final si = ((y - oy) * sw + (x - ox)) * 4;
      final sa = src[si + 3] / 255.0 * opacity;
      if (sa <= 0) continue;
      final di = (y * dw + x) * 4;
      final da = dst[di + 3] / 255.0;
      final outA = sa + da * (1 - sa);
      for (var c = 0; c < 3; c++) {
        dst[di + c] = clamp8(
          (src[si + c] * sa + dst[di + c] * da * (1 - sa)) / outA,
        );
      }
      dst[di + 3] = clamp8(outA * 255);
    }
  }
}

/// Composites the buffer over an opaque colour (for JPEG, which has no alpha).
void flattenOnto(Uint8List px, int argb) {
  final br = (argb >> 16) & 0xFF;
  final bg = (argb >> 8) & 0xFF;
  final bb = argb & 0xFF;
  for (var i = 0; i < px.length; i += 4) {
    final a = px[i + 3];
    if (a == 255) continue;
    final t = a / 255.0;
    px[i] = clamp8(px[i] * t + br * (1 - t));
    px[i + 1] = clamp8(px[i + 1] * t + bg * (1 - t));
    px[i + 2] = clamp8(px[i + 2] * t + bb * (1 - t));
    px[i + 3] = 255;
  }
}
