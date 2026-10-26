import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_status_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_lock_service.dart';
import 'services/auth_service.dart';

/// Membentuk instance [GoRouter] yang menggabungkan rute inti sistem autentikasi,
/// pengaturan profil, dengan rute dinamis dari modul-modul fitur yang aktif.
GoRouter createRouter({
  required List<AppModule> activeModules,
  required AuthService authService,
  required AppLockService appLockService,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => LandingScreen(authService: authService),
      ),
      GoRoute(
        path: '/auth/status',
        name: 'auth-status',
        builder: (context, state) =>
            AuthStatusScreen(authService: authService),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => SettingsScreen(
          authService: authService,
          appLockService: appLockService,
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => HomeScreen(
          activeModules: activeModules,
          authService: authService,
        ),
      ),
      ...activeModules.expand((m) => m.routes),
    ],
  );
}

/// Layar beranda utama yang menampilkan antarmuka dari modul aktif.
/// Mendukung peralihan modul dan memantau status validitas perangkat secara periodik.
class HomeScreen extends StatefulWidget {
  final List<AppModule> activeModules;
  final AuthService authService;

  const HomeScreen({
    super.key,
    required this.activeModules,
    required this.authService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeIndex = 0;
  Timer? _authGuardTimer;

  @override
  void initState() {
    super.initState();
    _checkDeviceStatus();
    _authGuardTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkDeviceStatus(),
    );
  }

  @override
  void dispose() {
    _authGuardTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeviceStatus() async {
    final router = GoRouter.of(context);
    try {
      final res = await widget.authService.checkStatus();
      if (!mounted) return;
      if (res.status == DeviceStatus.revoked ||
          res.status == DeviceStatus.pending) {
        _authGuardTimer?.cancel();
        router.go('/auth/status');
      }
    } catch (_) {}
  }

  AppModule? get _currentModule {
    if (widget.activeModules.isEmpty) return null;
    return widget.activeModules[_activeIndex.clamp(
      0,
      widget.activeModules.length - 1,
    )];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final module = _currentModule;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (module != null) ...[
              Icon(module.icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(module?.name ?? 'Gumpalan'),
          ],
        ),
        actions: [
          if (widget.activeModules.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.apps_rounded),
              tooltip: 'Ganti tampilan',
              onSelected: (i) => setState(() => _activeIndex = i),
              itemBuilder: (context) => widget.activeModules
                  .asMap()
                  .entries
                  .map(
                    (e) => PopupMenuItem(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(
                            e.value.icon,
                            size: 18,
                            color: e.key == _activeIndex
                                ? colors.primary
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            e.value.name,
                            style: TextStyle(
                              fontWeight: e.key == _activeIndex
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: e.key == _activeIndex
                                  ? colors.primary
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan & Profil',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: module != null
          ? module.homeScreen
          : _EmptyModuleView(colors: colors),
    );
  }
}

class _EmptyModuleView extends StatelessWidget {
  final ColorScheme colors;

  const _EmptyModuleView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.extension_off_rounded,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada modul aktif',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.45),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Konfigurasikan variabel MODULES pada file .env\nuntuk mengaktifkan fitur.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.35),
                ),
          ),
        ],
      ),
    );
  }
}
