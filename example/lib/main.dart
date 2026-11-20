import 'package:flutter/material.dart';

import 'src/screens/studio_shell.dart';
import 'src/state/studio_services.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ToolkitStudio());
}

class ToolkitStudio extends StatelessWidget {
  const ToolkitStudio(
      {super.key, this.services, this.themeMode = ThemeMode.system});

  final StudioServices? services;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Toolkit Studio',
        debugShowCheckedModeBanner: false,
        theme: StudioTheme.light,
        darkTheme: StudioTheme.dark,
        themeMode: themeMode,
        home: StudioShell(services: services ?? StudioServices()),
      );
}
