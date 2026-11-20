import 'dart:math' as math;

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

import 'photo_controller.dart';

class PrivacyController extends PhotoController {
  PrivacyController(super.services);

  @override
  String get assetPath => 'assets/people_sample.jpg';
  @override
  String get sampleName => 'An afternoon in Lagos';

  final Set<DetectorType> _targets = {DetectorType.face};
  RedactionStyle style = RedactionStyle.pixelate;
  RedactionResult? result;
  bool manual = false;
  bool showDetections = false;

  bool targets(DetectorType type) => _targets.contains(type);
  bool get canRedact => photo != null && !busy && _targets.isNotEmpty;

  String get resultLabel {
    if (manual) return '1 demo region pixelated · no automatic detection';
    final regions = result?.regions ?? [];
    if (regions.isEmpty) {
      return 'No regions found. Check the photo before sharing.';
    }
    final faces = regions.where((d) => d.type == DetectorType.face).length;
    final texts = regions.where((d) => d.type == DetectorType.text).length;
    return '${[
      if (faces > 0) '$faces ${faces == 1 ? 'face' : 'faces'}',
      if (texts > 0) '$texts text ${texts == 1 ? 'block' : 'blocks'}',
    ].join(', ')} hidden';
  }

  void toggleTarget(DetectorType type) {
    if (busy) return;
    if (!_targets.remove(type)) _targets.add(type);
    reset();
  }

  void setStyle(RedactionStyle selected) {
    if (busy) return;
    style = selected;
    reset();
  }

  void viewDetections(bool show) {
    showDetections = show;
    changed();
  }

  @override
  void reset() {
    result = null;
    manual = false;
    showDetections = false;
    changed();
  }

  Future<void> redact() async {
    if (!canRedact || !services.detectionSupported) return;
    await perform('Finding faces & text…',
        'Detection could not finish. Please try again on Android or iOS.',
        () async {
      result = await services.redact(photo!.bytes, Set.of(_targets), style);
      manual = false;
      showDetections = false;
      if (result!.regions.isEmpty) {
        notice =
            'No regions found. The detector may still be downloading; review the photo and try again.';
      }
    });
  }

  Future<void> tryManual() async {
    if (photo == null) return;
    await perform('Pixelating the demo region…',
        'The demo could not finish. Try another photo.', () async {
      final source = photo!;
      final recipe = const ImagePipeline().redact([
        math.Rectangle<double>(source.width * 0.47, source.height * 0.32,
            source.width * 0.19, source.height * 0.27),
      ],
          style: RedactionStyle.pixelate,
          blockSize: math.max(4, (source.width / 45).round()));
      final output = await services.process(recipe, source.bytes);
      result = RedactionResult(
          bytes: output.bytes,
          width: output.width,
          height: output.height,
          regions: const []);
      manual = true;
      showDetections = false;
    });
  }

  Future<void> export() async {
    if (result != null) await exportBytes(result!.bytes, 'toolkit-private');
  }
}
