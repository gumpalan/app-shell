import 'package:core_api/core_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/app.dart';
import 'package:gumpalan/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Implementasi tiruan penyimpanan token untuk pengujian terisolasi.
// ignore: library_names
class FakeStorage extends SharedPrefsTokenStorage {
  String? _token;
  String? _deviceId;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> deleteToken() async => _token = null;

  @override
  Future<String?> readDeviceId() async => _deviceId;

  @override
  Future<void> writeDeviceId(String deviceId) async => _deviceId = deviceId;

  @override
  Future<void> clear() async {
    _token = null;
    _deviceId = null;
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_URL=http://127.0.0.1:8001\nMODULES=iot\n');
  });

  testWidgets(
    'Alur autentikasi: pendaftaran, verifikasi status pending, persetujuan admin, hingga penyimpanan token',
    (WidgetTester tester) async {
      bool isApproved = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/register') {
          return http.Response(
            '{"deviceId":"dev_test_999","status":"pending"}',
            202,
          );
        }
        if (request.url.path == '/auth/v1/register/dev_test_999/status') {
          if (!isApproved) {
            return http.Response(
              '{"deviceId":"dev_test_999","status":"pending","token":null}',
              200,
            );
          }
          return http.Response(
            '{"deviceId":"dev_test_999","status":"approved","token":"tok_test_success"}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final storage = FakeStorage();
      final apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:8001',
        tokenStorage: storage,
        client: mockClient,
      );
      final reg = DeviceRegistration(apiClient: apiClient);
      final authService = AuthService(
        storage: storage,
        client: apiClient,
        registration: reg,
        deviceNameResolver: () async => 'Test Device',
        deviceFingerprintResolver: () async => 'test:fingerprint:001',
      );

      await tester.pumpWidget(GumpalanApp(authService: authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Gumpalan'), findsWidgets);
      expect(find.text('Daftarkan Perangkat Ini'), findsOneWidget);

      await tester.tap(find.text('Daftarkan Perangkat Ini'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Menunggu Persetujuan'), findsOneWidget);
      expect(find.textContaining('dev_test_999'), findsWidgets);
      expect(
        find.textContaining('auth device approve dev_test_999'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Cek Status'));
      await tester.tap(find.text('Cek Status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Menunggu Persetujuan'), findsOneWidget);

      isApproved = true;

      await tester.ensureVisible(find.text('Cek Status'));
      await tester.tap(find.text('Cek Status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(await storage.readToken(), equals('tok_test_success'));
    },
  );

  testWidgets(
    'Alur pencabutan otorisasi: pembersihan token lokal dan pengalihan ke status Dicabut',
    (tester) async {
      final storage = FakeStorage();
      await storage.writeDeviceId('dev_revoked_123');
      await storage.writeToken('old_valid_token');

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/register/dev_revoked_123/status') {
          return http.Response(
            '{"deviceId":"dev_revoked_123","status":"revoked","name":"My Phone"}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:8001',
        tokenStorage: storage,
        client: mockClient,
      );
      final reg = DeviceRegistration(apiClient: apiClient);
      final authService = AuthService(
        storage: storage,
        client: apiClient,
        registration: reg,
        deviceNameResolver: () async => 'My Phone',
        deviceFingerprintResolver: () async => 'test:fp:revoked',
      );

      expect(await storage.readToken(), equals('old_valid_token'));

      await tester.pumpWidget(GumpalanApp(authService: authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(await storage.readToken(), isNull);
      expect(find.text('Akses Dicabut'), findsOneWidget);
      expect(find.text('Dicabut'), findsOneWidget);
      expect(find.text('Daftar Ulang'), findsOneWidget);
    },
  );

  testWidgets(
    'Proteksi dashboard: pengalihan otomatis saat otorisasi dicabut di latar belakang',
    (tester) async {
      var isRevoked = false;
      final storage = FakeStorage();
      await storage.writeDeviceId('dev_live_123');
      await storage.writeToken('live_token');

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/register/dev_live_123/status') {
          if (!isRevoked) {
            return http.Response(
              '{"deviceId":"dev_live_123","status":"approved","token":"live_token"}',
              200,
            );
          }
          return http.Response(
            '{"deviceId":"dev_live_123","status":"revoked"}',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:8001',
        tokenStorage: storage,
        client: mockClient,
      );
      final reg = DeviceRegistration(apiClient: apiClient);
      final authService = AuthService(
        storage: storage,
        client: apiClient,
        registration: reg,
        deviceNameResolver: () async => 'Live Device',
        deviceFingerprintResolver: () async => 'test:fp:live',
      );

      await tester.pumpWidget(GumpalanApp(authService: authService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Gumpalan'), findsWidgets);

      isRevoked = true;

      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(await storage.readToken(), isNull);
      expect(find.text('Akses Dicabut'), findsOneWidget);
    },
  );
}
