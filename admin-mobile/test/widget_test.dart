import 'package:flutter_test/flutter_test.dart';
import 'package:is_agi_yonetim/main.dart' as app;

void main() {
  testWidgets('Eksik yapılandırma anlaşılır ekran gösterir', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Yönetim bağlantısı yapılandırılmadı.'), findsOneWidget);
  });
}

