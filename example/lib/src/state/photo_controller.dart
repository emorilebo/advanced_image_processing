import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/foundation.dart';

import 'studio_services.dart';

abstract class PhotoController extends ChangeNotifier {
  PhotoController(this.services);
  final StudioServices services;
  PipelineResult? photo;
  String filename = '';
  String? error;
  String? notice;
  String? busyLabel;
  bool _disposed = false;

  bool get busy => busyLabel != null;
  String get assetPath;
  String get sampleName;

  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> perform(
      String label, String failure, AsyncCallback action) async {
    if (busy || _disposed) return;
    busyLabel = label;
    error = null;
    notice = null;
    changed();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (_disposed) return;
      await action();
    } catch (_) {
      error = failure;
      notice = failure;
    } finally {
      busyLabel = null;
      changed();
    }
  }

  Future<void> loadSample() => perform('Opening your canvas…',
          'This sample could not be opened. Please try again.', () async {
        await _replace(await services.loadAsset(assetPath), sampleName);
      });

  Future<void> pickPhoto() => perform('Opening photo…',
          'We could not open that photo. Try a JPEG or PNG from your gallery.',
          () async {
        final picked = await services.pickPhoto();
        if (picked != null) await _replace(picked.bytes, picked.name);
      });

  Future<void> _replace(Uint8List bytes, String name) async {
    final prepared =
        await services.process(const ImagePipeline().downscale(2048), bytes);
    photo = prepared;
    filename = name;
    reset();
  }

  void reset();

  Future<void> exportBytes(Uint8List bytes, String prefix) => perform(
          'Saving photo…', 'The photo could not be saved. Please try again.',
          () async {
        final name = await services.save(bytes, prefix);
        notice = 'Saved $name to app documents.';
      });

  String? takeNotice() {
    final value = notice;
    notice = null;
    return value;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
