import 'dart:typed_data';

import 'color_matrix.dart';
import 'options.dart';
import 'pipeline.dart';

/// A named, ready-made look.
///
/// Every preset is a colour matrix plus optional vignette and grain. The
/// colour part ([matrix]) can be previewed live with
/// `ColorFilter.matrix(preset.matrix.values)`, so a filter strip can show
/// every look at 60 fps; [pipeline] renders the full look on export.
final class FilterPreset {
  FilterPreset._(
    this.id,
    this.name,
    this.matrix, {
    this.vignette = 0,
    this.grain = 0,
  });

  /// Stable identifier, safe to persist.
  final String id;

  /// Display name.
  final String name;

  /// The colour transform, for live preview and export alike.
  final ColorMatrix matrix;

  /// Vignette strength applied on export (`0` for none).
  final double vignette;

  /// Grain amount applied on export (`0` for none).
  final double grain;

  /// The full look as a pipeline. Compose it with other steps:
  /// `const ImagePipeline().downscale(2048).then(FilterPreset.noir.pipeline)`.
  ImagePipeline get pipeline {
    var p = const ImagePipeline().colorMatrix(matrix, label: 'preset:$id');
    if (vignette > 0) p = p.vignette(strength: vignette, radius: 0.45);
    if (grain > 0) p = p.grain(amount: grain);
    return p;
  }

  /// Renders this look onto [bytes].
  Future<Uint8List> apply(
    Uint8List bytes, {
    OutputFormat output = const OutputFormat.original(),
  }) => pipeline.apply(bytes, output: output);

  /// Punchy colour and contrast.
  static final FilterPreset vivid = FilterPreset._(
    'vivid',
    'Vivid',
    _chain([ColorMatrix.contrast(1.1), ColorMatrix.saturation(1.35)]),
  );

  /// High-contrast black and white with a dark edge.
  static final FilterPreset noir = FilterPreset._(
    'noir',
    'Noir',
    _chain([
      ColorMatrix.grayscale(),
      ColorMatrix.contrast(1.35),
      ColorMatrix.brightness(-0.03),
    ]),
    vignette: 0.35,
  );

  /// Warm, glowing late-afternoon light.
  static final FilterPreset goldenHour = FilterPreset._(
    'goldenHour',
    'Golden Hour',
    _chain([
      ColorMatrix.temperature(0.5),
      ColorMatrix.saturation(1.15),
      ColorMatrix.contrast(1.05),
      ColorMatrix.brightness(0.03),
    ]),
  );

  /// Lifted blacks, muted colour, light grain.
  static final FilterPreset fadedFilm = FilterPreset._(
    'fadedFilm',
    'Faded Film',
    _chain([
      ColorMatrix.contrast(0.82),
      ColorMatrix.brightness(0.07),
      ColorMatrix.saturation(0.8),
      ColorMatrix.sepia(0.12),
    ]),
    grain: 0.05,
  );

  /// Cool, clean, crisp.
  static final FilterPreset arctic = FilterPreset._(
    'arctic',
    'Arctic',
    _chain([
      ColorMatrix.temperature(-0.55),
      ColorMatrix.saturation(0.9),
      ColorMatrix.brightness(0.04),
      ColorMatrix.contrast(1.05),
    ]),
  );

  /// Warm, dusty and soft, like a West African dry-season haze.
  static final FilterPreset harmattan = FilterPreset._(
    'harmattan',
    'Harmattan',
    _chain([
      ColorMatrix.temperature(0.35),
      ColorMatrix.sepia(0.18),
      ColorMatrix.saturation(0.78),
      ColorMatrix.contrast(0.9),
      ColorMatrix.brightness(0.05),
    ]),
  );

  /// Low contrast, soft shadows.
  static final FilterPreset matte = FilterPreset._(
    'matte',
    'Matte',
    _chain([
      ColorMatrix.contrast(0.8),
      ColorMatrix.brightness(0.06),
      ColorMatrix.saturation(0.92),
    ]),
  );

  /// Clean neutral black and white.
  static final FilterPreset mono = FilterPreset._(
    'mono',
    'Mono',
    _chain([ColorMatrix.grayscale(), ColorMatrix.contrast(1.12)]),
  );

  /// Magenta-violet evening tones.
  static final FilterPreset dusk = FilterPreset._(
    'dusk',
    'Dusk',
    _chain([
      ColorMatrix.hueRotate(-8),
      ColorMatrix.temperature(0.2),
      ColorMatrix.tint(0.18),
      ColorMatrix.contrast(1.08),
    ]),
    vignette: 0.25,
  );

  /// Crisp contrast with a cool metallic edge.
  static final FilterPreset chrome = FilterPreset._(
    'chrome',
    'Chrome',
    _chain([
      ColorMatrix.contrast(1.22),
      ColorMatrix.saturation(1.12),
      ColorMatrix.temperature(-0.12),
    ]),
  );

  /// Lush greens.
  static final FilterPreset verdant = FilterPreset._(
    'verdant',
    'Verdant',
    _chain([
      ColorMatrix.tint(-0.3),
      ColorMatrix.saturation(1.2),
      ColorMatrix.hueRotate(6),
      ColorMatrix.contrast(1.05),
    ]),
  );

  /// Aged print: sepia, soft contrast, vignette and grain.
  static final FilterPreset vintage = FilterPreset._(
    'vintage',
    'Vintage',
    _chain([
      ColorMatrix.sepia(0.45),
      ColorMatrix.contrast(0.9),
      ColorMatrix.brightness(0.03),
    ]),
    vignette: 0.4,
    grain: 0.07,
  );

  /// Every built-in preset, in display order.
  static final List<FilterPreset> all = List.unmodifiable([
    vivid,
    goldenHour,
    harmattan,
    fadedFilm,
    matte,
    vintage,
    dusk,
    arctic,
    chrome,
    verdant,
    mono,
    noir,
  ]);

  /// Looks up a preset by [id], or `null`.
  static FilterPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static ColorMatrix _chain(List<ColorMatrix> steps) =>
      steps.fold(ColorMatrix.identity, (acc, m) => acc.then(m));

  @override
  String toString() => 'FilterPreset($id)';
}
