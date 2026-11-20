import 'dart:ui' show ColorFilter;

import '../engine/color_matrix.dart';
import '../engine/pipeline.dart';
import '../engine/presets.dart';

/// Bridges engine colour matrices to Flutter's GPU colour filters.
extension ColorMatrixFilter on ColorMatrix {
  /// A `ColorFilter` that renders this matrix on the GPU, for live preview
  /// with `ColorFiltered`. Matches the exported pixels to within rounding.
  ColorFilter toColorFilter() => ColorFilter.matrix(values);
}

/// Live-preview helpers for presets.
extension FilterPresetPreview on FilterPreset {
  /// The colour part of this preset as a GPU `ColorFilter`. Vignette and
  /// grain appear only on export.
  ColorFilter toColorFilter() => ColorFilter.matrix(matrix.values);
}

/// Live-preview helpers for pipelines.
extension ImagePipelinePreview on ImagePipeline {
  /// A GPU `ColorFilter` equivalent to this pipeline, or `null` if it has
  /// any step that is not a pure colour transform.
  ColorFilter? toColorFilter() {
    final m = previewMatrix;
    return m == null ? null : ColorFilter.matrix(m.values);
  }
}
