import 'package:flutter_test/flutter_test.dart';
import 'package:is_agi/main.dart' as app;

void main() {
  testWidgets('Eksik bağlantı ayarları açıklayıcı ekran gösterir', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.textContaining('İş Ağı bağlantısı henüz ayarlanmadı.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
