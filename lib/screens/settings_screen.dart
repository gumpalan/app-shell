import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import 'pin_screens.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final AppLockService appLockService;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.appLockService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _profile;
  List<UserDeviceItem> _devices = [];
  bool _isLoading = true;
  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  bool _canBiometrics = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileFuture = widget.authService.getUserProfile();
      final devicesFuture = widget.authService.listUserDevices();
      final hasPinFuture = widget.appLockService.hasPin();
      final bioEnabledFuture = widget.appLockService.isBiometricEnabled();
      final canBioFuture = widget.appLockService.canAuthenticateWithBiometrics();

      final results = await Future.wait([
        profileFuture,
        devicesFuture,
        hasPinFuture,
        bioEnabledFuture,
        canBioFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _devices = results[1] as List<UserDeviceItem>;
        _hasPin = results[2] as bool;
        _isBiometricEnabled = results[3] as bool;
        _canBiometrics = results[4] as bool;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Settings] loadSettings error: $e');
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleEditProfile() async {
    if (_profile == null) return;
    final controller = TextEditingController(text: _profile!.displayName);

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Nama Lengkap'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nama Lengkap',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && updated != _profile!.displayName) {
      try {
        await widget.authService.updateProfile(displayName: updated);
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama berhasil disimpan')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui nama: $e')),
        );
      }
    }
  }

  Future<void> _handleChangePassword() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Kata Sandi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Lama',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Masukkan kata sandi lama' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Baru',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val != null && val.length >= 6 ? null : 'Minimal 6 karakter',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Ulangi Kata Sandi Baru',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == newController.text ? null : 'Kata sandi tidak sama',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.authService.updatePassword(
          oldPassword: oldController.text,
          newPassword: newController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kata sandi berhasil diganti')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _handleManagePin() async {
    if (!_hasPin) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(appLockService: widget.appLockService),
        ),
      );

      if (result == true) {
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN berhasil dibuat')),
        );
      }
    } else {
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('Ganti PIN'),
                onTap: () => Navigator.pop(ctx, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.lock_open_rounded, color: Colors.red),
                title: const Text(
                  'Nonaktifkan PIN & Sidik Jari',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(ctx, 'disable'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (action == 'change') {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PinSetupScreen(appLockService: widget.appLockService),
          ),
        );
        if (result == true) {
          await _loadSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN berhasil diperbarui')),
          );
        }
      } else if (action == 'disable') {
        await widget.appLockService.removePin();
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kunci PIN & Sidik Jari dinonaktifkan')),
        );
      }
    }
  }

  Future<void> _handleToggleBiometric(bool value) async {
    if (!_hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buat PIN terlebih dahulu untuk mengaktifkan sidik jari')),
      );
      return;
    }

    if (value) {
      final authenticated = await widget.appLockService.authenticateBiometrics(
        reason: 'Pindai sidik jari untuk mengaktifkan verifikasi biometrik',
      );
      if (!authenticated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifikasi sidik jari dibatalkan')),
        );
        return;
      }
    }

    await widget.appLockService.setBiometricEnabled(value);
    setState(() => _isBiometricEnabled = value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Sidik jari diaktifkan' : 'Sidik jari dinonaktifkan',
        ),
      ),
    );
  }

  Future<void> _handleRevokeDevice(UserDeviceItem dev) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabut Akses Perangkat?'),
        content: Text(
          'Cabut akses perangkat "${dev.name.isNotEmpty ? dev.name : dev.deviceId}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Cabut'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.authService.revokeUserDevice(dev.deviceId);
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perangkat "${dev.name}" dicabut')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencabut perangkat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardBorder = BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.25),
      width: 1,
    );
    final cardColor = isDark
        ? colors.surfaceContainerLow
        : colors.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: cardBorder,
                    ),
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                                child: Text(
                                  _profile?.displayName.isNotEmpty == true
                                      ? _profile!.displayName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _profile?.displayName ?? 'Pengguna',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '@${_profile?.username ?? "-"}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.onSurface.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _profile?.roleName.toUpperCase() ?? 'USER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                            title: const Text('Ubah Nama Lengkap', style: TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: _handleEditProfile,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.lock_reset_rounded,
                              size: 20,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                            title: const Text('Ganti Kata Sandi', style: TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: _handleChangePassword,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: cardBorder,
                    ),
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 20,
                                color: colors.onSurface.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Keamanan Aplikasi',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kunci PIN adalah pengaman utama. Sidik jari digunakan untuk verifikasi cepat.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.pin_outlined,
                              color: colors.onSurface.withValues(alpha: 0.75),
                            ),
                            title: const Text('Kunci PIN (6 Digit)', style: TextStyle(fontSize: 14)),
                            subtitle: Text(
                              _hasPin ? 'Aktif • Ketuk untuk ubah atau nonaktifkan' : 'Belum diatur • Diperlukan untuk verifikasi sidik jari',
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasPin
                                    ? colors.onSurface.withValues(alpha: 0.75)
                                    : colors.error.withValues(alpha: 0.8),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: _handleManagePin,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              Icons.fingerprint_rounded,
                              color: colors.onSurface.withValues(alpha: 0.75),
                            ),
                            title: const Text('Buka Cepat dengan Sidik Jari', style: TextStyle(fontSize: 14)),
                            subtitle: Text(
                              !_hasPin
                                  ? 'Wajib membuat PIN terlebih dahulu'
                                  : _canBiometrics
                                      ? 'Pindai sidik jari saat membuka aplikasi'
                                      : 'Sensor biometrik tidak tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            value: _isBiometricEnabled,
                            onChanged: (_hasPin && _canBiometrics)
                                ? _handleToggleBiometric
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: cardBorder,
                    ),
                    color: cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.devices_outlined,
                                size: 20,
                                color: colors.onSurface.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Perangkat Tertaut',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.onSurface.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_devices.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Daftar perangkat fisik yang terotorisasi mengakses akun.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_devices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Tidak ada perangkat terdaftar.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _devices.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (ctx, idx) {
                                final dev = _devices[idx];
                                final isApproved = dev.status == 'approved';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.smartphone_rounded,
                                    color: isApproved
                                        ? colors.onSurface.withValues(alpha: 0.7)
                                        : colors.error,
                                  ),
                                  title: Text(
                                    dev.name.isNotEmpty ? dev.name : dev.deviceId,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    '${dev.status} • ${dev.createdAt.day}/${dev.createdAt.month}/${dev.createdAt.year}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                    color: colors.error,
                                    onPressed: () => _handleRevokeDevice(dev),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        await widget.authService.logout();
                        if (!context.mounted) return;
                        router.go('/');
                      },
                      icon: Icon(Icons.logout_rounded, color: colors.error),
                      label: Text(
                        'Keluar dari Akun',
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
