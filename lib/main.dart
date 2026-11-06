import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'community.dart';
part 'visual_v02.dart';
part 'profile_jobs.dart';

const professions = ['İnşaat ustası','Elektrikçi','Tesisatçı','Alçıpan ustası','Sıva ustası','Mimar','Mühendis','Öğretmen','Yazılımcı','Tasarımcı','Kuaför','Nakliyeci','Muhasebeci','Diğer'];
final db = Supabase.instance.client;
String get me => db.auth.currentUser!.id;
Map<String,dynamic> row(dynamic x) => Map<String,dynamic>.from(x as Map);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
    runApp(const App());
  } else {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24),child: Text('İş Ağı bağlantısı henüz ayarlanmadı. GitHub Secrets içine SUPABASE_URL ve SUPABASE_ANON_KEY ekleyin.'))))));
  }
}

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'İş Ağı', debugShowCheckedModeBanner: false, navigatorObservers: [communityRoutes],
    theme: ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor: const Color(0xff073765)),scaffoldBackgroundColor:const Color(0xfff3f6fa),cardTheme:CardThemeData(color:Colors.white,elevation:1,shadowColor:const Color(0x16073565),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(),contentPadding:EdgeInsets.symmetric(horizontal:12,vertical:13))),
    home: StreamBuilder<AuthState>(stream:db.auth.onAuthStateChange,builder:(context,snapshot) => db.auth.currentUser == null ? const AuthPage() : const Shell()),
  );
}

void notice(BuildContext c,Object error) { if(c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(error.toString().replaceFirst('PostgrestException(message: ','').replaceFirst('AuthException(message: ','')))); }
Future<void> runSafe(BuildContext c,Future<void> Function() action) async { try { await action(); } catch(e){ if(c.mounted) notice(c,e); } }

class AuthPage extends StatefulWidget { const AuthPage({super.key}); @override State<AuthPage> createState()=>_AuthPageState(); }
class _AuthPageState extends State<AuthPage> {
  final email=TextEditingController(),password=TextEditingController(),name=TextEditingController(); bool signUp=false, busy=false;
  @override void dispose(){email.dispose();password.dispose();name.dispose();super.dispose();}
  @override Widget build(BuildContext context)=> Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:420),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Icon(Icons.hub_rounded,size:72,color:Color(0xff1858a7)),const SizedBox(height:16),const Text('İş Ağı',textAlign:TextAlign.center,style:TextStyle(fontSize:34,fontWeight:FontWeight.w800)),const Text('Mesleğini göster, çevreni büyüt, iş bul.',textAlign:TextAlign.center),const SizedBox(height:28),
    if(signUp)...[TextField(controller:name,decoration:const InputDecoration(labelText:'Ad soyad')),const SizedBox(height:12)],
    TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'E-posta')),const SizedBox(height:12),TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Şifre (en az 6 karakter)')),const SizedBox(height:16),
    FilledButton(onPressed:busy?null:() async {setState(()=>busy=true);await runSafe(context,() async { if(signUp){await db.auth.signUp(email:email.text.trim(),password:password.text,data:{'full_name':name.text.trim()});if(context.mounted)notice(context,'Kayıt oluşturuldu. E-posta onayı açıksa gelen kutunuzu kontrol edin.');}else{await db.auth.signInWithPassword(email:email.text.trim(),password:password.text);} });if(mounted)setState(()=>busy=false);},child:Padding(padding:const EdgeInsets.all(12),child:Text(signUp?'Hesap oluştur':'Giriş yap'))),
    TextButton(onPressed:()=>setState(()=>signUp=!signUp),child:Text(signUp?'Hesabım var, giriş yap':'Yeni hesap oluştur')),
  ]))))));
}

class Shell extends StatefulWidget {const Shell({super.key});@override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell> {
 int selected=0;
 int revision=0;
 Future<void> createPost()async{
  final action=await showModalBottomSheet<String>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
   const ListTile(title:Text('Paylaşım oluştur',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
   ListTile(leading:const Icon(Icons.add_photo_alternate_outlined),title:const Text('Sosyal gönderi'),onTap:()=>Navigator.pop(c,'post')),
   ListTile(leading:const Icon(Icons.auto_stories_outlined),title:const Text('Hikâye'),onTap:()=>Navigator.pop(c,'story')),
   ListTile(leading:const Icon(Icons.work_outline),title:const Text('İş ilanı'),onTap:()=>Navigator.pop(c,'job')),
  ])));
  if(!mounted||action==null)return;
  if(action=='job'){setState(()=>selected=1);return;}
  final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>CommunityComposer(story:action=='story')));
  if(ok==true&&mounted)setState(()=>revision++);
 }
 @override Widget build(BuildContext c){
  final pages=[FeedPage(key:ValueKey('feed-$revision')),const JobsPage(),const DiscoverPage(),const InboxPage(),ProfilePage(key:ValueKey('profile-$revision'),userId:me)];
  return Scaffold(
   appBar:AppBar(backgroundColor:iaNavy,foregroundColor:Colors.white,
    title:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.hub_rounded),SizedBox(width:9),Text('İş Ağı',style:TextStyle(fontWeight:FontWeight.w800,fontSize:24))]),
    actions:[const NotificationBell(),IconButton(tooltip:'Ara',onPressed:()=>setState(()=>selected=2),icon:const Icon(Icons.search)),IconButton(tooltip:'Profilim',onPressed:()=>setState(()=>selected=4),icon:Icon(selected==4?Icons.person:Icons.person_outline,color:selected==4?const Color(0xFF9ED2FF):Colors.white)),IconButton(tooltip:'Çıkış',onPressed:()=>db.auth.signOut(),icon:const Icon(Icons.logout))]),
   body:pages[selected],
   bottomNavigationBar:SafeArea(top:false,child:SizedBox(height:76,child:Container(padding:const EdgeInsets.symmetric(vertical:4,horizontal:3),decoration:const BoxDecoration(color:Colors.white,boxShadow:[BoxShadow(color:Color(0x16073565),blurRadius:13,offset:Offset(0,-3))]),child:Row(mainAxisSize:MainAxisSize.max,children:[
    _nav(0,Icons.home_outlined,Icons.home,'Akış'),
    _nav(1,Icons.work_outline,Icons.work,'İş Pazarı'),
    Expanded(child:SizedBox(height:64,child:Center(child:FloatingActionButton.small(heroTag:'main-share',onPressed:createPost,tooltip:'Paylaş',shape:const CircleBorder(),backgroundColor:iaBlue,foregroundColor:Colors.white,child:const Icon(Icons.add,size:30))))),
    _nav(2,Icons.explore_outlined,Icons.explore,'Keşfet'),
    _nav(3,Icons.chat_bubble_outline,Icons.chat_bubble,'Mesajlar'),
   ])))),
  );
 }
 Widget _nav(int i,IconData regular,IconData active,String label)=>Expanded(child:InkWell(onTap:()=>setState(()=>selected=i),child:Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(selected==i?active:regular,size:22,color:selected==i?iaBlue:const Color(0xff5c6877)),const SizedBox(height:4),Text(label,style:TextStyle(fontSize:10,fontWeight:selected==i?FontWeight.bold:FontWeight.w500,color:selected==i?iaBlue:const Color(0xff5c6877)))]))));
}

class LoadList extends StatelessWidget {final Future<List<Map<String,dynamic>>> Function() future;final Widget Function(Map<String,dynamic>) item;final String empty;const LoadList({super.key,required this.future,required this.item,this.empty='Henüz içerik yok.'}); @override Widget build(BuildContext c)=>FutureBuilder<List<Map<String,dynamic>>>(future:future(),builder:(c,s){if(s.hasError)return Center(child:Text('Yükleme hatası: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());if(s.data!.isEmpty)return Center(child:Text(empty));return ListView.builder(padding:const EdgeInsets.all(12),itemCount:s.data!.length,itemBuilder:(c,i)=>item(s.data![i]));});}
Widget panel(Widget child)=>Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:child));
Future<Map<String,dynamic>> profile(String id) async => row(await db.from('profiles').select().eq('id',id).single());
Future<void> editText(BuildContext context,{required String title,required Future<void> Function(String) save,String hint=''})async{
 final ctrl=TextEditingController();final value=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:TextField(controller:ctrl,maxLines:4,maxLength:1000,decoration:InputDecoration(hintText:hint)),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text.trim()),child:const Text('Gönder'))]));ctrl.dispose();if(value!=null&&value.isNotEmpty&&context.mounted){await runSafe(context,()=>save(value));}

}
class PostTile extends StatefulWidget {final Map<String,dynamic> post;final VoidCallback onChange;const PostTile({super.key,required this.post,required this.onChange});@override State<PostTile> createState()=>_PostTileState();}
class _PostTileState extends State<PostTile> {bool? liked;int? count;Future<void> refresh() async{final id=widget.post['id'];final likes=await db.from('likes').select('user_id').eq('post_id',id);if(mounted)setState((){liked=(likes as List).any((x)=>x['user_id']==me);count=likes.length;});}
 @override void initState(){super.initState();runSafe(context,refresh);}
 @override Widget build(BuildContext c){final p=widget.post,author=row(p['profiles']??{});return panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[ListTile(contentPadding:EdgeInsets.zero,leading:ProfileAvatar(path:author['avatar_url'] as String?),title:Text('${author['full_name']??'Kullanıcı'}'),subtitle:Text('${author['profession']??''}'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ProfilePage(userId:p['author_id'])))),Text('${p['body']}',style:const TextStyle(fontSize:16)),if(p['image_url']!=null)Padding(padding:const EdgeInsets.only(top:10),child:Image.network(p['image_url'],height:200,errorBuilder:(_,__,___)=>const Text('Fotoğraf yüklenemedi.'))),if(p['video_url']!=null)CommunityVideo(url:p['video_url']),const SizedBox(height:8),Wrap(spacing:5,children:[TextButton.icon(onPressed:p['author_id']==me?null:()async{await runSafe(c,()async{if(liked==true){await db.from('likes').delete().eq('post_id',p['id']).eq('user_id',me);}else{await db.from('likes').insert({'post_id':p['id'],'user_id':me});}await refresh();});},icon:Icon(liked==true?Icons.favorite:Icons.favorite_border),label:Text('${count??0}')),TextButton.icon(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>CommentsPage(postId:p['id']))),icon:const Icon(Icons.comment_outlined),label:const Text('Yorumlar')),PopupMenuButton<String>(tooltip:'İşlemler',onSelected:(v)async{if(v=='report'){await editText(c,title:'Gönderiyi şikâyet et',save:(reason)async{await db.from('reports').insert({'reporter_id':me,'target_post_id':p['id'],'reason':reason});});}else if(v=='delete'){await runSafe(c,()async{await db.from('posts').delete().eq('id',p['id']);widget.onChange();});}},itemBuilder:(_)=>[if(p['author_id']==me)const PopupMenuItem(value:'delete',child:Text('Sil')),const PopupMenuItem(value:'report',child:Text('Şikâyet et'))])]) ]));}
}
class CommentsPage extends StatefulWidget {final String postId;const CommentsPage({super.key,required this.postId});@override State<CommentsPage>createState()=>_CommentsPageState();}
class _CommentsPageState extends State<CommentsPage>{int tick=0;@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Yorumlar')),body:Column(children:[Expanded(child:LoadList(key:ValueKey(tick),future:()async=>(await db.from('comments').select('id,author_id,body,profiles!comments_author_id_fkey(full_name)').eq('post_id',widget.postId).order('created_at') as List).map(row).toList(),item:(x)=>panel(ListTile(title:Text('${row(x['profiles']??{})['full_name']??'Kullanıcı'}'),subtitle:Text('${x['body']}'))))),Padding(padding:const EdgeInsets.all(12),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>editText(c,title:'Yorum yaz',save:(t)async{await db.from('comments').insert({'post_id':widget.postId,'author_id':me,'body':t});setState(()=>tick++);}),icon:const Icon(Icons.edit),label:const Text('Yorum ekle'))))]));}

class ApplicationsPage extends StatelessWidget {final String jobId;const ApplicationsPage({super.key,required this.jobId});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Başvurular')),body:LoadList(future:()async=>(await db.from('applications').select('id,applicant_id,message,profiles!applications_applicant_id_fkey(full_name,profession)').eq('job_id',jobId) as List).map(row).toList(),item:(x)=>panel(ListTile(title:Text('${row(x['profiles']??{})['full_name']}'),subtitle:Text('${x['message']}'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ProfilePage(userId:x['applicant_id'])))))));}

class DiscoverPage extends StatefulWidget{const DiscoverPage({super.key});@override State<DiscoverPage>createState()=>_DiscoverPageState();}
class _DiscoverPageState extends State<DiscoverPage>{String q='';@override Widget build(BuildContext c)=>Column(children:[Padding(padding:const EdgeInsets.all(12),child:TextField(onChanged:(v)=>setState(()=>q=v.trim()),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'İsim, meslek veya şehir ara'))),Expanded(child:LoadList(key:ValueKey(q),future:()async{final result=await db.from('profiles').select('id,full_name,profession,city,bio,avatar_url').limit(100);return (result as List).map(row).where((p)=>'${p['full_name']} ${p['profession']} ${p['city']}'.toLowerCase().contains(q.toLowerCase())&&p['id']!=me).toList();},item:(p)=>panel(ListTile(leading:ProfileAvatar(path:p['avatar_url'] as String?),title:Text('${p['full_name']}'),subtitle:Text('${p['profession']} · ${p['city']}'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ProfilePage(userId:p['id'])))))))]);}

