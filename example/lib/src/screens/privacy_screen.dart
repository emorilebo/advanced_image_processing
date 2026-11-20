import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/material.dart';

import '../state/privacy_controller.dart';
import '../widgets/studio_widgets.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.controller});
  final PrivacyController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final photo = controller.photo;
          final result = controller.result;
          final preview = PreviewCanvas(
            controller: controller,
            status: result == null
                ? 'ORIGINAL'
                : controller.manual
                    ? 'MANUAL DEMO'
                    : 'REVIEW',
            footer: Text(
                result == null
                    ? 'Keep the moment. Protect the people.'
                    : controller.resultLabel,
                style: Theme.of(context).textTheme.bodySmall),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: photo == null
                  ? const SizedBox.shrink()
                  : result == null
                      ? PhotoImage(photo.bytes,
                          key: const ValueKey('privacy-original'))
                      : controller.showDetections
                          ? DetectionOverlay(
                              key: const ValueKey('detections'),
                              imageSize: Size(photo.width.toDouble(),
                                  photo.height.toDouble()),
                              detections: result.regions,
                              child: PhotoImage(photo.bytes),
                            )
                          : ComparePhoto(
                              key: ObjectKey(result),
                              before: photo.bytes,
                              after: result.bytes),
            ),
          );
          final heading = PageHeading(
            title: 'Share with care.',
            subtitle:
                'On-device face & text redaction. EXIF and GPS stripped on export.',
            action: OutlinedButton.icon(
              onPressed: controller.busy
                  ? null
                  : () => runAction(context, controller, controller.pickPhoto),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Pick photo'),
            ),
          );
          final controls = _PrivacyControls(controller: controller);
          final views = result == null || controller.manual
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('Before / After'),
                          icon: Icon(Icons.compare, size: 18)),
                      ButtonSegment(
                          value: true,
                          label: Text('Detections'),
                          icon: Icon(Icons.face_retouching_natural, size: 18)),
                    ],
                    selected: {controller.showDetections},
                    onSelectionChanged: (value) =>
                        controller.viewDetections(value.first),
                  ),
                );
          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    Expanded(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Expanded(
                              child: Column(
                                  children: [Expanded(child: preview), views])),
                          const SizedBox(width: 24),
                          SizedBox(
                              width: 360,
                              child: SingleChildScrollView(child: controls)),
                        ])),
                  ]),
            );
          }
          return SingleChildScrollView(
            key: const PageStorageKey('privacy-scroll'),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              heading,
              SizedBox(height: 330, child: preview),
              views,
              const SizedBox(height: 20),
              controls,
              const SizedBox(height: 16),
            ]),
          );
        },
      );
}

class _PrivacyControls extends StatelessWidget {
  const _PrivacyControls({required this.controller});
  final PrivacyController controller;

  @override
  Widget build(BuildContext context) {
    final supported = controller.services.detectionSupported;
    final colors = Theme.of(context).colorScheme;
    return StudioPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: colors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.shield_outlined, color: colors.secondary, size: 28),
      ),
      const SizedBox(height: 20),
      Text(supported ? 'A little more privacy.' : 'Private by design.',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
          supported
              ? 'Choose what to hide. Everything is processed on this device.'
              : 'Automatic face and text detection runs on Android and iOS. Explore a manual redaction here.',
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
      const Eyebrow('WHAT TO HIDE'),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final target in [DetectorType.face, DetectorType.text])
          FilterChip(
            label: Text(target == DetectorType.face ? 'Faces' : 'Text'),
            avatar: Icon(
                target == DetectorType.face
                    ? Icons.face_outlined
                    : Icons.text_fields,
                size: 17),
            selected: controller.targets(target),
            onSelected: controller.busy || !supported
                ? null
                : (_) => controller.toggleTarget(target),
          ),
      ]),
      const SizedBox(height: 24),
      const Eyebrow('REDACTION STYLE'),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: SegmentedButton<RedactionStyle>(
            showSelectedIcon: false,
            style: const ButtonStyle(
                padding:
                    WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
                textStyle: WidgetStatePropertyAll(
                    TextStyle(fontFamily: 'Inter', fontSize: 12))),
            segments: const [
              ButtonSegment(
                  value: RedactionStyle.pixelate, label: Text('Pixelate')),
              ButtonSegment(value: RedactionStyle.blur, label: Text('Blur')),
              ButtonSegment(
                  value: RedactionStyle.fill, label: Text('Solid fill')),
            ],
            selected: {controller.style},
            onSelectionChanged: controller.busy || !supported
                ? null
                : (value) => controller.setStyle(value.first),
          )),
      const SizedBox(height: 14),
      if (controller.targets(DetectorType.text) &&
          controller.style == RedactionStyle.pixelate)
        Text('Pixelated text can be recovered; use Solid fill.',
            style: TextStyle(fontSize: 12, height: 1.5, color: colors.primary))
      else
        Text(
            supported
                ? 'Review every result before sharing.'
                : 'The demo pixelates one fixed region. It does not find faces or text.',
            style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 20),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('redact-button'),
            onPressed: controller.busy ||
                    controller.photo == null ||
                    (supported && !controller.canRedact)
                ? null
                : () => runAction(context, controller,
                    supported ? controller.redact : controller.tryManual),
            icon: Icon(
                supported ? Icons.shield_outlined : Icons.grid_on_outlined,
                size: 18),
            label: Text(supported ? 'Redact' : 'Try manual redaction'),
          )),
      const SizedBox(height: 10),
      SizedBox(
          width: double.infinity,
          child: ExportButton(
              controller: controller,
              ready: controller.result != null,
              onExport: controller.export)),
      if (controller.result != null) ...[
        const SizedBox(height: 12),
        Text(controller.resultLabel,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ]));
  }
}
