import 'dart:convert';

import 'package:core_api/core_api.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/services/app_lock_service.dart';
import 'package:gumpalan/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_flow_test.dart' show FakeStorage;

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_URL=http://127.0.0.1:8001\n');
  });

  group('AuthService User & Device Management', () {
    test('registerWithUser mengirim username dan data perangkat dengan benar', () async {
      final storage = FakeStorage();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/register') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['username'], equals('testuser'));
          expect(body['password'], equals('secretpass'));
          expect(body['name'], equals('Device A'));
          expect(body['fingerprint'], equals('fp_test_123'));
          return http.Response(
            '{"deviceId":"dev_reg_01","status":"pending"}',
            202,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:8001',
        tokenStorage: storage,
        client: mockClient,
      );
      final auth = AuthService(
        storage: storage,
        client: apiClient,
        deviceNameResolver: () async => 'Device A',
        deviceFingerprintResolver: () async => 'fp_test_123',
      );

      final res = await auth.registerWithUser(
        username: 'testuser',
        password: 'secretpass',
      );

      expect(res.deviceId, equals('dev_reg_01'));
      expect(res.status, equals(DeviceStatus.pending));
      expect(await storage.readDeviceId(), equals('dev_reg_01'));
    });

    test('login menyimpan token dan deviceId saat status approved', () async {
      final storage = FakeStorage();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/login') {
          return http.Response(
            jsonEncode({
              'deviceId': 'dev_login_01',
              'status': 'approved',
              'token': 'jwt_user_token_abc',
              'user': {
                'id': 'usr_1',
                'username': 'alice',
                'displayName': 'Alice Smith',
                'role': {
                  'name': 'admin',
                  'allowedModules': ['iot', 'analytics'],
                },
              },
            }),
            200,
          );
        }
        return http.Response('Unauthorized', 401);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:8001',
        tokenStorage: storage,
        client: mockClient,
      );
      final auth = AuthService(
        storage: storage,
        client: apiClient,
        deviceNameResolver: () async => 'Laptop Alice',
        deviceFingerprintResolver: () async => 'fp_laptop_123',
      );

      final res = await auth.login(username: 'alice', password: 'password123');

      expect(res.deviceId, equals('dev_login_01'));
      expect(res.status, equals(DeviceStatus.approved));
      expect(res.token, equals('jwt_user_token_abc'));
      expect(res.user?.username, equals('alice'));
      expect(res.user?.roleName, equals('admin'));
      expect(res.user?.allowedModules, contains('iot'));

      expect(await storage.readToken(), equals('jwt_user_token_abc'));
      expect(await storage.readDeviceId(), equals('dev_login_01'));
    });

    test('getUserProfile, updateProfile, dan updatePassword beroperasi sesuai protokol API', () async {
      final storage = FakeStorage();
      await storage.writeToken('valid_jwt');

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/user/profile' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 'usr_2',
              'username': 'bob',
              'displayName': 'Bob Jones',
              'role': {'name': 'user', 'allowedModules': ['iot']},
            }),
            200,
          );
        }
        if (request.url.path == '/auth/v1/user/profile' && request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['displayName'], equals('Bob Super'));
          return http.Response(
            jsonEncode({'message': 'Profile updated successfully'}),
            200,
          );
        }
        if (request.url.path == '/auth/v1/user/password' && request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['oldPassword'], equals('oldpass'));
          expect(body['newPassword'], equals('newpass123'));
          return http.Response(
            jsonEncode({'message': 'Password updated successfully'}),
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
      final auth = AuthService(storage: storage, client: apiClient);

      final profile = await auth.getUserProfile();
      expect(profile.username, equals('bob'));
      expect(profile.displayName, equals('Bob Jones'));

      await auth.updateProfile(displayName: 'Bob Super');
      await auth.updatePassword(oldPassword: 'oldpass', newPassword: 'newpass123');
    });

    test('listUserDevices dan revokeUserDevice memproses daftar dan pencabutan perangkat', () async {
      final storage = FakeStorage();
      await storage.writeToken('valid_jwt');

      final mockClient = MockClient((request) async {
        if (request.url.path == '/auth/v1/user/devices' && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'dev_1',
                'name': 'Pixel 8',
                'status': 'approved',
                'createdAt': 1700000000,
                'approvedAt': 1700000100,
              },
              {
                'id': 'dev_2',
                'name': 'iPad Pro',
                'status': 'pending',
                'createdAt': 1700000200,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/auth/v1/user/devices/dev_2' && request.method == 'DELETE') {
          return http.Response(
            jsonEncode({'message': 'Device revoked successfully'}),
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
      final auth = AuthService(storage: storage, client: apiClient);

      final devices = await auth.listUserDevices();
      expect(devices.length, equals(2));
      expect(devices[0].deviceId, equals('dev_1'));
      expect(devices[0].name, equals('Pixel 8'));
      expect(devices[1].status, equals('pending'));

      await auth.revokeUserDevice('dev_2');
    });
  });

  group('AppLockService PIN and Lock Settings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Pengaturan status lock dan verifikasi PIN tersimpan di persistent prefs', () async {
      final lockService = AppLockService();

      expect(await lockService.isLockEnabled(), isFalse);
      expect(await lockService.hasCustomPin(), isFalse);

      await lockService.setLockEnabled(true);
      expect(await lockService.isLockEnabled(), isTrue);

      await lockService.setAppPin('1234');
      expect(await lockService.hasCustomPin(), isTrue);

      expect(await lockService.verifyAppPin('0000'), isFalse);
      expect(await lockService.verifyAppPin('1234'), isTrue);
      expect(lockService.isUnlockedForSession, isTrue);

      lockService.lockSession();
      expect(lockService.isUnlockedForSession, isFalse);
    });
  });
}
