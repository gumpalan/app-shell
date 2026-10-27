import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_status_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_lock_service.dart';
import 'services/auth_service.dart';
import 'services/shell_settings_service.dart';

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
        builder: (context, state) => AuthStatusScreen(authService: authService),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => SettingsScreen(
          authService: authService,
          appLockService: appLockService,
          activeModules: activeModules,
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => HomeScreen(
          activeModules: activeModules,
          authService: authService,
          appLockService: appLockService,
        ),
      ),
      ...activeModules.expand((m) => m.routes),
    ],
  );
}

/// Layar beranda utama yang menampilkan antarmuka superapp modern.
/// Memadukan layout shell adaptif 3 menu (Dashboard, Menu, Pengaturan),
/// auto-guard otorisasi berkala, serta pemilihan dashboard modular sementara & default.
class HomeScreen extends StatefulWidget {
  final List<AppModule> activeModules;
  final AuthService authService;
  final AppLockService? appLockService;

  const HomeScreen({
    super.key,
    required this.activeModules,
    required this.authService,
    this.appLockService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0; // 0: Dashboard, 1: Menu, 2: Pengaturan
  String? _tempModuleId;
  String? _defaultModuleId;
  late final ShellSettingsService _settingsService;
  Timer? _authGuardTimer;

  @override
  void initState() {
    super.initState();
    _settingsService = ShellSettingsService();
    _loadDefaultModule();
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

  Future<void> _loadDefaultModule() async {
    final def = await _settingsService.getDefaultDashboardModule();
    if (mounted) {
      setState(() {
        _defaultModuleId =
            def ??
            (widget.activeModules.isNotEmpty
                ? widget.activeModules.first.id
                : null);
      });
    }
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

  AppModule? get _currentDashboardModule {
    if (widget.activeModules.isEmpty) return null;
    final targetId = _tempModuleId ?? _defaultModuleId;
    if (targetId != null) {
      for (final m in widget.activeModules) {
        if (m.id == targetId) return m;
      }
    }
    return widget.activeModules.first;
  }

  void _showDashboardSwitcherModal(BuildContext context) {
    if (widget.activeModules.length <= 1) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final currentMod = _currentDashboardModule;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.dashboard_customize_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ganti Dashboard (Sesi Ini)',
                          style: Theme.of(ctx).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Perubahan hanya berlaku saat ini dan kembali ke default saat restart.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...widget.activeModules.map((m) {
                  final isSelected = m.id == currentMod?.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.1)
                          : (isDark
                                ? colors.surfaceContainerHighest.withValues(
                                    alpha: 0.3,
                                  )
                                : colors.surfaceContainerHighest.withValues(
                                    alpha: 0.2,
                                  )),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.outline.withValues(alpha: 0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        m.icon,
                        color: isSelected
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.8),
                      ),
                      title: Text(
                        m.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected ? colors.primary : null,
                        ),
                      ),
                      subtitle: Text(
                        isSelected
                            ? 'Dashboard aktif sesi ini'
                            : 'Beralih ke modul ini',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _tempModuleId = m.id;
                          _currentTab = 0;
                        });
                      },
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colors,
    bool isDark,
  ) {
    if (_currentTab == 0) {
      final module = _currentDashboardModule;
      return AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: SvgPicture.asset(
                'assets/images/in_app_icon.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Gumpalan',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.3),
            ),
            if (module != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      module.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.activeModules.length > 1)
            IconButton(
              icon: const Icon(Icons.dashboard_customize_outlined),
              tooltip: 'Ganti Dashboard Sesi Ini',
              onPressed: () => _showDashboardSwitcherModal(context),
            ),
        ],
      );
    }

    if (_currentTab == 1) {
      return AppBar(
        title: const Text(
          'Menu',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      );
    }

    return AppBar(
      title: const Text(
        'Pengaturan',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    switch (_currentTab) {
      case 0:
        final module = _currentDashboardModule;
        return module != null
            ? module.homeScreen
            : _EmptyModuleView(colors: colors);
      case 1:
        return _ModuleMenuHubTab(
          activeModules: widget.activeModules,
          onSelectDashboard: (module) {
            setState(() {
              _tempModuleId = module.id;
              _currentTab = 0;
            });
          },
        );
      case 2:
        return SettingsScreen(
          authService: widget.authService,
          appLockService: widget.appLockService ?? AppLockService(),
          activeModules: widget.activeModules,
          settingsService: _settingsService,
          onDefaultModuleChanged: (newId) {
            setState(() => _defaultModuleId = newId);
          },
          embedded: true,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final appBar = _buildAppBar(context, colors, isDark);

        if (isWide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentTab,
                  onDestinationSelected: (i) => setState(() => _currentTab = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: isDark
                      ? colors.surface
                      : colors.surfaceContainerHighest.withValues(alpha: 0.3),
                  selectedIconTheme: IconThemeData(color: colors.primary),
                  selectedLabelTextStyle: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: colors.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.widgets_outlined),
                      selectedIcon: Icon(Icons.widgets_rounded),
                      label: Text('Menu'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings_rounded),
                      label: Text('Pengaturan'),
                    ),
                  ],
                ),
                Expanded(child: _buildBody(colors)),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: _buildBody(colors),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (i) => setState(() => _currentTab = i),
            elevation: 2,
            height: 64,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.widgets_outlined),
                selectedIcon: Icon(Icons.widgets_rounded),
                label: 'Menu',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Pengaturan',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tab Menu: Menampilkan hub seluruh fungsi dan fitur dari semua modul aktif.
class _ModuleMenuHubTab extends StatelessWidget {
  final List<AppModule> activeModules;
  final ValueChanged<AppModule> onSelectDashboard;

  const _ModuleMenuHubTab({
    required this.activeModules,
    required this.onSelectDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (activeModules.isEmpty) {
      return _EmptyModuleView(colors: colors);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Ringkasan Ekosistem
        Card(
          elevation: isDark ? 0 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark
                  ? colors.outline.withValues(alpha: 0.2)
                  : colors.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_mosaic_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ekosistem Modular',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activeModules.length} modul aktif terpasang pada sesi ini.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'SEMUA MODUL & FITUR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),

        ...activeModules.map((module) {
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark
                    ? colors.outline.withValues(alpha: 0.2)
                    : colors.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          module.icon,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              module.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${module.id} • Modul Aktif',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => onSelectDashboard(module),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Buka Dashboard',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (module.homeCard != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    module.homeCard!,
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EmptyModuleView extends StatelessWidget {
  final ColorScheme colors;

  const _EmptyModuleView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.extension_off_rounded,
                size: 52,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tidak Ada Modul Aktif',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Konfigurasikan variabel MODULES pada file .env\nuntuk mengaktifkan fitur superapp.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
