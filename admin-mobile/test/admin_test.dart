import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:is_agi_yonetim/main.dart';

class FakeApi implements AdminApi {
  bool deny = false;
  int logins = 0, writes = 0;
  Completer<void>? pending;
  @override Future<void> login(String email, String password) async {logins++;if (pending != null) await pending!.future;if (deny) throw Exception('denied');}
  @override Future<void> logout() async {}
  @override Future<Row> overview() async => {'users':3,'posts':1,'reports':0,'jobs':0,'stories':0,'suspended':0};
  @override Future<Row> list(String section, String search, int offset) async => {'rows':<Row>[],'total':0};
  @override Future<void> suspend(String id, bool suspended, String reason) async {writes++;}
  @override Future<void> moderate(String kind, String id, bool hidden, String reason) async {writes++;}
  @override Future<void> review(String id, String status, String note) async {writes++;}
  @override Future<int> announce(String body, String request) async {writes++;return 3;}
}

void main() {
  test('Yalnızca uygulamanın kendi medya adresleri kabul edilir', () {
    expect(safeMediaUrl('javascript:alert(1)'),isNull);
    expect(safeMediaUrl('https://example.com/fake.mp4'),isNull);
    expect(safeMediaUrl('https://ikoyhonpgujbughdsouu.supabase.co/storage/v1/object/public/post-media/a.jpg'),isNotNull);
  });
  testWidgets('Boş giriş sunucuya gönderilmez', (tester) async {
    final api=FakeApi();await tester.pumpWidget(AdminApp(api:api));
    await tester.tap(find.text('Giriş yap'));await tester.pump();expect(api.logins,0);
  });
  testWidgets('Devam eden girişte çift gönderim engellenir', (tester) async {
    final api=FakeApi()..pending=Completer<void>();await tester.pumpWidget(AdminApp(api:api));
    await tester.enterText(find.byType(TextFormField).at(0),'admin@example.com');
    await tester.enterText(find.byType(TextFormField).at(1),'test-password');
    await tester.tap(find.text('Giriş yap'));await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);expect(api.logins,1);
    api.pending!.complete();await tester.pumpAndSettle();expect(find.text('Topluluğun bir bakışta.'),findsOneWidget);
    expect(find.text('Mesajlar'),findsNothing);
  });
  testWidgets('Yetkisiz giriş yönetim ekranını açmaz', (tester) async {
    final api=FakeApi()..deny=true;await tester.pumpWidget(AdminApp(api:api));
    await tester.enterText(find.byType(TextFormField).at(0),'other@example.com');
    await tester.enterText(find.byType(TextFormField).at(1),'test-password');
    await tester.tap(find.text('Giriş yap'));await tester.pumpAndSettle();
    expect(find.text('Topluluğun bir bakışta.'),findsNothing);expect(api.writes,0);
  });
  testWidgets('Yönetim işlemi için gerekçe zorunludur', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:ActionReason(title:'Askıya al')));
    await tester.tap(find.text('İşlemi onayla'));await tester.pump();
    expect(find.text('En az 3 karakterlik bir gerekçe yaz.'),findsOneWidget);
  });
}
