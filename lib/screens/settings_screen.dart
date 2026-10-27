import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/shell_settings_service.dart';
import 'pin_screens.dart';

/// Layar pengaturan akun, preferensi dashboard default,
/// keamanan biometrik/PIN, dan manajemen perangkat tertaut.
class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final AppLockService appLockService;
  final List<AppModule> activeModules;
  final ShellSettingsService? settingsService;
  final ValueChanged<String>? onDefaultModuleChanged;

  /// Jika [embedded] aktif, layar ini tidak merender Scaffold/AppBar sendiri
  /// karena dirancang untuk ditempel di dalam tab shell utama.
  final bool embedded;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.appLockService,
    this.activeModules = const [],
    this.settingsService,
    this.onDefaultModuleChanged,
    this.embedded = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ShellSettingsService _settingsService;
  UserProfile? _profile;
  List<UserDeviceItem> _devices = [];
  bool _isLoading = true;
  bool _hasPin = false;
  bool _isBiometricEnabled = false;
  bool _canBiometrics = false;
  String? _defaultModuleId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? ShellSettingsService();
    _loadSettings();
  }

  String _findModuleName(String? id) {
    if (id == null || id.isEmpty) {
      return widget.activeModules.isNotEmpty
          ? widget.activeModules.first.name
          : 'Bawaan';
    }
    for (final m in widget.activeModules) {
      if (m.id == id) return m.name;
    }
    return id.toUpperCase();
  }

  AppModule? get _currentDefaultModule {
    if (widget.activeModules.isEmpty) return null;
    if (_defaultModuleId != null) {
      for (final m in widget.activeModules) {
        if (m.id == _defaultModuleId) return m;
      }
    }
    return widget.activeModules.first;
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
      final canBioFuture = widget.appLockService
          .canAuthenticateWithBiometrics();
      final defModuleFuture = _settingsService.getDefaultDashboardModule();

      final results = await Future.wait([
        profileFuture,
        devicesFuture,
        hasPinFuture,
        bioEnabledFuture,
        canBioFuture,
        defModuleFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile;
        _devices = results[1] as List<UserDeviceItem>;
        _hasPin = results[2] as bool;
        _isBiometricEnabled = results[3] as bool;
        _canBioFuture(results[4] as bool);
        final savedDef = results[5] as String?;
        _defaultModuleId =
            savedDef ??
            (widget.activeModules.isNotEmpty
                ? widget.activeModules.first.id
                : null);
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

  void _canBioFuture(bool val) {
    _canBiometrics = val;
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

    if (updated != null &&
        updated.isNotEmpty &&
        updated != _profile!.displayName) {
      try {
        await widget.authService.updateProfile(displayName: updated);
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nama berhasil disimpan')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memperbarui nama: $e')));
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
                validator: (val) => val == null || val.isEmpty
                    ? 'Masukkan kata sandi lama'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata Sandi Baru',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val != null && val.length >= 6
                    ? null
                    : 'Minimal 6 karakter',
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PIN berhasil dibuat')));
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
            builder: (_) =>
                PinSetupScreen(appLockService: widget.appLockService),
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
        const SnackBar(
          content: Text(
            'Buat PIN terlebih dahulu untuk mengaktifkan sidik jari',
          ),
        ),
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
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Buka dengan sidik jari diaktifkan'
              : 'Buka dengan sidik jari dinonaktifkan',
        ),
      ),
    );
  }

  Future<void> _handleRevokeDevice(UserDeviceItem device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cabut Perangkat'),
        content: Text(
          'Akses untuk "${device.name.isNotEmpty ? device.name : device.deviceId}" akan dicabut. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut Akses'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.authService.revokeUserDevice(device.deviceId);
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perangkat berhasil dicabut')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mencabut perangkat: $e')));
      }
    }
  }

  Future<void> _showSelectDefaultDashboardModal() async {
    if (widget.activeModules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada modul aktif yang tersedia.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final colors = Theme.of(ctx).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Dashboard Default',
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modul ini akan selalu menjadi dashboard utama ketika aplikasi dibuka.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                ...widget.activeModules.map((m) {
                  final isSelected = m.id == _defaultModuleId;
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
                              : FontWeight.w500,
                          color: isSelected ? colors.primary : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, m.id),
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

    if (selected != null && selected != _defaultModuleId && mounted) {
      await _settingsService.setDefaultDashboardModule(selected);
      setState(() => _defaultModuleId = selected);
      widget.onDefaultModuleChanged?.call(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dashboard default diubah ke ${_findModuleName(selected)}',
          ),
        ),
      );
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required ColorScheme colors,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardBorder = BorderSide(
      color: isDark
          ? colors.outline.withValues(alpha: 0.25)
          : colors.outlineVariant.withValues(alpha: 0.8),
      width: 1,
    );
    final cardColor = isDark ? colors.surfaceContainerLow : colors.surface;

    Widget body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadSettings,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),

                // KARTU PROFIL PENGGUNA
                Card(
                  elevation: isDark ? 0 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: cardBorder,
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: colors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                _profile?.displayName.isNotEmpty == true
                                    ? _profile!.displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
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
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '@${_profile?.username ?? "-"}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _profile?.roleName.toUpperCase() ?? 'USER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                          title: const Text(
                            'Ubah Nama Lengkap',
                            style: TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: _handleEditProfile,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.lock_reset_rounded,
                            size: 20,
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                          title: const Text(
                            'Ganti Kata Sandi',
                            style: TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: _handleChangePassword,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // KARTU PREFERENSI DASHBOARD DEFAULT
                Card(
                  elevation: isDark ? 0 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: cardBorder,
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Dashboard Default',
                          colors: colors,
                          theme: theme,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pilih modul yang otomatis terbuka sebagai dashboard utama saat aplikasi dinyalakan.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _currentDefaultModule?.icon ??
                                  Icons.space_dashboard_rounded,
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _currentDefaultModule?.name ?? 'Modul Bawaan',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Aktif permanen saat startup',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.swap_horiz_rounded,
                            size: 22,
                          ),
                          onTap: _showSelectDefaultDashboardModal,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // KARTU KEAMANAN APLIKASI
                Card(
                  elevation: isDark ? 0 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: cardBorder,
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.shield_outlined,
                          title: 'Keamanan Aplikasi',
                          colors: colors,
                          theme: theme,
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
                          title: const Text(
                            'Kunci PIN (6 Digit)',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            _hasPin
                                ? 'Aktif • Ketuk untuk ubah atau nonaktifkan'
                                : 'Belum diatur • Diperlukan untuk verifikasi sidik jari',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasPin
                                  ? colors.onSurface.withValues(alpha: 0.75)
                                  : colors.error.withValues(alpha: 0.8),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: _handleManagePin,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.fingerprint_rounded,
                            color: colors.onSurface.withValues(alpha: 0.75),
                          ),
                          title: const Text(
                            'Buka Cepat dengan Sidik Jari',
                            style: TextStyle(fontSize: 14),
                          ),
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

                // KARTU PERANGKAT TERTAUT
                Card(
                  elevation: isDark ? 0 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: cardBorder,
                  ),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildSectionHeader(
                              icon: Icons.devices_outlined,
                              title: 'Perangkat Tertaut',
                              colors: colors,
                              theme: theme,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_devices.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.75,
                                  ),
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
                            separatorBuilder: (ctx, i) =>
                                const SizedBox(height: 4),
                            itemBuilder: (ctx, idx) {
                              final dev = _devices[idx];
                              final isApproved = dev.status == 'approved';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.smartphone_rounded,
                                  color: isApproved
                                      ? colors.primary
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
                                    color: colors.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                  ),
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

                // TOMBOL KELUAR
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
          );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan'), elevation: 0),
      body: body,
    );
  }
}
