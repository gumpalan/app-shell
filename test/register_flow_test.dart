import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/app.dart';
import 'package:gumpalan/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Register flow: submit name -> show instruction -> check status approve', (WidgetTester tester) async {
    bool isApproved = false;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/auth/v1/register') {
        return http.Response('{"deviceId":"dev_test_999","status":"pending"}', 202);
      }
      if (request.url.path == '/auth/v1/register/dev_test_999/status') {
        if (!isApproved) {
          return http.Response('{"deviceId":"dev_test_999","status":"pending","token":null}', 200);
        }
        return http.Response('{"deviceId":"dev_test_999","status":"approved","token":"tok_test_success"}', 200);
      }
      return http.Response('Not Found', 404);
    });

    final storage = InMemoryTokenStorage();
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
    );

    await tester.pumpWidget(GumpalanApp(authService: authService));
    await tester.pumpAndSettle();

    // Buka layar registrasi
    await tester.tap(find.byIcon(Icons.app_registration));
    await tester.pumpAndSettle();

    // Isi nama perangkat
    await tester.enterText(find.byType(TextField), 'HP Ruang Tamu');
    await tester.tap(find.text('Kirim Permintaan Pendaftaran'));
    await tester.pumpAndSettle();

    // Verifikasi tampilan instruksi terminal dan status pending
    expect(find.textContaining('Device ID: dev_test_999'), findsOneWidget);
    expect(find.textContaining('Status: pending'), findsOneWidget);
    expect(find.textContaining('auth device approve dev_test_999'), findsOneWidget);

    // Cek status saat masih pending
    await tester.tap(find.text('Cek Status Persetujuan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Status masih menunggu persetujuan di terminal.'), findsOneWidget);

    // Simulasikan persetujuan di terminal
    isApproved = true;

    // Cek status setelah disetujui
    await tester.tap(find.text('Cek Status Persetujuan'));
    await tester.pumpAndSettle();

    // Harus kembali ke Home screen dan token tersimpan
    expect(await storage.readToken(), equals('tok_test_success'));
    expect(find.text('Gumpalan'), findsOneWidget);
    expect(find.text('Perangkat Rumah'), findsOneWidget);
  });
}
