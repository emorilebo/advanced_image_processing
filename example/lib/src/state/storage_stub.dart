import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

Future<String> save(Uint8List bytes, String prefix) async =>
    throw UnsupportedError('File export is available in the native app.');

Future<RedactionResult> redact(Uint8List bytes, Set<DetectorType> targets,
        RedactionStyle style) async =>
    throw UnsupportedError('Automatic detection requires Android or iOS.');
