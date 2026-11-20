import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

import 'photo_controller.dart';

enum Adjustment {
  brightness('Brightness', -0.5, 0.5, 0),
  contrast('Contrast', 0.5, 1.5, 1),
  saturation('Saturation', 0, 2, 1),
  warmth('Warmth', -1, 1, 0),
  tint('Tint', -1, 1, 0),
  exposure('Exposure', -2, 2, 0);

  const Adjustment(this.label, this.min, this.max, this.neutral);
  final String label;
  final double min;
  final double max;
  final double neutral;

  String display(double value) {
    final amount = this == exposure ? value : (value - neutral) * 100;
    final number = amount.toStringAsFixed(this == exposure ? 1 : 0);
    return '${amount > 0 ? '+' : ''}$number${this == exposure ? ' EV' : ''}';
  }
}

enum StudioEffect {
  autoEnhance('Auto enhance', 'Balanced light & colour'),
  sharpen('Sharpen', 'Bring the details forward'),
  blur('Blur', 'A softer focus'),
  vignette('Vignette', 'Draw the eye inward'),
  grain('Grain', 'A little film texture'),
  painterly('Painterly', 'Kuwahara brushwork'),
  oilPaint('Oil paint', 'Rich, textured strokes'),
  watercolor('Watercolor', 'Soft washes of colour'),
  sketch('Sketch', 'Pencil on paper');

  const StudioEffect(this.label, this.description);
  final String label;
  final String description;

  ImagePipeline apply(ImagePipeline p) => switch (this) {
        autoEnhance => p.autoEnhance(),
        sharpen => p.sharpen(),
        blur => p.blur(2.5),
        vignette => p.vignette(strength: 0.45),
        grain => p.grain(amount: 0.12),
        painterly => p.kuwahara(radius: 4),
        oilPaint => p.oilPaint(radius: 3),
        watercolor => p.watercolor(radius: 4),
        sketch => p.sketch(),
      };
}

class EditorController extends PhotoController {
  EditorController(super.services);

  @override
  String get assetPath => 'assets/sample_image.jpg';
  @override
  String get sampleName => 'Valley light';

  FilterPreset? preset;
  final Map<Adjustment, double> _values = {};
  final Set<StudioEffect> _effects = {};
  PipelineResult? result;
  ImagePipeline? renderedRecipe;
  bool showComparison = true;

  double value(Adjustment adjustment) =>
      _values[adjustment] ?? adjustment.neutral;
  bool hasEffect(StudioEffect effect) => _effects.contains(effect);
  int get effectCount => _effects.length;

  ImagePipeline get adjustments {
    var p = const ImagePipeline();
    if (value(Adjustment.brightness) != 0) {
      p = p.brightness(value(Adjustment.brightness));
    }
    if (value(Adjustment.contrast) != 1) {
      p = p.contrast(value(Adjustment.contrast));
    }
    if (value(Adjustment.saturation) != 1) {
      p = p.saturation(value(Adjustment.saturation));
    }
    if (value(Adjustment.warmth) != 0) {
      p = p.temperature(value(Adjustment.warmth));
    }
    if (value(Adjustment.tint) != 0) p = p.tint(value(Adjustment.tint));
    return p;
  }

  ColorMatrix get previewMatrix =>
      (preset?.matrix ?? ColorMatrix.identity).then(adjustments.previewMatrix!);

  ImagePipeline get pipeline {
    var p = const ImagePipeline().downscale(2048);
    if (preset != null) {
      p = p.colorMatrix(preset!.matrix, label: 'preset:${preset!.id}');
    }
    p = p.then(adjustments);
    if (value(Adjustment.exposure) != 0) {
      p = p.exposure(value(Adjustment.exposure));
    }
    if ((preset?.vignette ?? 0) > 0) {
      p = p.vignette(strength: preset!.vignette, radius: 0.45);
    }
    if ((preset?.grain ?? 0) > 0) p = p.grain(amount: preset!.grain);
    for (final effect in StudioEffect.values) {
      if (_effects.contains(effect)) p = effect.apply(p);
    }
    return p;
  }

  void _edited() {
    result = null;
    renderedRecipe = null;
    changed();
  }

  void selectPreset(FilterPreset? selected) {
    if (busy) return;
    preset = selected;
    _edited();
  }

  void adjust(Adjustment adjustment, double amount) {
    if (busy) return;
    _values[adjustment] = amount;
    _edited();
  }

  void toggleEffect(StudioEffect effect) {
    if (busy) return;
    if (!_effects.remove(effect)) _effects.add(effect);
    _edited();
  }

  void compare(bool enabled) {
    showComparison = enabled;
    changed();
  }

  @override
  void reset() {
    preset = null;
    _values.clear();
    _effects.clear();
    showComparison = true;
    _edited();
  }

  Future<void> render() async {
    if (photo == null) return;
    await perform('Rendering your look…',
        'This render did not finish. Try fewer effects or a smaller photo.',
        () async {
      final recipe = pipeline;
      final output = await services.process(recipe, photo!.bytes);
      result = output;
      renderedRecipe = recipe;
      showComparison = true;
    });
  }

  Future<void> export() async {
    if (result != null) await exportBytes(result!.bytes, 'toolkit-studio');
  }
}
