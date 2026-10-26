import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'modules_registry.dart';
import 'router.dart';
import 'screens/pin_screens.dart';
import 'services/app_lock_service.dart';
import 'services/auth_service.dart';

/// Root widget aplikasi Gumpalan.
/// Bertanggung jawab atas inisialisasi tema, router komposit,
/// proteksi kunci aplikasi (App Lock / Biometrics), dan penentuan rute awal.
class GumpalanApp extends StatefulWidget {
  final AuthService? authService;
  final AppLockService? appLockService;

  const GumpalanApp({
    super.key,
    this.authService,
    this.appLockService,
  });

  @override
  State<GumpalanApp> createState() => _GumpalanAppState();
}

class _GumpalanAppState extends State<GumpalanApp> with WidgetsBindingObserver {
  late final AuthService _authService;
  late final AppLockService _appLockService;
  late final dynamic _router;

  _StartRoute? _startRoute;
  bool _isAppLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService = widget.authService ?? AuthService();
    _appLockService = widget.appLockService ?? AppLockService();
    final activeModules = ModulesRegistry.getActiveModules();
    _router = createRouter(
      activeModules: activeModules,
      authService: _authService,
      appLockService: _appLockService,
    );
    _resolveStartRoute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _appLockService.isLockEnabled().then((enabled) {
        if (enabled && mounted) {
          _appLockService.lockSession();
          setState(() => _isAppLocked = true);
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _checkLockStatusAndPrompt();
    }
  }

  Future<void> _checkLockStatusAndPrompt() async {
    final enabled = await _appLockService.isLockEnabled();
    final isAuth = await _authService.isAuthenticated();
    if (enabled && isAuth && !_appLockService.isUnlockedForSession) {
      if (mounted) {
        setState(() => _isAppLocked = true);
      }
    } else {
      if (mounted && _isAppLocked) {
        setState(() => _isAppLocked = false);
      }
    }
  }

  /// Menentukan halaman awal saat cold start dengan memverifikasi
  /// kredensial lokal dan status perangkat pada backend.
  Future<void> _resolveStartRoute() async {
    final deviceId = await _authService.getStoredDeviceId();
    try {
      if (deviceId != null && deviceId.isNotEmpty) {
        final result = await _authService.checkStatus(deviceId);
        switch (result.status) {
          case DeviceStatus.approved:
            _setStart(_StartRoute.home);
          case DeviceStatus.pending:
          case DeviceStatus.revoked:
            _setStart(_StartRoute.status);
          case DeviceStatus.unknown:
            await _authService.logout();
            _setStart(_StartRoute.landing);
        }
        return;
      }

      if (await _authService.isAuthenticated()) {
        _setStart(_StartRoute.home);
        return;
      }

      _setStart(_StartRoute.landing);
    } catch (_) {
      // Penanganan koneksi offline: izinkan akses dashboard jika memiliki token valid
      if (await _authService.isAuthenticated()) {
        _setStart(_StartRoute.home);
      } else if (deviceId != null && deviceId.isNotEmpty) {
        _setStart(_StartRoute.status);
      } else {
        _setStart(_StartRoute.landing);
      }
    }
  }

  Future<void> _checkInitialLock() async {
    final lockEnabled = await _appLockService.isLockEnabled();
    if (lockEnabled) {
      if (mounted) {
        setState(() => _isAppLocked = true);
      }
    }
  }

  void _setStart(_StartRoute route) {
    if (mounted) setState(() => _startRoute = route);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gumpalan',
      theme: GumpalanTheme.lightTheme,
      darkTheme: GumpalanTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      builder: (context, child) {
        if (_startRoute == null) {
          return _SplashScreen();
        }
        if (_startRoute != _StartRoute.done) {
          final target = _startRoute!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _router.go(target.path);
            if (target == _StartRoute.home) {
              _checkLockStatusAndPrompt();
            }
            setState(() => _startRoute = _StartRoute.done);
          });
        }

        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (_isAppLocked)
              Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => PinLockScreen(
                      appLockService: _appLockService,
                      onUnlocked: () {
                        setState(() => _isAppLocked = false);
                      },
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

enum _StartRoute {
  landing('/'),
  status('/auth/status'),
  home('/home'),
  done('');

  final String path;
  const _StartRoute(this.path);
}

class _SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_rounded, size: 72, color: colors.primary),
            const SizedBox(height: 20),
            Text(
              'Gumpalan',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
