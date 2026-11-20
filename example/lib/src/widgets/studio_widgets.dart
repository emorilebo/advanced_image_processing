import 'dart:typed_data';

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/material.dart';

import '../state/photo_controller.dart';

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> runAction(BuildContext context, PhotoController controller,
    Future<void> Function() action) async {
  await action();
  final notice = controller.takeNotice();
  if (context.mounted && notice != null) showNotice(context, notice);
}

class StudioPanel extends StatelessWidget {
  const StudioPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: child,
      );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelSmall);
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.active = false});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = active ? colors.secondary : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (active) ...[
          Icon(Icons.circle, size: 5, color: color),
          const SizedBox(width: 6)
        ],
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: color)),
      ]),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.action});
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Padding(
      padding: EdgeInsets.only(bottom: wide ? 26 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: wide
                      ? Theme.of(context).textTheme.headlineLarge
                      : Theme.of(context).textTheme.headlineMedium)),
          const SizedBox(width: 12),
          action,
        ]),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class PhotoImage extends StatelessWidget {
  const PhotoImage(this.bytes,
      {super.key, this.thumbnail = false, this.label = 'Photo preview'});
  final Uint8List bytes;
  final bool thumbnail;
  final String label;

  @override
  Widget build(BuildContext context) => Image.memory(
        bytes,
        fit: thumbnail ? BoxFit.cover : BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: thumbnail ? 160 : null,
        gaplessPlayback: true,
        semanticLabel: label,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
}

class ComparePhoto extends StatelessWidget {
  const ComparePhoto({super.key, required this.before, required this.after});
  final Uint8List before;
  final Uint8List after;

  @override
  Widget build(BuildContext context) => ImageCompareSlider(
        before: PhotoImage(before),
        after: PhotoImage(after),
        beforeLabel: const _CompareLabel('Before'),
        afterLabel: const _CompareLabel('After'),
      );
}

class _CompareLabel extends StatelessWidget {
  const _CompareLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xCC15171C),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      );
}

class PreviewCanvas extends StatelessWidget {
  const PreviewCanvas(
      {super.key,
      required this.controller,
      required this.child,
      required this.status,
      required this.footer,
      this.trailing});
  final PhotoController controller;
  final Widget child;
  final String status;
  final Widget footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = controller.photo;
    return StudioPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(children: [
              Icon(Icons.image_outlined,
                  size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      controller.filename.isEmpty
                          ? 'Your canvas'
                          : controller.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(width: 8),
              StatusBadge(status, active: photo != null),
              ?trailing,
            ]),
          ),
          const Divider(),
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                )
              else if (!controller.busy)
                Center(
                    child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.image_outlined, size: 32),
                    const SizedBox(height: 12),
                    Text(controller.error ?? 'A new perspective starts here.',
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: () => runAction(
                            context, controller, controller.loadSample),
                        child: const Text('Open sample')),
                  ]),
                )),
              if (controller.busy)
                ColoredBox(
                  color: colors.surface.withValues(alpha: 0.82),
                  child: Center(
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(height: 16),
                      Text(controller.busyLabel!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (!controller.services.runsInBackground) ...[
                        const SizedBox(height: 6),
                        Text('This tab may pause while processing.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center),
                      ],
                    ]),
                  )),
                ),
            ]),
          ),
          const Divider(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(alignment: Alignment.centerLeft, child: footer)),
        ]),
      ),
    );
  }
}

class ExportButton extends StatelessWidget {
  const ExportButton(
      {super.key,
      required this.controller,
      required this.ready,
      required this.onExport});
  final PhotoController controller;
  final bool ready;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: !controller.services.exportSupported
            ? 'File export is available in the mobile and desktop app.'
            : !ready
                ? 'Render a result to export.'
                : 'Save to app documents',
        child: OutlinedButton.icon(
          onPressed:
              ready && !controller.busy && controller.services.exportSupported
                  ? () => runAction(context, controller, onExport)
                  : null,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Export'),
        ),
      );
}

String renderStats(PipelineResult result, bool background) =>
    '${result.width}×${result.height} · ${result.format.name.toUpperCase()} · ${(result.bytes.length / 1024).round()} KB · ${result.processingTime.inMilliseconds} ms · ${background ? 'background isolate' : 'main thread (web)'}';
