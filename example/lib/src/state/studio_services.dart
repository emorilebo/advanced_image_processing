import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'storage_stub.dart' if (dart.library.io) 'storage_io.dart' as storage;

class PickedPhoto {
  const PickedPhoto(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

class StudioServices {
  bool get detectionSupported =>
      AdvancedImageProcessingToolkit.isDetectionSupported;
  bool get exportSupported => !kIsWeb;
  bool get runsInBackground => AdvancedImageProcessingToolkit.runsInBackground;

  Future<Uint8List> loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<PickedPhoto?> pickPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    return photo == null
        ? null
        : PickedPhoto(await photo.readAsBytes(), photo.name);
  }

  Future<PipelineResult> process(ImagePipeline pipeline, Uint8List bytes) =>
      pipeline.run(bytes,
          output: const OutputFormat.jpeg(), metadata: MetadataPolicy.strip);

  Future<RedactionResult> redact(
          Uint8List bytes, Set<DetectorType> targets, RedactionStyle style) =>
      storage.redact(bytes, targets, style);

  Future<String> save(Uint8List bytes, String prefix) =>
      storage.save(bytes, prefix);

  Future<String> platformVersion() async =>
      await AdvancedImageProcessingToolkit.getPlatformVersion() ??
      'Unavailable on this device';
}
