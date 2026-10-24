import 'package:core_api/core_api.dart';

class AuthService {
  final TokenStorage tokenStorage;
  final ApiClient apiClient;
  final DeviceRegistration deviceRegistration;

  String? registeredDeviceId;

  AuthService({
    TokenStorage? storage,
    ApiClient? client,
    DeviceRegistration? registration,
  })  : tokenStorage = storage ?? InMemoryTokenStorage(),
        apiClient = client ??
            ApiClient(
              baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8080'),
              tokenStorage: storage ?? InMemoryTokenStorage(),
            ),
        deviceRegistration = registration ??
            DeviceRegistration(
              apiClient: client ??
                  ApiClient(
                    baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8080'),
                    tokenStorage: storage ?? InMemoryTokenStorage(),
                  ),
            );

  Future<bool> isAuthenticated() async {
    final token = await tokenStorage.readToken();
    return token != null && token.isNotEmpty;
  }

  Future<RegistrationResult> register(String deviceName) async {
    // Generate dummy PEM key placeholder untuk pendaftaran perangkat
    const dummyKey = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\n-----END PUBLIC KEY-----';
    final result = await deviceRegistration.register(
      deviceName: deviceName,
      publicKeyPem: dummyKey,
    );
    registeredDeviceId = result.deviceId;
    return result;
  }

  Future<DeviceStatusResult> checkStatus() async {
    if (registeredDeviceId == null || registeredDeviceId!.isEmpty) {
      return const DeviceStatusResult(
        deviceId: '',
        status: DeviceStatus.unknown,
      );
    }

    final result = await deviceRegistration.checkStatus(registeredDeviceId!);
    if (result.status == DeviceStatus.approved && result.token != null) {
      await tokenStorage.writeToken(result.token!);
    }
    return result;
  }

  Future<void> logout() async {
    await tokenStorage.deleteToken();
    registeredDeviceId = null;
  }
}
