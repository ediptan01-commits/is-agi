part of 'main.dart';

Future<bool> confirmRemoval(BuildContext context, String title, String detail) async =>
  await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(title), content: Text(detail), actions: [
    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Onayla')),
  ])) ?? false;

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});
  @override State<JobsPage> createState() => _JobsPageState();
}
class _JobsPageState extends State<JobsPage> {
  final listKey = GlobalKey<CommunityListState>();
  bool deleting = false;
  Future<List<Map<String,dynamic>>> load() async => (await db.from('jobs')
    .select('id,owner_id,title,description,city,status,created_at,profiles!jobs_owner_id_fkey(full_name,avatar_url)')
    .order('created_at', ascending: false).limit(100)).map(row).toList();
  Future<void> edit([Map<String,dynamic>? job]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => JobEditor(
      initial: job, onSave: (values) async {
        if (job == null) {await db.from('jobs').insert({...values,'owner_id':me});}
        else {await db.from('jobs').update(values).eq('id',job['id']).eq('owner_id',me).select('id').single();}
      })));
    if (saved == true && mounted) await listKey.currentState?.refresh();
  }
  Future<void> remove(Map<String,dynamic> job) async {
    if (deleting) return;
    if (!await confirmRemoval(context, 'İlan silinsin mi?', '“${job['title']}” ilanı ve bu ilana yapılan başvurular silinecek.') || !mounted) return;
    setState(() => deleting = true);
    try {
      final result = await db.from('jobs').delete().eq('id',job['id']).eq('owner_id',me).select('id');
      if (result.isEmpty) throw StateError('İlan bulunamadı.');
      if (mounted) {notice(context,'İlan silindi.');await listKey.currentState?.refresh();}
    } catch (_) {if (mounted) notice(context,'İlan silinemedi. Bağlantını kontrol edip tekrar dene.');}
    finally {if (mounted) setState(() => deleting = false);}
  }
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: SizedBox(width:double.infinity, child:
      FilledButton.icon(onPressed: () => edit(), icon:const Icon(Icons.add), label:const Text('İş ilanı oluştur')))),
    if (deleting) const LinearProgressIndicator(),
    Expanded(child: CommunityList(key:listKey,load:load,empty:'Henüz iş ilanı yok.',item:(job) => JobCard(job:job,
      onEdit:job['owner_id']==me && !deleting ? () => edit(job) : null,
      onDelete:job['owner_id']==me && !deleting ? () => remove(job) : null,
      onApplications:job['owner_id']==me ? () => Navigator.push(context,MaterialPageRoute(builder:(_)=>ApplicationsPage(jobId:job['id']))) : null,
      onApply:job['owner_id']!=me && job['status']=='open' ? () => editText(context,title:'İşe başvur',hint:'Kendini tanıt',save:(text) async {
        await db.from('applications').insert({'job_id':job['id'],'applicant_id':me,'message':text});
        if (mounted) notice(context,'Başvurun gönderildi.');
      }) : null))),
  ]);
}

class JobCard extends StatelessWidget {
  final Map<String,dynamic> job;
  final VoidCallback? onEdit,onDelete,onApplications,onApply;
  const JobCard({super.key,required this.job,this.onEdit,this.onDelete,this.onApplications,this.onApply});
  @override Widget build(BuildContext context) => panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('${job['title']}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:iaNavy)),
    const SizedBox(height:6),Text('${job['city'] ?? ''} · ${row(job['profiles'] ?? {})['full_name'] ?? 'Kullanıcı'}'),
    Chip(label:Text(job['status']=='open'?'Başvuruya açık':'Başvuruya kapalı')),
    Text('${job['description']}'),const SizedBox(height:10),
    Wrap(spacing:8,runSpacing:4,children:[
      if(onApply!=null)FilledButton.tonal(onPressed:onApply,child:const Text('Başvur')),
      if(onApplications!=null)TextButton(onPressed:onApplications,child:const Text('Başvuruları gör')),
      if(onEdit!=null)TextButton.icon(onPressed:onEdit,icon:const Icon(Icons.edit_outlined),label:const Text('Düzenle')),
      if(onDelete!=null)TextButton.icon(onPressed:onDelete,icon:const Icon(Icons.delete_outline),label:const Text('Sil')),
    ]),
  ]));
}

class JobEditor extends StatefulWidget {
  final Map<String,dynamic>? initial;
  final Future<void> Function(Map<String,dynamic>) onSave;
  const JobEditor({super.key,this.initial,required this.onSave});
  @override State<JobEditor> createState() => _JobEditorState();
}
class _JobEditorState extends State<JobEditor> {
  final form=GlobalKey<FormState>();
  late final TextEditingController title,description,city;
  late String status;
  bool busy=false;
  String? error;
  @override void initState(){super.initState();final p=widget.initial ?? {};title=TextEditingController(text:p['title']);description=TextEditingController(text:p['description']);city=TextEditingController(text:p['city']);status=p['status']=='closed'?'closed':'open';}
  @override void dispose(){title.dispose();description.dispose();city.dispose();super.dispose();}
  Future<void> save()async{
    if(busy||!form.currentState!.validate())return;
    setState((){busy=true;error=null;});
    try{await widget.onSave({'title':title.text.trim(),'description':description.text.trim(),'city':city.text.trim(),'status':status});if(mounted)Navigator.pop(context,true);}
    catch(_){if(mounted)setState(()=>error='İlan kaydedilemedi. Bağlantını kontrol edip tekrar dene.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>PopScope(canPop:!busy,child:Scaffold(appBar:AppBar(title:Text(widget.initial==null?'İş ilanı oluştur':'İlanı düzenle')),body:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
    TextFormField(controller:title,enabled:!busy,maxLength:160,decoration:const InputDecoration(labelText:'İş başlığı'),validator:(v)=>(v?.trim().length ?? 0)<3?'Başlık en az 3 karakter olmalı.':null),
    const SizedBox(height:12),TextFormField(controller:description,enabled:!busy,maxLines:6,maxLength:4000,decoration:const InputDecoration(labelText:'Açıklama'),validator:(v)=>(v?.trim().length ?? 0)<3?'Açıklama en az 3 karakter olmalı.':null),
    const SizedBox(height:12),TextFormField(controller:city,enabled:!busy,maxLength:120,decoration:const InputDecoration(labelText:'Şehir')),
    const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:status,decoration:const InputDecoration(labelText:'İlan durumu'),items:const[DropdownMenuItem(value:'open',child:Text('Başvuruya açık')),DropdownMenuItem(value:'closed',child:Text('Başvuruya kapalı'))],onChanged:busy?null:(value)=>setState(()=>status=value!)),
    const SizedBox(height:20),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
    FilledButton(onPressed:busy?null:save,child:Padding(padding:const EdgeInsets.all(12),child:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):Text(widget.initial==null?'Yayınla':'Değişiklikleri kaydet'))),
  ]))));
}

const emptyProfileValues=<String,dynamic>{'full_name':'','profession':'','skills':<String>[],'city':'','bio':'','available':false,'avatar_url':null};

class ProfileEditor extends StatefulWidget {
  final Map<String,dynamic> initial;
  final Future<void> Function(Map<String,dynamic>) onSave;
  const ProfileEditor({super.key,required this.initial,required this.onSave});
  @override State<ProfileEditor> createState()=>_ProfileEditorState();
}
class _ProfileEditorState extends State<ProfileEditor>{
  late final TextEditingController name,city,bio,skills;
  late String profession;
  late bool available;
  bool busy=false;
  String? error;
  @override void initState(){super.initState();final p=widget.initial;name=TextEditingController(text:p['full_name']);city=TextEditingController(text:p['city']);bio=TextEditingController(text:p['bio']);skills=TextEditingController(text:(p['skills'] as List? ?? []).join(', '));profession=professions.contains(p['profession'])?p['profession']:'';available=p['available']==true;}
  @override void dispose(){name.dispose();city.dispose();bio.dispose();skills.dispose();super.dispose();}
  Future<void> save()async{
    if(busy)return;setState((){busy=true;error=null;});
    try{await widget.onSave({'full_name':name.text.trim(),'profession':profession,'city':city.text.trim(),'bio':bio.text.trim(),'skills':skills.text.split(',').map((x)=>x.trim()).where((x)=>x.isNotEmpty).toSet().toList(),'available':available});if(mounted)Navigator.pop(context,true);}
    catch(_){if(mounted)setState(()=>error='Profil kaydedilemedi. Bağlantını kontrol edip tekrar dene.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>PopScope(canPop:!busy,child:Scaffold(appBar:AppBar(title:const Text('Profili düzenle')),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Bir bilgiyi kaldırmak için alanı boş bırakıp kaydet.'),const SizedBox(height:16),
    TextField(controller:name,enabled:!busy,maxLength:100,decoration:const InputDecoration(labelText:'Ad soyad')),const SizedBox(height:12),
    DropdownButtonFormField<String>(initialValue:profession,decoration:const InputDecoration(labelText:'Meslek'),items:[const DropdownMenuItem(value:'',child:Text('Belirtilmedi')),...professions.map((p)=>DropdownMenuItem(value:p,child:Text(p)))],onChanged:busy?null:(value)=>setState(()=>profession=value!)),const SizedBox(height:12),
    TextField(controller:city,enabled:!busy,maxLength:120,decoration:const InputDecoration(labelText:'Şehir')),const SizedBox(height:12),
    TextField(controller:skills,enabled:!busy,maxLength:500,decoration:const InputDecoration(labelText:'Yetenekler (virgülle ayır)')),const SizedBox(height:12),
    TextField(controller:bio,enabled:!busy,maxLines:5,maxLength:1000,decoration:const InputDecoration(labelText:'Hakkımda')),
    SwitchListTile(title:const Text('İşe müsaitim'),value:available,onChanged:busy?null:(value)=>setState(()=>available=value)),
    if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
    FilledButton(onPressed:busy?null:save,child:Padding(padding:const EdgeInsets.all(12),child:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):const Text('Profili kaydet'))),
  ])));
}

class ProfileAvatar extends StatefulWidget{
  final String? path;
  final double radius;
  const ProfileAvatar({super.key,this.path,this.radius=24});
  @override State<ProfileAvatar> createState()=>_ProfileAvatarState();
}
class _ProfileAvatarState extends State<ProfileAvatar>{
  late Future<String?> source;
  Future<String?> resolve()async{
    final path=widget.path;
    if(path==null||path.isEmpty)return null;
    if(Uri.tryParse(path)?.hasScheme==true)return null;
    return db.storage.from('profile-avatars').createSignedUrl(path,1800);
  }
  @override void initState(){super.initState();source=resolve();}
  @override void didUpdateWidget(covariant ProfileAvatar old){super.didUpdateWidget(old);if(old.path!=widget.path)source=resolve();}
  @override Widget build(BuildContext context)=>FutureBuilder<String?>(future:source,builder:(context,snapshot)=>CircleAvatar(radius:widget.radius,backgroundColor:const Color(0xFFDCEBFC),child:snapshot.data==null?
    Icon(Icons.person,size:widget.radius,color:iaNavy):ClipOval(child:Image.network(snapshot.data!,width:widget.radius*2,height:widget.radius*2,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Icon(Icons.person,size:widget.radius,color:iaNavy)))));
}

class ProfilePage extends StatefulWidget{
  final String userId;
  const ProfilePage({super.key,required this.userId});
  @override State<ProfilePage> createState()=>_ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage>{
  late Future<Map<String,dynamic>> data;
  bool busy=false;
  int revision=0;
  @override void initState(){super.initState();data=profile(widget.userId);}
  void refresh(){if(mounted)setState((){data=profile(widget.userId);revision++;});}
  Future<void> update(Map<String,dynamic> values)async{await db.from('profiles').update(values).eq('id',widget.userId).select('id').single();}
  Future<void> edit(Map<String,dynamic> p)async{
    final changed=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>ProfileEditor(initial:p,onSave:update)));
    if(changed==true&&mounted)refresh();
  }
  Future<void> cleanFile(String? path)async{
    if(path==null||!path.startsWith('${widget.userId}/'))return;
    try{await db.storage.from('profile-avatars').remove([path]);}catch(_){/* The old photo no longer has a profile reference. */}
  }
  Future<void> photo(Map<String,dynamic> p)async{
    if(busy)return;setState(()=>busy=true);
    String? uploaded;
    try{
      final file=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1024,maxHeight:1024,imageQuality:85,requestFullMetadata:false);
      if(file==null)return;
      final selected=await readPickedMedia(file,video:false);
      uploaded='${widget.userId}/${DateTime.now().microsecondsSinceEpoch}.${selected.extension}';
      await db.storage.from('profile-avatars').uploadBinary(uploaded,selected.bytes,fileOptions:FileOptions(contentType:selected.contentType));
      await update({'avatar_url':uploaded});
      await cleanFile(p['avatar_url'] as String?);
      if(mounted){refresh();notice(context,'Profil fotoğrafı kaydedildi.');}
    }catch(_){if(mounted)notice(context,'Fotoğraf kaydedilemedi. JPG, PNG veya WebP ve en fazla 5 MB bir fotoğraf seç.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> clear(Map<String,dynamic> p,{bool onlyPhoto=false})async{
    if(busy)return;
    if(!await confirmRemoval(context,onlyPhoto?'Profil fotoğrafı kaldırılsın mı?':'Profil bilgileri temizlensin mi?',onlyPhoto?'Mevcut profil fotoğrafı kaldırılacak.':'Ad, meslek, şehir, yetenekler, hakkımda bilgisi ve profil fotoğrafı temizlenecek.')||!mounted)return;
    setState(()=>busy=true);
    try{await update(onlyPhoto?{'avatar_url':null}:emptyProfileValues);await cleanFile(p['avatar_url'] as String?);if(mounted){refresh();notice(context,onlyPhoto?'Profil fotoğrafı kaldırıldı.':'Profil bilgileri temizlendi.');}}
    catch(_){if(mounted)notice(context,'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> otherAction(String value)async{
    if(value=='report'){await editText(context,title:'Kullanıcıyı şikâyet et',save:(reason)async{await db.from('reports').insert({'reporter_id':me,'target_user_id':widget.userId,'reason':reason});});}
    else{await runSafe(context,()async{final existing=await db.from('blocks').select('blocked_id').eq('blocker_id',me).eq('blocked_id',widget.userId);if(existing.isEmpty){await db.from('blocks').insert({'blocker_id':me,'blocked_id':widget.userId});}else{await db.from('blocks').delete().eq('blocker_id',me).eq('blocked_id',widget.userId);}if(mounted)Navigator.pop(context);});}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:Navigator.canPop(context)?AppBar(title:const Text('Profil')):null,body:FutureBuilder<Map<String,dynamic>>(future:data,builder:(context,snapshot){
    if(snapshot.hasError)return Center(child:TextButton(onPressed:refresh,child:const Text('Profil yüklenemedi. Tekrar dene.')));
    if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
    final p=snapshot.data!;
    return RefreshIndicator(onRefresh:()async{refresh();await data;},child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(12,12,12,24),children:[
      profileCover(p),const SizedBox(height:12),
      if(widget.userId==me)panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Profilimi yönet',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17,color:iaNavy)),const SizedBox(height:10),
        if(busy)const LinearProgressIndicator(),
        Wrap(spacing:8,runSpacing:4,children:[
          FilledButton.icon(onPressed:busy?null:()=>edit(p),icon:const Icon(Icons.edit_outlined),label:const Text('Profili düzenle')),
          OutlinedButton.icon(onPressed:busy?null:()=>photo(p),icon:const Icon(Icons.add_a_photo_outlined),label:Text(p['avatar_url']==null?'Fotoğraf ekle':'Fotoğrafı değiştir')),
          if(p['avatar_url']!=null)TextButton(onPressed:busy?null:()=>clear(p,onlyPhoto:true),child:const Text('Fotoğrafı kaldır')),
          TextButton(onPressed:busy?null:()=>clear(p),child:const Text('Profil bilgilerini temizle')),
        ]),
      ])),
      profileDetails(p,widget.userId),const SizedBox(height:12),
      panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Mesleki bağlantılar',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17,color:iaNavy)),ProfileSocialStats(userId:widget.userId),
        if(widget.userId!=me)Wrap(spacing:8,children:[FollowButton(userId:widget.userId),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatPage(otherId:widget.userId,name:'${p['full_name']}'))),child:const Text('Mesaj')),
          PopupMenuButton<String>(onSelected:otherAction,itemBuilder:(_)=>const[PopupMenuItem(value:'block',child:Text('Engelle / engeli kaldır')),PopupMenuItem(value:'report',child:Text('Şikâyet et'))])]),
      ])),const SizedBox(height:12),const Text('Paylaşımlar',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:8),
      FutureBuilder<List<dynamic>>(key:ValueKey(revision),future:db.from('posts').select('id,author_id,body,image_url,video_url,created_at').eq('author_id',widget.userId).order('created_at',ascending:false),builder:(context,snapshot){
        if(snapshot.hasError)return const Text('Paylaşımlar yüklenemedi.');
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        return Column(children:snapshot.data!.map((post)=>PostTile(key:ValueKey(post['id']),post:{...row(post),'profiles':p},onChange:refresh)).toList());
      }),
    ]));
  }));
}
