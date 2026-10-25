import 'dart:io' show Platform;

import 'package:core_api/core_api.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef DeviceNameResolver = Future<String> Function();
typedef DeviceFingerprintResolver = Future<String> Function();

/// Layanan orkestrasi autentikasi pada tingkat aplikasi (app-shell).
/// Menangani siklus hidup identitas perangkat, pendaftaran, verifikasi status,
/// dan persistensi sesi lokal.
class AuthService {
  final SharedPrefsTokenStorage tokenStorage;
  final ApiClient apiClient;
  final DeviceRegistration deviceRegistration;
  final DeviceNameResolver _deviceNameResolver;
  final DeviceFingerprintResolver _deviceFingerprintResolver;

  AuthService({
    SharedPrefsTokenStorage? storage,
    ApiClient? client,
    DeviceRegistration? registration,
    DeviceNameResolver? deviceNameResolver,
    DeviceFingerprintResolver? deviceFingerprintResolver,
  })  : tokenStorage = storage ?? SharedPrefsTokenStorage(),
        apiClient = client ??
            ApiClient(
              baseUrl: dotenv.env['API_URL'] ?? 'http://127.0.0.1:8001',
              tokenStorage: storage ?? SharedPrefsTokenStorage(),
            ),
        deviceRegistration = registration ??
            DeviceRegistration(
              apiClient: client ??
                  ApiClient(
                    baseUrl: dotenv.env['API_URL'] ?? 'http://127.0.0.1:8001',
                    tokenStorage: storage ?? SharedPrefsTokenStorage(),
                  ),
            ),
        _deviceNameResolver = deviceNameResolver ?? _resolveDeviceName,
        _deviceFingerprintResolver =
            deviceFingerprintResolver ?? _resolveDeviceFingerprint;

  /// Memeriksa apakah token autentikasi tersimpan di media lokal.
  Future<bool> isAuthenticated() async {
    final token = await tokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  /// Mengambil identitas unik perangkat yang tersimpan secara lokal.
  Future<String?> getStoredDeviceId() {
    return tokenStorage.readDeviceId();
  }

  /// Mendaftarkan perangkat ke auth service menggunakan fingerprint hardware deterministik.
  Future<RegistrationResult> register() async {
    final deviceName = await _deviceNameResolver();
    final fingerprint = await _deviceFingerprintResolver();

    // Nilai kunci publik sementara hingga modul kriptografi asimetris diintegrasikan.
    const placeholderPublicKey = 'scaffold_placeholder_public_key';

    final result = await deviceRegistration.register(
      deviceName: deviceName,
      publicKeyPem: placeholderPublicKey,
      fingerprint: fingerprint,
    );
    await tokenStorage.writeDeviceId(result.deviceId);
    return result;
  }

  /// Memverifikasi status persetujuan perangkat pada server backend.
  /// Jika status perangkat disetujui, token sesi disimpan.
  /// Jika status dicabut (revoked) atau tidak valid, token lokal otomatis dibersihkan.
  Future<DeviceStatusResult> checkStatus([String? deviceId]) async {
    final id = deviceId ?? await tokenStorage.readDeviceId();
    if (id == null || id.isEmpty) {
      return const DeviceStatusResult(
        deviceId: '',
        status: DeviceStatus.unknown,
      );
    }
    final result = await deviceRegistration.checkStatus(id);
    if (result.status == DeviceStatus.approved && result.token != null) {
      await tokenStorage.writeToken(result.token!);
    } else if (result.status == DeviceStatus.revoked ||
        result.status == DeviceStatus.unknown) {
      await tokenStorage.deleteToken();
    }
    return result;
  }

  /// Menghapus seluruh sesi autentikasi dan identitas perangkat dari media lokal.
  Future<void> logout() async {
    await tokenStorage.clear();
  }

  /// Menentukan nama deskriptif perangkat berdasarkan platform sistem operasi.
  static Future<String> _resolveDeviceName() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        return '${d.manufacturer} ${d.model}';
      } else if (Platform.isIOS) {
        final d = await info.iosInfo;
        return d.utsname.machine;
      } else if (Platform.isLinux) {
        final d = await info.linuxInfo;
        return d.prettyName;
      } else if (Platform.isMacOS) {
        final d = await info.macOsInfo;
        return d.computerName;
      } else if (Platform.isWindows) {
        final d = await info.windowsInfo;
        return d.computerName;
      }
    } catch (_) {}
    return 'Unknown Device';
  }

  /// Mengambil fingerprint hardware deterministik untuk mencegah pendaftaran duplikat.
  static Future<String> _resolveDeviceFingerprint() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        return 'android:${d.id}:${d.hardware}:${d.fingerprint}';
      } else if (Platform.isIOS) {
        final d = await info.iosInfo;
        final id = d.identifierForVendor ?? d.utsname.machine;
        return 'ios:$id:${d.systemVersion}';
      } else if (Platform.isLinux) {
        final d = await info.linuxInfo;
        return 'linux:${d.machineId ?? d.id}:${d.buildId ?? ""}';
      } else if (Platform.isMacOS) {
        final d = await info.macOsInfo;
        return 'macos:${d.systemGUID ?? d.computerName}:${d.kernelVersion}';
      } else if (Platform.isWindows) {
        final d = await info.windowsInfo;
        return 'windows:${d.deviceId}:${d.computerName}';
      }
    } catch (_) {}
    return 'generic:${Platform.operatingSystem}:${Platform.localHostname}';
  }
}
