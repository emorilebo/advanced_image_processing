import 'dart:io';
import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:path_provider/path_provider.dart';

Future<String> save(Uint8List bytes, String prefix) async {
  final directory = await getApplicationDocumentsDirectory();
  final name = '$prefix-${DateTime.now().microsecondsSinceEpoch}.jpg';
  await File('${directory.path}/$name').writeAsBytes(bytes, flush: true);
  return name;
}

Future<RedactionResult> redact(
    Uint8List bytes, Set<DetectorType> targets, RedactionStyle style) async {
  final temporary = await getTemporaryDirectory();
  final directory =
      await Directory('${temporary.path}/toolkit-studio-').createTemp();
  try {
    final file = await File('${directory.path}/source.jpg')
        .writeAsBytes(bytes, flush: true);
    return await ObjectRecognition.redactFromPath(
      file.path,
      targets: targets,
      style: style,
      output: const OutputFormat.jpeg(),
      metadata: MetadataPolicy.strip,
    );
  } finally {
    try {
      await ObjectRecognition.dispose();
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
