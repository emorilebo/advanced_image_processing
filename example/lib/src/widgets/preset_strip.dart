import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/editor_controller.dart';
import 'studio_widgets.dart';

class PresetStrip extends StatefulWidget {
  const PresetStrip({super.key, required this.controller});
  final EditorController controller;
  @override
  State<PresetStrip> createState() => _PresetStripState();
}

class _PresetStripState extends State<PresetStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double offset) {
    _scroll.animateTo(
        (_scroll.offset + offset).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.controller;
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Eyebrow('THE LOOKS'),
        const SizedBox(width: 12),
        Expanded(
            child: Text(editor.preset?.name ?? 'Original',
                style: Theme.of(context).textTheme.bodySmall)),
        IconButton(
            tooltip: 'Previous looks',
            onPressed: () => _move(-300),
            icon: const Icon(Icons.chevron_left, size: 20),
            visualDensity: VisualDensity.compact),
        IconButton(
            tooltip: 'More looks',
            onPressed: () => _move(300),
            icon: const Icon(Icons.chevron_right, size: 20),
            visualDensity: VisualDensity.compact),
      ]),
      SizedBox(
        height: 108,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: FilterPreset.all.length + 1,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final preset = index == 0 ? null : FilterPreset.all[index - 1];
            final selected = editor.preset == preset;
            final name = preset?.name ?? 'Original';
            return Semantics(
              button: true,
              selected: selected,
              label: '$name preset',
              child: Tooltip(
                message: name,
                child: InkWell(
                  key: ValueKey('preset-${preset?.id ?? 'original'}'),
                  borderRadius: BorderRadius.circular(13),
                  onTap: editor.busy || editor.photo == null
                      ? null
                      : () {
                          editor.selectPreset(preset);
                          if (!kIsWeb &&
                              (defaultTargetPlatform ==
                                      TargetPlatform.android ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.iOS)) {
                            HapticFeedback.selectionClick();
                          }
                        },
                  child: SizedBox(
                      width: 78,
                      child: Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 76,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : colors.outlineVariant,
                                  width: selected ? 2 : 1)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: editor.photo == null
                                ? ColoredBox(
                                    color: colors.surfaceContainerHighest)
                                : ColorFiltered(
                                    colorFilter:
                                        (preset?.matrix ?? ColorMatrix.identity)
                                            .toColorFilter(),
                                    child: PhotoImage(editor.photo!.bytes,
                                        thumbnail: true, label: name),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ])),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
