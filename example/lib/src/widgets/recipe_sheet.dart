import 'dart:convert';

import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'studio_widgets.dart';

Future<void> showRecipe(BuildContext context, ImagePipeline pipeline) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => RecipeSheet(pipeline: pipeline),
    );

class RecipeSheet extends StatelessWidget {
  const RecipeSheet({super.key, required this.pipeline});
  final ImagePipeline pipeline;

  @override
  Widget build(BuildContext context) {
    final json = const JsonEncoder.withIndent('  ').convert(pipeline.toJson());
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Your recipe',
                    style: Theme.of(context).textTheme.headlineMedium)),
            IconButton(
                tooltip: 'Close recipe',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 6),
          Text('A reusable sequence. Your photo stays out of the recipe.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                const Eyebrow('PROCESSING ORDER'),
                const SizedBox(height: 12),
                for (final (index, step) in pipeline.steps.indexed)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 30,
                                child: Text('${index + 1}'.padLeft(2, '0'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontSize: 12))),
                            Expanded(
                                child: Text(step,
                                    style: const TextStyle(fontSize: 13))),
                          ])),
                const SizedBox(height: 18),
                const Eyebrow('JSON'),
                const SizedBox(height: 12),
                StudioPanel(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                        width: double.infinity,
                        child: SelectableText(json,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.6)))),
              ]))),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: json));
                    if (context.mounted) showNotice(context, 'Recipe copied.');
                  } catch (_) {
                    if (context.mounted) {
                      showNotice(context,
                          'Could not copy. You can select the JSON instead.');
                    }
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy JSON'),
              )),
        ]),
      ),
    );
  }
}
