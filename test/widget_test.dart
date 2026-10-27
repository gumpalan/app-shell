import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/app.dart';
import 'package:gumpalan/services/auth_service.dart';

import 'register_flow_test.dart' show FakeStorage;

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_URL=http://127.0.0.1:8080\nMODULES=iot\n');
  });

  testWidgets('GumpalanApp splash → landing screen smoke test', (
    WidgetTester tester,
  ) async {
    final storage = FakeStorage();
    final authService = AuthService(storage: storage);

    await tester.pumpWidget(GumpalanApp(authService: authService));

    // Verifikasi keberadaan widget pada tahap inisialisasi awal
    expect(find.byType(GumpalanApp), findsOneWidget);

    // Menunggu penyelesaian rute awal dari _resolveStartRoute
    await tester.pumpAndSettle();

    // Memverifikasi navigasi ke LandingScreen saat perangkat belum terdaftar
    expect(find.text('Gumpalan'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Belum punya akun? Buat Akun'), findsOneWidget);
  });
}
