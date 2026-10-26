import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/screens/pin_screens.dart';
import 'package:gumpalan/services/app_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PinSetupScreen Tests', () {
    testWidgets('Input PIN 6 digit dan konfirmasi berhasil', (tester) async {
      final lockService = AppLockService();
      bool? setupResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                setupResult = await Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => PinSetupScreen(appLockService: lockService),
                  ),
                );
              },
              child: const Text('Open Setup'),
            ),
          ),
        ),
      );

      // Buka setup screen
      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Buat PIN Baru'), findsOneWidget);

      // Masukkan 6 digit: 1, 2, 3, 4, 5, 6
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Sekarang masuk ke tahap konfirmasi
      expect(find.text('Konfirmasi PIN'), findsOneWidget);

      // Masukkan 6 digit konfirmasi yang sama
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Screen harus pop dan mengembalikan true
      expect(setupResult, isTrue);
      expect(await lockService.hasPin(), isTrue);
      expect(await lockService.verifyPin('123456'), isTrue);
    });
  });

  group('PinLockScreen Tests', () {
    testWidgets('Kunci PIN verifikasi salah lalu benar', (tester) async {
      final lockService = AppLockService();
      await lockService.setPin('654321');

      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinLockScreen(
            appLockService: lockService,
            onUnlocked: () => unlocked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Masukkan PIN'), findsOneWidget);

      // Ketik PIN salah: 1, 2, 3, 4, 5, 6
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('PIN salah'), findsOneWidget);
      expect(unlocked, isFalse);

      // Ketik PIN yang benar: 6, 5, 4, 3, 2, 1
      for (final digit in ['6', '5', '4', '3', '2', '1']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });
  });
}
