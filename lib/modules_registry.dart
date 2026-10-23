import 'package:core_ui/core_ui.dart';
import 'package:mod_iot/mod_iot.dart';

/// Registri seluruh modul yang tersedia dalam kompilasi ini.
class ModulesRegistry {
  ModulesRegistry._();

  static final List<AppModule> _allModules = [
    IotModule(),
  ];

  /// Mengembalikan modul aktif berdasarkan:
  /// 1. Flag compile-time --dart-define=MODULES=mod1,mod2 (default: semua)
  /// 2. Daftar modul aktif yang diizinkan oleh server
  static List<AppModule> getActiveModules({List<String>? serverEnabledModules}) {
    // 1. Baca dart-define flag
    const compileTimeModules = String.fromEnvironment('MODULES', defaultValue: '');
    List<String>? allowedByBuild;
    if (compileTimeModules.isNotEmpty) {
      allowedByBuild = compileTimeModules
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // Server list (sementara dummy ['iot'] jika tidak diprovide)
    final serverList = serverEnabledModules ?? ['iot'];

    return _allModules.where((module) {
      // Saring berdasarkan build flag jika ada
      if (allowedByBuild != null && !allowedByBuild.contains(module.id)) {
        return false;
      }
      // Saring berdasarkan hak akses server
      if (!serverList.contains(module.id)) {
        return false;
      }
      return true;
    }).toList();
  }
}
