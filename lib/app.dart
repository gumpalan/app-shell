import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'modules_registry.dart';
import 'router.dart';
import 'services/auth_service.dart';

class GumpalanApp extends StatefulWidget {
  final AuthService? authService;

  const GumpalanApp({super.key, this.authService});

  @override
  State<GumpalanApp> createState() => _GumpalanAppState();
}

class _GumpalanAppState extends State<GumpalanApp> {
  late final AuthService _authService;
  late final dynamic _router;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    final activeModules = ModulesRegistry.getActiveModules();
    _router = createRouter(
      activeModules: activeModules,
      authService: _authService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gumpalan',
      theme: GumpalanTheme.lightTheme,
      darkTheme: GumpalanTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
