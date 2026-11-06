part of 'main.dart';

const iaNavy = Color(0xFF073765);
const iaBlue = Color(0xFF0875DA);
const iaGreen = Color(0xFF17A767);

Widget profileCover(Map<String,dynamic> p) => Card(
 clipBehavior: Clip.antiAlias,
 margin: EdgeInsets.zero,
 child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Container(height:108,decoration:const BoxDecoration(gradient:LinearGradient(
   colors:[iaNavy,Color(0xFF3B85C9)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
   alignment:Alignment.centerRight,
   child:const Padding(padding:EdgeInsets.all(20),child:Icon(Icons.business_center_outlined,
    color:Color(0x66FFFFFF),size:74))),
  Padding(padding:const EdgeInsets.fromLTRB(16,0,16,18),child:Column(
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    Transform.translate(offset:const Offset(0,-24),child:Row(children:[
     Container(padding:const EdgeInsets.all(4),decoration:const BoxDecoration(
      color:Colors.white,shape:BoxShape.circle),
      child:ProfileAvatar(path:p['avatar_url'] as String?,radius:37)),
     const Spacer(),
     if(p['available']==true)const Chip(label:Text('İşe müsait'),
      avatar:Icon(Icons.circle,color:iaGreen,size:13)),
    ])),
    Text((p['full_name']?.toString().trim().isNotEmpty??false)?p['full_name'].toString():'Kullanıcı',style:const TextStyle(
     fontWeight:FontWeight.w900,fontSize:27,color:iaNavy)),
    const SizedBox(height:4),
    Text('${p['profession']??''} · ${p['city']??''}',style:const TextStyle(fontSize:15,
     color:Color(0xFF536278))),
   ])),
 ]),
);

Widget profileDetails(Map<String,dynamic> p,String id)=> Card(
 margin:EdgeInsets.zero,
 child:Padding(padding:const EdgeInsets.all(17),child:Column(
  crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Row(children:[Icon(Icons.workspace_premium_outlined,color:iaNavy),
   SizedBox(width:9),Text('Mesleki Bilgiler',style:TextStyle(
    fontWeight:FontWeight.w800,fontSize:18,color:iaNavy))]),
  const Divider(height:23),
  _profileDetail(Icons.handyman_outlined,'Uzmanlık',p['profession']?.toString()??''),
  _profileDetail(Icons.location_on_outlined,'Çalışma bölgesi',p['city']?.toString()??''),
  if(p['available']==true)_profileDetail(Icons.check_circle_outline,'Durum','Yeni iş alabilir'),
  if((p['bio']?.toString()??'').isNotEmpty)...[
   const SizedBox(height:12),
   const Text('Hakkımda',style:TextStyle(fontWeight:FontWeight.bold)),
   Text(p['bio'].toString()),
  ],
  const SizedBox(height:12),
  const Text('Yetenekler',style:TextStyle(fontWeight:FontWeight.bold)),
  const SizedBox(height:7),
  Wrap(spacing:6,runSpacing:4,children:(p['skills'] as List? ?? [])
    .map((x)=>Chip(label:Text(x.toString()))).toList()),
 ])),
);
Widget _profileDetail(IconData icon,String label,String value)=>Padding(
 padding:const EdgeInsets.symmetric(vertical:6),
 child:Row(children:[Icon(icon,size:19,color:iaNavy),const SizedBox(width:9),
  Expanded(child:Text(label,style:const TextStyle(color:Color(0xFF59677A)))),
  Flexible(child:Text(value,textAlign:TextAlign.right,
   style:const TextStyle(fontWeight:FontWeight.w700))),
 ]),
);
