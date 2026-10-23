import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'modules_registry.dart';
import 'router.dart';

class GumpalanApp extends StatelessWidget {
  const GumpalanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final activeModules = ModulesRegistry.getActiveModules();
    final router = createRouter(activeModules: activeModules);

    return MaterialApp.router(
      title: 'Gumpalan',
      theme: GumpalanTheme.lightTheme,
      darkTheme: GumpalanTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
