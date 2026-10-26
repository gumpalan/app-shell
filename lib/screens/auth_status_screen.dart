import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/auth_service.dart';

/// Layar pemantauan status otorisasi perangkat.
/// Melakukan polling berkala ke server auth hingga perangkat disetujui (approved),
/// ditolak/dicabut (revoked), atau pengguna membatalkan pendaftaran.
class AuthStatusScreen extends StatefulWidget {
  final AuthService authService;
  final String? initialDeviceId;

  const AuthStatusScreen({
    super.key,
    required this.authService,
    this.initialDeviceId,
  });

  @override
  State<AuthStatusScreen> createState() => _AuthStatusScreenState();
}

class _AuthStatusScreenState extends State<AuthStatusScreen> {
  String? _deviceId;
  DeviceStatusResult? _lastResult;
  bool _isChecking = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _deviceId = widget.initialDeviceId;
    _checkStatus();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkStatus(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final router = GoRouter.of(context);
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      _deviceId ??= await widget.authService.getStoredDeviceId();
      final result = await widget.authService.checkStatus(_deviceId);

      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _isChecking = false;
      });

      if (result.status == DeviceStatus.approved) {
        _pollTimer?.cancel();
        router.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Koneksi ke auth service terputus: $e';
        _isChecking = false;
      });
    }
  }

  Future<void> _handleReRegister() async {
    final router = GoRouter.of(context);
    await widget.authService.logout();
    if (!mounted) return;
    router.go('/');
  }

  Future<void> _copyDeviceId() async {
    if (_deviceId == null) return;
    await Clipboard.setData(ClipboardData(text: _deviceId!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID Perangkat disalin ke clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = _lastResult?.status ?? DeviceStatus.pending;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: SvgPicture.asset(
                      'assets/images/in_app_icon.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                  const SizedBox(height: 12),
                  Text(
                    'Gumpalan',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StatusHeader(status: status, colors: colors, theme: theme),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _DeviceInfoCard(
                    deviceId: _deviceId,
                    result: _lastResult,
                    status: status,
                    onCopy: _copyDeviceId,
                    colors: colors,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),
                  if (status == DeviceStatus.pending)
                    _ApproveInstructionCard(
                      deviceId: _deviceId,
                      colors: colors,
                      theme: theme,
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isChecking ? null : _checkStatus,
                    icon: _isChecking
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(
                      _isChecking ? 'Memeriksa status...' : 'Cek Status',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _handleReRegister,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Daftar Ulang'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Memeriksa status otomatis setiap 10 detik',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
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

class _StatusHeader extends StatelessWidget {
  final DeviceStatus status;
  final ColorScheme colors;
  final ThemeData theme;

  const _StatusHeader({
    required this.status,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    Color iconBg;
    String title;
    String desc;

    switch (status) {
      case DeviceStatus.pending:
        icon = Icons.hourglass_top_rounded;
        iconColor = colors.primary;
        iconBg = colors.primaryContainer;
        title = 'Menunggu Persetujuan';
        desc =
          'Perangkat ini telah terdaftar. Hubungi administrator sistem untuk mengaktifkan akses perangkat.';
      case DeviceStatus.approved:
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green;
        iconBg = Colors.green.withValues(alpha: 0.15);
        title = 'Perangkat Disetujui';
        desc = 'Akses telah diverifikasi. Membuka layar utama...';
      case DeviceStatus.revoked:
        icon = Icons.block_rounded;
        iconColor = colors.error;
        iconBg = colors.errorContainer;
        title = 'Akses Dicabut';
        desc =
          'Otorisasi perangkat ini telah dinonaktifkan oleh administrator sistem.';
      case DeviceStatus.unknown:
        icon = Icons.help_outline_rounded;
        iconColor = colors.error;
        iconBg = colors.errorContainer;
        title = 'Status Tidak Dikenal';
        desc = 'Status perangkat tidak ditemukan dalam sistem backend.';
    }

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: iconColor),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final String? deviceId;
  final DeviceStatusResult? result;
  final DeviceStatus status;
  final VoidCallback onCopy;
  final ColorScheme colors;
  final ThemeData theme;

  const _DeviceInfoCard({
    required this.deviceId,
    required this.result,
    required this.status,
    required this.onCopy,
    required this.colors,
    required this.theme,
  });

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'Informasi Perangkat',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const Spacer(),
                _StatusBadge(status: status, colors: colors),
              ],
            ),
            const Divider(height: 20),
            if (result?.name != null && result!.name!.isNotEmpty) ...[
              _InfoRow(
                label: 'Nama',
                value: result!.name!,
                colors: colors,
                theme: theme,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID Perangkat',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        deviceId ?? 'Belum ada',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (deviceId != null)
                  IconButton(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Salin ID',
                  ),
              ],
            ),
            if (result?.registeredAt != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Terdaftar Pada',
                value: _formatDateTime(result!.registeredAt!),
                colors: colors,
                theme: theme,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colors;
  final ThemeData theme;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApproveInstructionCard extends StatelessWidget {
  final String? deviceId;
  final ColorScheme colors;
  final ThemeData theme;

  const _ApproveInstructionCard({
    required this.deviceId,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final devId = deviceId ?? '<DEVICE_ID>';
    final cmd = 'cd svc-auth && go run ./cmd/auth device approve $devId';

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.terminal_rounded,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Perintah Persetujuan (Terminal Admin)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      cmd,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Salin Perintah',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: cmd));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Perintah disalin ke clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DeviceStatus status;
  final ColorScheme colors;

  const _StatusBadge({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, bg, fg, border) = switch (status) {
      DeviceStatus.approved => (
        'Disetujui',
        isDark ? const Color(0xFF0F381E) : const Color(0xFFDEF7EC),
        isDark ? const Color(0xFF31C48D) : const Color(0xFF03543F),
        isDark ? const Color(0xFF0E9F6E) : const Color(0xFF84E1BC),
      ),
      DeviceStatus.revoked => (
        'Dicabut',
        isDark ? const Color(0xFF491216) : const Color(0xFFFDE8E8),
        isDark ? const Color(0xFFF98080) : const Color(0xFF9B1C1C),
        isDark ? const Color(0xFFE02424) : const Color(0xFFF8B4B4),
      ),
      DeviceStatus.pending => (
        'Menunggu',
        isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
        isDark ? const Color(0xFF9E9E9E) : const Color(0xFF4B5563),
        isDark ? const Color(0xFF424242) : const Color(0xFFD1D5DB),
      ),
      DeviceStatus.unknown => (
        'Unknown',
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
        colors.outlineVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
