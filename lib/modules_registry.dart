import 'package:core_ui/core_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mod_iot/mod_iot.dart';

/// Registri terpusat untuk modul-modul fitur yang dikompilasi ke dalam aplikasi.
class ModulesRegistry {
  ModulesRegistry._();

  static final List<AppModule> _allModules = [
    IotModule(),
  ];

  /// Mengembalikan daftar modul aktif yang telah disaring berdasarkan:
  /// 1. Konfigurasi `MODULES` pada berkas `.env` (jika didefinisikan).
  /// 2. Daftar modul yang diizinkan untuk perangkat dari backend auth.
  static List<AppModule> getActiveModules({List<String>? serverEnabledModules}) {
    final envModules = dotenv.env['MODULES'] ?? '';
    List<String>? allowedByEnv;
    if (envModules.isNotEmpty) {
      allowedByEnv = envModules
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final serverList = serverEnabledModules ?? ['iot'];

    return _allModules.where((module) {
      if (allowedByEnv != null && !allowedByEnv.contains(module.id)) {
        return false;
      }
      if (!serverList.contains(module.id)) {
        return false;
      }
      return true;
    }).toList();
  }
}
