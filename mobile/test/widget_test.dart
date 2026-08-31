import 'package:flutter_test/flutter_test.dart';

import 'package:ainote_mobile/main.dart';

void main() {
  testWidgets('Uygulama başlığı görünür', (tester) async {
    await tester.pumpWidget(const AinoteApp());
    expect(find.text('CRM ANALİZ'), findsOneWidget);
  });
}
