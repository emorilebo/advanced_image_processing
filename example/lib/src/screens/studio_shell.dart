import 'dart:async';

import 'package:flutter/material.dart';

import '../state/editor_controller.dart';
import '../state/privacy_controller.dart';
import '../state/studio_services.dart';
import '../widgets/studio_widgets.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';
import 'studio_screen.dart';

class StudioShell extends StatefulWidget {
  const StudioShell({super.key, required this.services});
  final StudioServices services;
  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  late final EditorController _editor = EditorController(widget.services);
  late final PrivacyController _privacy = PrivacyController(widget.services);
  int _destination = 0;
  bool _privacyOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(runAction(context, _editor, _editor.loadSample));
    });
  }

  void _navigate(int index) {
    setState(() => _destination = index);
    if (index == 1 && !_privacyOpened) {
      _privacyOpened = true;
      unawaited(runAction(context, _privacy, _privacy.loadSample));
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final colors = Theme.of(context).colorScheme;
    final screen = switch (_destination) {
      0 => StudioScreen(controller: _editor),
      1 => PrivacyScreen(controller: _privacy),
      _ => AboutScreen(services: widget.services),
    };
    return Scaffold(
      body: SafeArea(
          child: Column(children: [
        Container(
          height: wide ? 82 : 68,
          padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 20),
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant))),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.camera_outlined,
                  color: colors.onPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Toolkit ',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(
                          text: 'Studio',
                          style: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: colors.onSurfaceVariant)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, letterSpacing: -0.7))),
            if (wide) ...[
              Icon(Icons.lock_outline,
                  size: 13, color: colors.onSurfaceVariant),
              const SizedBox(width: 7),
              Text('ON YOUR DEVICE. IN YOUR HANDS.',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 24),
            ],
            const StatusBadge('v0.3'),
          ]),
        ),
        Expanded(
            child: Row(children: [
          if (wide) ...[
            NavigationRail(
              selectedIndex: _destination,
              onDestinationSelected: _navigate,
              labelType: NavigationRailLabelType.all,
              minWidth: 88,
              groupAlignment: -0.88,
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.tune), label: Text('Studio')),
                NavigationRailDestination(
                    icon: Icon(Icons.shield_outlined),
                    selectedIcon: Icon(Icons.shield),
                    label: Text('Privacy')),
                NavigationRailDestination(
                    icon: Icon(Icons.info_outline),
                    selectedIcon: Icon(Icons.info),
                    label: Text('About')),
              ],
            ),
            VerticalDivider(width: 1, color: colors.outlineVariant),
          ],
          Expanded(child: screen),
        ])),
      ])),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                  border:
                      Border(top: BorderSide(color: colors.outlineVariant))),
              child: NavigationBar(
                selectedIndex: _destination,
                onDestinationSelected: _navigate,
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.tune), label: 'Studio'),
                  NavigationDestination(
                      icon: Icon(Icons.shield_outlined),
                      selectedIcon: Icon(Icons.shield),
                      label: 'Privacy'),
                  NavigationDestination(
                      icon: Icon(Icons.info_outline),
                      selectedIcon: Icon(Icons.info),
                      label: 'About'),
                ],
              ),
            ),
    );
  }
}
