import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/material.dart';

import '../state/editor_controller.dart';
import '../widgets/editor_controls.dart';
import '../widgets/preset_strip.dart';
import '../widgets/studio_widgets.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key, required this.controller});
  final EditorController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final photo = controller.photo;
          final result = controller.result;
          final preview = PreviewCanvas(
            controller: controller,
            status: result == null ? 'LIVE PREVIEW' : 'RENDERED',
            trailing: result == null
                ? null
                : IconButton(
                    tooltip: controller.showComparison
                        ? 'Show result only'
                        : 'Compare before and after',
                    onPressed: () =>
                        controller.compare(!controller.showComparison),
                    icon: Icon(
                        controller.showComparison
                            ? Icons.compare
                            : Icons.compare_outlined,
                        size: 18),
                  ),
            footer: Text(
              result == null
                  ? photo == null
                      ? 'Your next favourite photo starts here.'
                      : '${photo.width}×${photo.height} · Live colour · Render to compare'
                  : renderStats(result, controller.services.runsInBackground),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: photo == null
                  ? const SizedBox.shrink()
                  : result != null
                      ? controller.showComparison
                          ? ComparePhoto(
                              key: ObjectKey(result),
                              before: photo.bytes,
                              after: result.bytes)
                          : PhotoImage(result.bytes,
                              key: const ValueKey('result-only'))
                      : ColorFiltered(
                          key: const ValueKey('live-colour-preview'),
                          colorFilter: controller.previewMatrix.toColorFilter(),
                          child: PhotoImage(photo.bytes),
                        ),
            ),
          );
          final heading = PageHeading(
            title: 'Find your light.',
            subtitle: 'A fresh perspective, one adjustment at a time.',
            action: OutlinedButton.icon(
              onPressed: controller.busy
                  ? null
                  : () => runAction(context, controller, controller.pickPhoto),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Pick photo'),
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
                              child: Column(children: [
                            Expanded(child: preview),
                            const SizedBox(height: 16),
                            PresetStrip(controller: controller),
                          ])),
                          const SizedBox(width: 24),
                          SizedBox(
                              width: 360,
                              child: EditorControls(
                                  controller: controller, wide: true)),
                        ])),
                  ]),
            );
          }
          return SingleChildScrollView(
            key: const PageStorageKey('studio-scroll'),
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              heading,
              SizedBox(
                  height: MediaQuery.sizeOf(context).height < 650 ? 280 : 330,
                  child: preview),
              const SizedBox(height: 10),
              PresetStrip(controller: controller),
              const SizedBox(height: 20),
              EditorControls(controller: controller, wide: false),
              const SizedBox(height: 16),
            ]),
          );
        },
      );
}
