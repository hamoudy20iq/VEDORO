import 'package:flutter_test/flutter_test.dart';
import 'package:vedoro/main.dart';

void main() {
  testWidgets('VEDORO app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const VedoroApp());

    expect(find.text('VEDORO'), findsWidgets);
    expect(find.text('الرئيسية'), findsOneWidget);
  });
}
