import 'package:shared_preferences/shared_preferences.dart';

/// Layanan persistensi preferensi pengaturan app-shell Gumpalan.
class ShellSettingsService {
  static const String _keyDefaultModule = 'gumpalan_default_dashboard_module';

  /// Mendapatkan ID modul yang diatur sebagai dashboard utama saat startup.
  Future<String?> getDefaultDashboardModule() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultModule);
  }

  /// Menyimpan ID modul pilihan sebagai dashboard utama permanen.
  Future<void> setDefaultDashboardModule(String moduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultModule, moduleId);
  }
}
