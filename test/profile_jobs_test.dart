import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:is_agi/main.dart';

void main(){
  testWidgets('İlan kartında sahiplik eylemleri yalnızca sağlandığında görünür',(tester)async{
    final job={'title':'Usta aranıyor','description':'Deneyimli usta','city':'Bursa','status':'open'};
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:JobCard(job:job))));
    expect(find.text('Düzenle'),findsNothing);expect(find.text('Sil'),findsNothing);
    var edits=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:JobCard(job:job,onEdit:()=>edits++,onDelete:(){}))));
    await tester.tap(find.text('Düzenle'));expect(edits,1);expect(find.text('Sil'),findsOneWidget);
  });
  testWidgets('İlan düzenleme mevcut değerleri yükler ve değişikliği kaydeder',(tester)async{
    Map<String,dynamic>? saved;
    await tester.pumpWidget(MaterialApp(home:JobEditor(initial:{'title':'Eski başlık','description':'Eski açıklama','city':'Bursa','status':'closed'},onSave:(values)async{saved=values;})));
    expect(find.text('Eski başlık'),findsOneWidget);expect(find.text('Başvuruya kapalı'),findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0),'Yeni iş başlığı');
    await tester.ensureVisible(find.text('Değişiklikleri kaydet'));await tester.tap(find.text('Değişiklikleri kaydet'));await tester.pumpAndSettle();
    expect(saved?['title'],'Yeni iş başlığı');expect(saved?['description'],'Eski açıklama');expect(saved?['status'],'closed');expect(saved?.containsKey('owner_id'),false);
  });
  testWidgets('Geçersiz ilan sunucuya gönderilmez',(tester)async{
    var writes=0;await tester.pumpWidget(MaterialApp(home:JobEditor(onSave:(_)async{writes++;})));
    await tester.ensureVisible(find.text('Yayınla'));await tester.tap(find.text('Yayınla'));await tester.pump();expect(writes,0);
  });
  testWidgets('Profilde alanlar boşaltılabilir ve yetenekler tekilleştirilir',(tester)async{
    Map<String,dynamic>? saved;
    await tester.pumpWidget(MaterialApp(home:ProfileEditor(initial:{'full_name':'Örnek Usta','profession':'Elektrikçi','city':'Bursa','bio':'Deneyim','skills':['Elektrik'],'available':true},onSave:(values)async{saved=values;})));
    await tester.enterText(find.byType(TextField).at(0),'');
    await tester.enterText(find.byType(TextField).at(2),'Elektrik, Elektrik, Bakım');
    await tester.enterText(find.byType(TextField).at(3),'');
    await tester.scrollUntilVisible(find.text('Profili kaydet'),250,scrollable:find.byType(Scrollable).last);await tester.tap(find.text('Profili kaydet'));await tester.pumpAndSettle();
    expect(saved?['full_name'],'');expect(saved?['bio'],'');expect(saved?['skills'],['Elektrik','Bakım']);expect(saved?.containsKey('avatar_url'),false);
  });
  testWidgets('Silme onayı iptal edilince işlem yapılmaz',(tester)async{
    var removed=false;
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()async{
      if(await confirmRemoval(context,'Silinsin mi?','İlan ve başvurular silinir.'))removed=true;
    },child:const Text('İlanı sil'))))));
    await tester.tap(find.text('İlanı sil'));await tester.pumpAndSettle();await tester.tap(find.text('Vazgeç'));await tester.pumpAndSettle();expect(removed,false);
  });
  test('Profil temizliği hesap veya gönderi silme alanı içermez',(){
    expect(emptyProfileValues['avatar_url'],isNull);expect(emptyProfileValues['skills'],isEmpty);expect(emptyProfileValues['full_name'],'');expect(emptyProfileValues.containsKey('id'),false);
  });
}
