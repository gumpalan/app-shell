import 'package:flutter_test/flutter_test.dart';
import 'package:gumpalan/app.dart';

void main() {
  testWidgets('GumpalanApp renders home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GumpalanApp());
    expect(find.text('Gumpalan'), findsOneWidget);
    expect(find.text('Perangkat Rumah'), findsOneWidget);
  });
}
