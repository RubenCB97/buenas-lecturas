import 'package:flutter_test/flutter_test.dart';
import 'package:buenas_lecturas_app/main.dart';

void main() {
  testWidgets('App starts without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const BuenasLecturasApp());
    expect(find.byType(BuenasLecturasApp), findsOneWidget);
  });
}
