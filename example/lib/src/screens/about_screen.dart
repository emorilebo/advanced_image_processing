import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/material.dart';

import '../state/studio_services.dart';
import '../widgets/studio_widgets.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.services});
  final StudioServices services;
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<String> _platform = _getPlatform();

  Future<String> _getPlatform() async {
    try {
      return await widget.services.platformVersion();
    } catch (_) {
      return 'Unavailable on this device';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding:
          EdgeInsets.all(MediaQuery.sizeOf(context).width >= 900 ? 40 : 20),
      child: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          const Eyebrow('SMALL TOOLKIT. BIG POSSIBILITIES.'),
          const SizedBox(height: 20),
          Text('Good photos.\nEntirely your own.',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontSize: 42)),
          const SizedBox(height: 16),
          Text(
              'Toolkit Studio is a space to explore light, colour and texture — with image processing that stays on your device.',
              style: TextStyle(
                  color: colors.onSurfaceVariant, fontSize: 15, height: 1.7)),
          const SizedBox(height: 28),
          StudioPanel(
              child: Column(children: [
            const _InfoRow(
                label: 'Toolkit version',
                value: AdvancedImageProcessingToolkit.version),
            const Divider(height: 28),
            FutureBuilder<String>(
                future: _platform,
                builder: (context, snapshot) => _InfoRow(
                    label: 'Platform', value: snapshot.data ?? 'Checking…')),
            const Divider(height: 28),
            _InfoRow(
                label: 'Pipeline execution',
                value: widget.services.runsInBackground
                    ? 'Background isolate'
                    : 'Main thread (web)'),
            const Divider(height: 28),
            _InfoRow(
                label: 'Face & text detection',
                value: widget.services.detectionSupported
                    ? 'Available on this device'
                    : 'Android & iOS'),
          ])),
          const SizedBox(height: 28),
          const Eyebrow('IN THE TOOLKIT'),
          const SizedBox(height: 16),
          const Wrap(spacing: 10, runSpacing: 10, children: [
            _Capability(Icons.palette_outlined, '12 signature looks'),
            _Capability(Icons.tune, 'Live colour adjustments'),
            _Capability(Icons.auto_awesome_outlined, 'Tone & artistic effects'),
            _Capability(Icons.crop_rotate, 'Crop, resize & geometry'),
            _Capability(Icons.shield_outlined, 'Face & text redaction'),
            _Capability(Icons.data_object, 'Portable JSON recipes'),
          ]),
          const SizedBox(height: 32),
          const Eyebrow('BUILT WITH ADVANCED IMAGE PROCESSING TOOLKIT'),
          const SizedBox(height: 12),
          const SelectableText(
              'pub.dev/packages/advanced_image_processing_toolkit',
              style: TextStyle(fontSize: 13, height: 1.7)),
          const SizedBox(height: 6),
          const SelectableText('github.com/emorilebo/advanced_image_processing',
              style: TextStyle(fontSize: 13, height: 1.7)),
          const SizedBox(height: 32),
        ]),
      )),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(width: 16),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
      ]);
}

class _Capability extends StatelessWidget {
  const _Capability(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
      avatar:
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
      label: Text(label));
}
