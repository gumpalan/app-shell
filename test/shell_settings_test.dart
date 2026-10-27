import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/services/shell_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'ShellSettingsService menyimpan dan membaca modul default dengan benar',
    () async {
      final service = ShellSettingsService();

      expect(await service.getDefaultDashboardModule(), isNull);

      await service.setDefaultDashboardModule('iot');
      expect(await service.getDefaultDashboardModule(), equals('iot'));

      await service.setDefaultDashboardModule('finance');
      expect(await service.getDefaultDashboardModule(), equals('finance'));
    },
  );
}
