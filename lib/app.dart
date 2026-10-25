import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'modules_registry.dart';
import 'router.dart';
import 'services/auth_service.dart';

/// Root widget aplikasi Gumpalan.
/// Bertanggung jawab atas inisialisasi tema, router komposit,
/// dan penentuan rute awal berdasarkan status autentikasi perangkat.
class GumpalanApp extends StatefulWidget {
  final AuthService? authService;

  const GumpalanApp({super.key, this.authService});

  @override
  State<GumpalanApp> createState() => _GumpalanAppState();
}

class _GumpalanAppState extends State<GumpalanApp> {
  late final AuthService _authService;
  late final dynamic _router;

  _StartRoute? _startRoute;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    final activeModules = ModulesRegistry.getActiveModules();
    _router = createRouter(
      activeModules: activeModules,
      authService: _authService,
    );
    _resolveStartRoute();
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _router.go(_startRoute!.path);
            setState(() => _startRoute = _StartRoute.done);
          });
        }
        return child ?? const SizedBox.shrink();
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
