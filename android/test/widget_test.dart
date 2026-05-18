import 'package:flutter_test/flutter_test.dart';

import 'package:edu/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EduApp());
    expect(find.text('Edu'), findsOneWidget);
  });
}
