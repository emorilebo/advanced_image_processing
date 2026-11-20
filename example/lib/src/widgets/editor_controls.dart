import 'package:flutter/material.dart';

import '../state/editor_controller.dart';
import 'recipe_sheet.dart';
import 'studio_widgets.dart';

class EditorControls extends StatefulWidget {
  const EditorControls(
      {super.key, required this.controller, required this.wide});
  final EditorController controller;
  final bool wide;
  @override
  State<EditorControls> createState() => _EditorControlsState();
}

class _EditorControlsState extends State<EditorControls> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final editor = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('Make it yours.',
                style: Theme.of(context).textTheme.titleLarge)),
        IconButton(
            tooltip: 'Reset all edits',
            onPressed: editor.busy ? null : editor.reset,
            icon: const Icon(Icons.restart_alt, size: 20)),
      ]),
      const SizedBox(height: 10),
      SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                  value: 0,
                  label: Text('Adjust'),
                  icon: Icon(Icons.tune, size: 17)),
              ButtonSegment(
                  value: 1,
                  label: Text(editor.effectCount == 0
                      ? 'Effects'
                      : 'Effects (${editor.effectCount})'),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 17)),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) =>
                setState(() => _tab = selection.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          )),
      const SizedBox(height: 24),
      if (_tab == 0) ...[
        const Eyebrow('LIGHT & COLOUR'),
        const SizedBox(height: 14),
        for (final adjustment in Adjustment.values)
          _AdjustmentSlider(controller: editor, adjustment: adjustment),
        const SizedBox(height: 4),
        Text(
            'Colour changes are live. Exposure, preset grain and vignette appear when you render.',
            style: Theme.of(context).textTheme.bodySmall),
      ] else ...[
        const Eyebrow('A FINISHING TOUCH'),
        const SizedBox(height: 8),
        Text('Select effects, then Render to see the result.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        for (final effect in StudioEffect.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: editor.hasEffect(effect)
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: CheckboxListTile(
                value: editor.hasEffect(effect),
                onChanged: editor.busy || editor.photo == null
                    ? null
                    : (_) => editor.toggleEffect(effect),
                title: Text(effect.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(effect.description,
                    style: Theme.of(context).textTheme.bodySmall),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                dense: true,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    ]);
    final actions =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: FilledButton.icon(
          key: const ValueKey('render-button'),
          onPressed: editor.busy || editor.photo == null
              ? null
              : () => runAction(context, editor, editor.render),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Render'),
        )),
        const SizedBox(width: 10),
        ExportButton(
            controller: editor,
            ready: editor.result != null,
            onExport: editor.export),
      ]),
      const SizedBox(height: 4),
      TextButton.icon(
        onPressed: editor.photo == null
            ? null
            : () =>
                showRecipe(context, editor.renderedRecipe ?? editor.pipeline),
        icon: const Icon(Icons.data_object, size: 16),
        label: const Text('Recipe'),
      ),
    ]);
    return StudioPanel(
      child: widget.wide
          ? Column(children: [
              Expanded(child: SingleChildScrollView(child: content)),
              const SizedBox(height: 16),
              actions
            ])
          : Column(children: [content, const SizedBox(height: 24), actions]),
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({required this.controller, required this.adjustment});
  final EditorController controller;
  final Adjustment adjustment;

  @override
  Widget build(BuildContext context) {
    final value = controller.value(adjustment);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        Row(children: [
          Expanded(
              child:
                  Text(adjustment.label, style: const TextStyle(fontSize: 13))),
          if (adjustment == Adjustment.exposure) ...[
            Text('ON RENDER',
                style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 0.7,
                    color: colors.onSurfaceVariant)),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5)),
            child: Text(adjustment.display(value),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: value == adjustment.neutral
                        ? colors.onSurfaceVariant
                        : colors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]),
        Semantics(
          label: adjustment.label,
          child: Slider(
            key: ValueKey('slider-${adjustment.name}'),
            value: value,
            min: adjustment.min,
            max: adjustment.max,
            divisions: 100,
            label: adjustment.display(value),
            semanticFormatterCallback: adjustment.display,
            onChanged: controller.busy || controller.photo == null
                ? null
                : (value) => controller.adjust(adjustment, value),
          ),
        ),
      ]),
    );
  }
}
