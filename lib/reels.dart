part of 'main.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});
  @override State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  late Future<List<Map<String, dynamic>>> videos;
  @override void initState() { super.initState(); videos = load(); }
  Future<List<Map<String, dynamic>>> load() async {
    final result = await db.from('posts').select(
      'id,author_id,body,video_url,created_at,profiles!posts_author_id_fkey(full_name,profession,avatar_url)'
    ).not('video_url', 'is', null).order('created_at', ascending:false).limit(80);
    return result.map(row).where((p) => (p['video_url']??'').toString().isNotEmpty).toList();
  }
  void reload() { if(mounted) setState(() => videos = load()); }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String,dynamic>>>(
    future: videos, builder: (context,snapshot) {
      if(snapshot.hasError) return Center(child: TextButton.icon(onPressed:reload,
        icon:const Icon(Icons.refresh), label:const Text('Reels yüklenemedi. Tekrar dene')));
      if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
      final items=snapshot.data!;
      if(items.isEmpty) return const Center(child:Padding(padding:EdgeInsets.all(28),
        child:Text('Henüz Reels yok. + düğmesinden video paylaşabilirsin.',textAlign:TextAlign.center)));
      return PageView.builder(scrollDirection:Axis.vertical, itemCount:items.length,
        itemBuilder:(context,index) => ReelsTile(key:ValueKey(items[index]['id']),
          post:items[index],onChanged:reload));
    });
}

class ReelsTile extends StatefulWidget {
  final Map<String,dynamic> post;
  final VoidCallback onChanged;
  const ReelsTile({super.key,required this.post,required this.onChanged});
  @override State<ReelsTile> createState() => _ReelsTileState();
}

class _ReelsTileState extends State<ReelsTile> {
  int count=0;
  bool liked=false;
  @override void initState(){super.initState(); refreshLikes();}
  Future<void> refreshLikes() async {
    try {
      final rows=await db.from('likes').select('user_id').eq('post_id',widget.post['id']);
      if(mounted)setState(() {
        count=rows.length;
        liked=rows.any((x)=>x['user_id']==me);
      });
    }catch(e){if(mounted)notice(context,e);}
  }
  Future<void> toggleLike() async {
    if(widget.post['author_id']==me)return;
    await runSafe(context,()async{
      if(liked){
        await db.from('likes').delete().eq('post_id',widget.post['id']).eq('user_id',me);
      }else{
        await db.from('likes').insert({'post_id':widget.post['id'],'user_id':me});
      }
      await refreshLikes();
    });
  }
  Future<void> action(String choice) async {
    if(choice=='report'){
      await editText(context,title:'Videoyu şikâyet et',save:(reason)async{
        await db.from('reports').insert({'reporter_id':me,
          'target_post_id':widget.post['id'],'reason':reason});
      });
    }else if(choice=='delete'){
      await runSafe(context,()async {
        await db.from('posts').delete().eq('id',widget.post['id']).eq('author_id',me);
        widget.onChanged();
      });
    }
  }
  @override Widget build(BuildContext context) {
    final post=widget.post, author=row(post['profiles']??{});
    return Padding(padding:const EdgeInsets.symmetric(horizontal:4,vertical:2),
      child:ClipRRect(borderRadius:BorderRadius.circular(12),
        child:Stack(fit:StackFit.expand,children:[
          CommunityVideo(url:post['video_url'].toString(),expandToFill:true),
          const IgnorePointer(child:DecoratedBox(decoration:BoxDecoration(
            gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
              colors:[Color(0x44000000),Colors.transparent,Color(0xDD000000)],
              stops:[0,0.58,1])))),
          Positioned(top:8,right:8,child:PopupMenuButton<String>(
            tooltip:'Video işlemleri',
            icon:const Icon(Icons.more_vert,color:Colors.white),
            onSelected:action,
            itemBuilder:(_)=>[
              if(post['author_id']==me)
                const PopupMenuItem(value:'delete',child:Text('Videoyu sil')),
              const PopupMenuItem(value:'report',child:Text('Şikâyet et')),
            ])),
          Positioned(left:12,right:70,bottom:18,child:Column(
            mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Row(children:[
                InkWell(
                  onTap:()=>Navigator.push(context,MaterialPageRoute(
                    builder:(_)=>ProfilePage(userId:post['author_id']))),
                  child:ProfileAvatar(path:author['avatar_url'] as String?)),
                const SizedBox(width:7),
                Expanded(child:Text('${author['full_name']??'Kullanıcı'}',
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w800))),
                if(post['author_id']!=me)
                  FollowButton(userId:post['author_id'].toString(),compact:true),
              ]),
              if((post['body']??'').toString().trim().isNotEmpty)...[
                const SizedBox(height:8),
                Text(post['body'].toString(),maxLines:3,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white)),
              ],
            ])),
          Positioned(right:5,bottom:16,child:Column(
            mainAxisSize:MainAxisSize.min,children:[
              IconButton(tooltip:'Beğen',onPressed:post['author_id']==me?null:toggleLike,
                icon:Icon(liked?Icons.favorite:Icons.favorite_border,
                  color:liked?Colors.redAccent:Colors.white,size:30)),
              Text('$count',style:const TextStyle(color:Colors.white)),
              const SizedBox(height:8),
              IconButton(tooltip:'Yorumlar',
                onPressed:()=>Navigator.push(context,MaterialPageRoute(
                  builder:(_)=>CommentsPage(postId:post['id']))),
                icon:const Icon(Icons.mode_comment_outlined,color:Colors.white,size:29)),
              const SizedBox(height:12),
              const Icon(Icons.share_outlined,color:Color(0xFFCBD1DD),size:27),
              const SizedBox(height:18),
              const Icon(Icons.bookmark_border,color:Color(0xFFCBD1DD),size:27),
            ])),
        ]))));
  }
}
