/// The pure-Dart image engine, without any Flutter dependency.
///
/// Import this from your own isolates, from a Dart server, or from CLI tools.
/// Flutter apps can import the main library instead, which re-exports all
/// of this.
///
/// `ImagePipeline.custom` steps receive a `package:image` `Image`; add
/// `image` to your own pubspec to write one.
library;

export 'src/engine/color_matrix.dart';
export 'src/engine/cube_lut.dart';
export 'src/engine/errors.dart';
export 'src/engine/options.dart';
export 'src/engine/pipeline.dart'
    show ImagePipeline, PipelineResult, defaultMaxInputPixels;
export 'src/engine/presets.dart';
