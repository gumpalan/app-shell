import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

/// Layar inisialisasi onboarding perangkat.
/// Memungkinkan pendaftaran perangkat baru secara otomatis ke server auth.
class LandingScreen extends StatefulWidget {
  final AuthService authService;

  const LandingScreen({super.key, required this.authService});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegister() async {
    final router = GoRouter.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.register();
      if (!mounted) return;
      router.go('/auth/status');
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[Gumpalan][Register] Gagal mendaftarkan perangkat: $e');
        debugPrint(stack.toString());
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mendaftarkan perangkat:\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: SvgPicture.asset(
                      'assets/images/in_app_icon.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                  const SizedBox(height: 28),
                  Text(
                    'Gumpalan',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Platform IoT & Otomasi Terdistribusi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Perangkat belum terdaftar dalam sistem.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Daftarkan perangkat ini ke server autentikasi untuk memperoleh akses operasional.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: colors.onErrorContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Text(
                            'Daftarkan Perangkat Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Identitas perangkat dikirim secara otomatis via hardware fingerprint.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
