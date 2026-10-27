import 'dart:convert';
import 'dart:io' show Platform;

import 'package:core_api/core_api.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef DeviceNameResolver = Future<String> Function();
typedef DeviceFingerprintResolver = Future<String> Function();

/// Model profil pengguna dari backend autentikasi.
class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String roleName;
  final List<String> allowedModules;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roleName,
    required this.allowedModules,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as Map<String, dynamic>?;
    final modules =
        (role?['allowedModules'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      roleName: role?['name'] as String? ?? 'user',
      allowedModules: modules,
    );
  }
}

/// Model perangkat tertaut milik akun pengguna.
class UserDeviceItem {
  final String deviceId;
  final String name;
  final String status;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const UserDeviceItem({
    required this.deviceId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.approvedAt,
  });

  factory UserDeviceItem.fromJson(Map<String, dynamic> json) {
    final createdSec = json['createdAt'] as int? ?? 0;
    final approvedSec = json['approvedAt'] as int?;
    return UserDeviceItem(
      deviceId: json['id'] as String? ?? json['deviceId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdSec * 1000),
      approvedAt: approvedSec != null
          ? DateTime.fromMillisecondsSinceEpoch(approvedSec * 1000)
          : null,
    );
  }
}

/// Hasil dari operasi login akun pengguna.
class LoginResult {
  final String deviceId;
  final DeviceStatus status;
  final String? token;
  final UserProfile? user;

  const LoginResult({
    required this.deviceId,
    required this.status,
    this.token,
    this.user,
  });
}

/// Layanan orkestrasi autentikasi pada tingkat aplikasi (app-shell).
/// Menangani siklus hidup identitas perangkat, pendaftaran, login pengguna,
/// verifikasi status, profil pengguna, dan persistensi sesi lokal.
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
  }) : tokenStorage = storage ?? SharedPrefsTokenStorage(),
       apiClient =
           client ??
           ApiClient(
             baseUrl: dotenv.env['API_URL'] ?? 'http://127.0.0.1:8001',
             tokenStorage: storage ?? SharedPrefsTokenStorage(),
           ),
       deviceRegistration =
           registration ??
           DeviceRegistration(
             apiClient:
                 client ??
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

  /// Pendaftaran legacy perangkat tanpa akun pengguna.
  Future<RegistrationResult> register() async {
    final deviceName = await _deviceNameResolver();
    final fingerprint = await _deviceFingerprintResolver();

    const placeholderPublicKey = 'scaffold_placeholder_public_key';

    final result = await deviceRegistration.register(
      deviceName: deviceName,
      publicKeyPem: placeholderPublicKey,
      fingerprint: fingerprint,
    );
    await tokenStorage.writeDeviceId(result.deviceId);
    return result;
  }

  /// Mendaftarkan akun pengguna baru beserta perangkat saat ini.
  Future<RegistrationResult> registerWithUser({
    required String username,
    required String password,
    String? displayName,
  }) async {
    final deviceName = await _deviceNameResolver();
    final fingerprint = await _deviceFingerprintResolver();
    const placeholderPublicKey = 'scaffold_placeholder_public_key';

    final response = await apiClient.post(
      '/auth/v1/register',
      body: {
        'username': username,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'displayName': displayName,
        'name': deviceName,
        'fingerprint': fingerprint,
        'publicKey': placeholderPublicKey,
      },
    );

    if (response.statusCode == 202) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final devId = json['deviceId'] as String? ?? '';
      await tokenStorage.writeDeviceId(devId);
      final statusStr = json['status'] as String?;
      return RegistrationResult(
        deviceId: devId,
        status: _parseDeviceStatus(statusStr),
      );
    } else if (response.statusCode == 409) {
      throw Exception('Username sudah terdaftar.');
    } else {
      throw Exception(
        'Registrasi gagal dengan kode status: ${response.statusCode}',
      );
    }
  }

  /// Melakukan login akun pengguna dan mengaitkan perangkat saat ini.
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final deviceName = await _deviceNameResolver();
    final fingerprint = await _deviceFingerprintResolver();
    const placeholderPublicKey = 'scaffold_placeholder_public_key';

    final response = await apiClient.post(
      '/auth/v1/login',
      body: {
        'username': username,
        'password': password,
        'name': deviceName,
        'fingerprint': fingerprint,
        'publicKey': placeholderPublicKey,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final devId = json['deviceId'] as String? ?? '';
      final statusStr = json['status'] as String?;
      final token = json['token'] as String?;
      final userData = json['user'] as Map<String, dynamic>?;

      await tokenStorage.writeDeviceId(devId);
      if (token != null && token.isNotEmpty) {
        await tokenStorage.writeToken(token);
      }

      return LoginResult(
        deviceId: devId,
        status: _parseDeviceStatus(statusStr),
        token: token,
        user: userData != null ? UserProfile.fromJson(userData) : null,
      );
    } else if (response.statusCode == 401) {
      throw Exception('Username atau kata sandi tidak valid.');
    } else {
      throw Exception('Login gagal dengan kode status: ${response.statusCode}');
    }
  }

  /// Mengambil profil akun pengguna saat ini dari backend.
  Future<UserProfile> getUserProfile() async {
    final response = await apiClient.get('/auth/v1/user/profile');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    }
    throw Exception('Gagal memuat profil pengguna (${response.statusCode})');
  }

  /// Memperbarui nama tampilan pengguna.
  Future<void> updateProfile({required String displayName}) async {
    final response = await apiClient.put(
      '/auth/v1/user/profile',
      body: {'displayName': displayName},
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal memperbarui profil (${response.statusCode})');
    }
  }

  /// Mengganti kata sandi akun pengguna.
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await apiClient.put(
      '/auth/v1/user/password',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    if (response.statusCode == 401) {
      throw Exception('Kata sandi lama salah.');
    } else if (response.statusCode != 200) {
      throw Exception('Gagal mengganti kata sandi (${response.statusCode})');
    }
  }

  /// Mengambil daftar perangkat yang tertaut dengan akun pengguna ini.
  Future<List<UserDeviceItem>> listUserDevices() async {
    final response = await apiClient.get('/auth/v1/user/devices');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) => UserDeviceItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      'Gagal mengambil daftar perangkat (${response.statusCode})',
    );
  }

  /// Mencabut izin perangkat tertentu yang tertaut pada akun pengguna ini.
  Future<void> revokeUserDevice(String deviceId) async {
    final response = await apiClient.delete('/auth/v1/user/devices/$deviceId');
    if (response.statusCode != 200) {
      throw Exception('Gagal mencabut perangkat (${response.statusCode})');
    }
  }

  /// Memverifikasi status persetujuan perangkat pada server backend.
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

  static DeviceStatus _parseDeviceStatus(String? status) {
    switch (status) {
      case 'approved':
        return DeviceStatus.approved;
      case 'revoked':
        return DeviceStatus.revoked;
      case 'pending':
        return DeviceStatus.pending;
      default:
        return DeviceStatus.unknown;
    }
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
