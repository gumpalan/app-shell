import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layanan manajemen kunci aplikasi berbasis PIN dan biometrik.
/// PIN merupakan kunci utama; otentikasi biometrik adalah opsi pelengkap.
class AppLockService {
  static const String _keyPin = 'gumpalan_app_lock_pin';
  static const String _keyBiometricEnabled = 'gumpalan_app_lock_biometric_enabled';

  final LocalAuthentication _localAuth;
  bool _isUnlockedForSession = false;

  AppLockService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  bool get isUnlockedForSession => _isUnlockedForSession;

  void lockSession() {
    _isUnlockedForSession = false;
  }

  void unlockSession() {
    _isUnlockedForSession = true;
  }

  /// Memeriksa apakah PIN pengunci aplikasi sudah dibuat.
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_keyPin);
    return pin != null && pin.isNotEmpty;
  }

  /// Kompatibilitas alias untuk mengecek apakah kunci aplikasi aktif.
  Future<bool> isLockEnabled() => hasPin();

  /// Menyimpan PIN baru aplikasi.
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
    _isUnlockedForSession = true;
  }

  /// Memverifikasi PIN input pengguna terhadap PIN yang tersimpan.
  Future<bool> verifyPin(String inputPin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_keyPin);
    if (savedPin == null || savedPin.isEmpty) {
      _isUnlockedForSession = true;
      return true;
    }
    final matches = savedPin == inputPin;
    if (matches) {
      _isUnlockedForSession = true;
    }
    return matches;
  }

  /// Menghapus PIN dan menonaktifkan seluruh kunci aplikasi termasuk biometrik.
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPin);
    await prefs.setBool(_keyBiometricEnabled, false);
    _isUnlockedForSession = true;
  }

  /// Memeriksa apakah opsi biometrik diaktifkan oleh pengguna.
  Future<bool> isBiometricEnabled() async {
    final pinExists = await hasPin();
    if (!pinExists) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Mengaktifkan atau menonaktifkan opsi buka cepat via biometrik.
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Memeriksa ketersediaan sensor biometrik pada perangkat fisik.
  Future<bool> canAuthenticateWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Meminta otentikasi biometrik OS (sidik jari / wajah / kunci perangkat).
  Future<bool> authenticateBiometrics({
    String reason = 'Pindai sidik jari untuk membuka Gumpalan',
  }) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        _isUnlockedForSession = true;
      }
      return authenticated;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppLock] Biometric auth failed: $e');
      }
      return false;
    }
  }

  // Helper alias untuk backwards compatibility
  Future<bool> hasCustomPin() => hasPin();
  Future<void> setAppPin(String pin) => setPin(pin);
  Future<bool> verifyAppPin(String pin) => verifyPin(pin);
  Future<void> setLockEnabled(bool enabled) async {
    if (enabled) {
      final pinExists = await hasPin();
      if (!pinExists) {
        await setPin('123456');
      }
    } else {
      await removePin();
    }
  }
}
