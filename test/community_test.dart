import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:is_agi/main.dart';

void main() {
  test('Fotoğraf türü dosya içeriğinden doğrulanır', () {
    expect(imageContentType(Uint8List.fromList([255,216,255,0])), 'image/jpeg');
    expect(imageContentType(Uint8List.fromList([137,80,78,71,13,10,26,10])), 'image/png');
    expect(imageContentType(Uint8List.fromList('RIFF0000WEBP'.codeUnits)), 'image/webp');
    expect(imageContentType(Uint8List.fromList('not a photo'.codeUnits)), isNull);
  });

  testWidgets('Boş gönderi yayınlanamaz', (tester) async {
    var published = false;
    await tester.pumpWidget(MaterialApp(home: CommunityComposer(onPublish: (_, __, ___) async { published = true; })));
    await tester.tap(find.widgetWithText(FilledButton, 'Paylaş'));
    await tester.pump();
    expect(published, false);
    expect(find.text('Bir açıklama veya fotoğraf/video ekle.'), findsOneWidget);
  });

  testWidgets('Yayınlama sırasında tekrar gönderim engellenir ve hata taslağı korur', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CommunityComposer(onPublish: (_, __, ___) { calls++; return pending.future; })));
    await tester.enterText(find.byType(TextField), 'Bugün birlikte ürettik.');
    await tester.tap(find.widgetWithText(FilledButton, 'Paylaş'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    pending.completeError(Exception('Bağlantı kesildi'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün birlikte ürettik.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Paylaş'), findsOneWidget);
  });

  testWidgets('Hikâye için medya zorunludur', (tester) async {
    var published = false;
    await tester.pumpWidget(MaterialApp(home: CommunityComposer(story: true, onPublish: (_, __, ___) async { published = true; })));
    await tester.tap(find.widgetWithText(FilledButton, 'Paylaş'));
    await tester.pump();
    expect(published, false);
    expect(find.text('Hikâyene fotoğraf veya video ekle.'), findsOneWidget);
  });

  testWidgets('Geçici yenileme hatasında önceki sohbet içeriği korunur', (tester) async {
    var fail = false;
    final key = GlobalKey<CommunityListState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CommunityList(key: key,
      load: () async { if (fail) throw Exception('offline'); return [{'body': 'Merhaba'}]; },
      item: (row) => Text(row['body'] as String)))));
    await tester.pumpAndSettle();
    expect(find.text('Merhaba'), findsOneWidget);
    fail = true;
    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
