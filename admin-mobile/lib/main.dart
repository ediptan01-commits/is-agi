import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

typedef Row = Map<String, dynamic>;
const navy = Color(0xff152b45);
const blue = Color(0xff245de9);
const sectionNames = <String, String>{
  'overview': 'Genel bakış', 'users': 'Kullanıcılar', 'posts': 'Gönderiler',
  'comments': 'Yorumlar', 'jobs': 'İş ilanları', 'stories': 'Hikâyeler',
  'reports': 'Şikâyetler', 'announce': 'Duyuru yayınla', 'audit': 'İşlem geçmişi',
};

abstract class AdminApi {
  Future<void> login(String email, String password);
  Future<void> logout();
  Future<Row> overview();
  Future<Row> list(String section, String search, int offset);
  Future<void> suspend(String id, bool suspended, String reason);
  Future<void> moderate(String kind, String id, bool hidden, String reason);
  Future<void> review(String id, String status, String note);
  Future<int> announce(String body, String request);
}

class SupabaseAdminApi implements AdminApi {
  final SupabaseClient client;
  SupabaseAdminApi(this.client);
  @override Future<void> login(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
    try { await overview(); } catch (_) {
      await client.auth.signOut(scope: SignOutScope.local);
      rethrow;
    }
  }
  @override Future<void> logout() => client.auth.signOut(scope: SignOutScope.local);
  @override Future<Row> overview() async => Map<String,dynamic>.from(await client.rpc('admin_overview'));
  @override Future<Row> list(String section, String search, int offset) async => Map<String,dynamic>.from(
    await client.rpc('admin_list', params: {'p_section': section, 'p_search': search, 'p_offset': offset}));
  @override Future<void> suspend(String id, bool suspended, String reason) async {
    await client.rpc('admin_suspend', params: {'p_user': id, 'p_suspended': suspended, 'p_reason': reason});
  }
  @override Future<void> moderate(String kind, String id, bool hidden, String reason) async {
    await client.rpc('admin_moderate', params: {'p_kind': kind, 'p_id': id, 'p_hidden': hidden, 'p_reason': reason});
  }
  @override Future<void> review(String id, String status, String note) async {
    await client.rpc('admin_review_report', params: {'p_id': id, 'p_status': status, 'p_note': note});
  }
  @override Future<int> announce(String body, String request) async => (await client.rpc('admin_announce', params: {'p_body': body, 'p_request': request}) as num).toInt();
}

String friendlyError(Object error) {
  if (error is AuthException) return 'E-posta veya şifre doğrulanamadı. İş Ağı hesap bilgilerini kontrol et.';
  if (error is PostgrestException) {
    if (error.code == '42501') return 'Bu hesap yönetici yetkisine sahip değil veya oturumun sona erdi.';
    return error.message;
  }
  return 'İşlem tamamlanamadı. İnternet bağlantını kontrol edip tekrar dene.';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || key.isEmpty) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Yönetim bağlantısı yapılandırılmadı.')))));
    return;
  }
  await Supabase.initialize(url: url, anonKey: key,
    authOptions: const FlutterAuthClientOptions(localStorage: EmptyLocalStorage()));
  runApp(AdminApp(api: SupabaseAdminApi(Supabase.instance.client)));
}

class AdminApp extends StatelessWidget {
  final AdminApi api;
  const AdminApp({super.key, required this.api});
  @override Widget build(BuildContext context) => MaterialApp(title: 'İş Ağı Yönetim', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: blue),
      scaffoldBackgroundColor: const Color(0xfff4f6f9), appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())), home: AdminLogin(api: api));
}

class AdminLogin extends StatefulWidget {
  final AdminApi api;
  const AdminLogin({super.key, required this.api});
  @override State<AdminLogin> createState() => _AdminLoginState();
}
class _AdminLoginState extends State<AdminLogin> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {busy = true; error = null;});
    try {
      await widget.api.login(email.text.trim(), password.text);
      password.clear();
      if (mounted) await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminHome(api: widget.api)));
    } catch (e) { if (mounted) setState(() => error = friendlyError(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() {email.dispose();password.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(key: form,
      child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 72, color: blue), const SizedBox(height: 20),
        const Text('İş Ağı Yönetim', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 10), const Text('Topluluğun için tek kontrol merkezi.', textAlign: TextAlign.center), const SizedBox(height: 32),
        TextFormField(controller: email, enabled: !busy, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(labelText: 'E-posta'), validator: (value) => value?.contains('@') == true ? null : 'Geçerli e-posta adresini yaz.'),
        const SizedBox(height: 16), TextFormField(controller: password, enabled: !busy, obscureText: obscure, autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: 'İş Ağı hesap şifren', suffixIcon: IconButton(tooltip: 'Şifreyi göster / gizle',
            onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
          validator: (value) => value?.isNotEmpty == true ? null : 'Şifreni yaz.'),
        const SizedBox(height: 20), if (error != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(error!, style: const TextStyle(color: Colors.red))),
        FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.all(13), child: busy ?
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Giriş yap'))),
        const SizedBox(height: 18), const Text('İş Ağı uygulamasındaki hesabınla giriş yap. Veritabanı şifreni kullanma.\nYalnızca yönetici yetkili hesaplar erişebilir.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ]))))))));
}

class AdminHome extends StatefulWidget {
  final AdminApi api;
  const AdminHome({super.key, required this.api});
  @override State<AdminHome> createState() => _AdminHomeState();
}
class _AdminHomeState extends State<AdminHome> {
  String section = 'overview', search = '';
  final searchText = TextEditingController(), announcement = TextEditingController();
  Row? summary;
  List<Row> rows = [];
  int offset = 0, total = 0, generation = 0;
  bool loading = true, acting = false;
  String? error, announcementRequest;
  @override void initState() {super.initState();load();}
  @override void dispose() {searchText.dispose();announcement.dispose();super.dispose();}
  Future<void> load() async {
    final stamp = ++generation;
    setState(() {loading = true;error = null;});
    try {
      if (section == 'overview') {
        final result = await widget.api.overview();
        if (mounted && stamp == generation) setState(() => summary = result);
      } else if (section != 'announce') {
        final result = await widget.api.list(section, search, offset);
        if (mounted && stamp == generation) setState(() {
          rows = (result['rows'] as List).map((x) => Map<String,dynamic>.from(x as Map)).toList(); total = (result['total'] as num).toInt();
        });
      }
    } catch (e) {if (mounted && stamp == generation) setState(() => error = friendlyError(e));}
    finally {if (mounted && stamp == generation) setState(() => loading = false);}
  }
  void navigate(String next, {String query = ''}) {
    setState(() {section = next;search = query;searchText.text = query;offset = 0;rows = [];summary = null;});
    load();
  }
  void inform(String message) {if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));}
  Future<void> reasonAction(String title, Future<void> Function(String) action, {String? detail}) async {
    if (acting) return;
    final reason = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ActionReason(title: title, detail: detail)));
    if (reason == null || !mounted) return;
    setState(() => acting = true);
    try {await action(reason);if (mounted) {inform('İşlem tamamlandı ve geçmişe kaydedildi.');await load();}}
    catch (e) {inform(friendlyError(e));}
    finally {if (mounted) setState(() => acting = false);}
  }
  Future<void> sendAnnouncement() async {
    final body = announcement.text.trim();
    if (body.length < 3) {inform('Duyuru en az 3 karakter olmalı.');return;}
    if (acting) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Duyuruyu yayınla?'),
      content: SingleChildScrollView(child: Text('Aktif kullanıcıların uygulama içi bildirimlerine gönderilecek:\n\n$body')),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yayınla'))]));
    if (confirmed != true || !mounted) return;
    announcementRequest ??= const Uuid().v4();
    setState(() => acting = true);
    try {
      final count = await widget.api.announce(body, announcementRequest!);
      if (mounted) {announcement.clear();announcementRequest = null;inform('Duyuru $count aktif hesaba iletildi.');}
    } catch (e) {inform(friendlyError(e));}
    finally {if (mounted) setState(() => acting = false);}
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(sectionNames[section]!), actions: [
    IconButton(tooltip: 'Yenile', onPressed: loading || acting ? null : load, icon: const Icon(Icons.refresh)),
    IconButton(tooltip: 'Çıkış yap', onPressed: acting ? null : () async {
      try {await widget.api.logout();} catch (e) {inform(friendlyError(e));return;}
      if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => AdminLogin(api: widget.api)), (_) => false);
    }, icon: const Icon(Icons.logout)),
  ]), drawer: Drawer(child: SafeArea(child: Column(children: [
    const ListTile(leading: Icon(Icons.admin_panel_settings_outlined, color: blue), title: Text('İş Ağı Yönetim', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Yönetici hesabı')),
    const Divider(), Expanded(child: ListView(children: sectionNames.entries.map((entry) => ListTile(selected: section == entry.key,
      title: Text(entry.value), onTap: acting ? null : () {Navigator.pop(context);navigate(entry.key);})).toList())),
    const Padding(padding: EdgeInsets.all(16), child: Text('Özel mesaj içerikleri bu uygulamada gösterilmez.', style: TextStyle(fontSize: 11, color: Colors.blueGrey))),
  ]))), body: SafeArea(child: Column(children: [
    if (acting) const LinearProgressIndicator(),
    if (section != 'overview' && section != 'announce' && section != 'audit') Padding(padding: const EdgeInsets.all(12), child: TextField(
      controller: searchText, enabled: !acting, textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: 'Ad, içerik veya kayıt numarası ara',
      suffixIcon: IconButton(tooltip: 'Ara', onPressed: () {search = searchText.text.trim();offset = 0;load();}, icon: const Icon(Icons.search))),
      onSubmitted: (value) {search = value.trim();offset = 0;load();})),
    if (error != null) MaterialBanner(content: Text(error!), actions: [TextButton(onPressed: load, child: const Text('Tekrar dene'))]),
    Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : section == 'announce' ? announcementView() :
      RefreshIndicator(onRefresh: load, child: section == 'overview' ? overviewView() : recordList())),
    if (!loading && section != 'overview' && section != 'announce') Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(tooltip: 'Önceki sayfa', onPressed: offset > 0 && !acting ? () {offset -= 30;load();} : null, icon: const Icon(Icons.chevron_left)),
      Text('${total == 0 ? 0 : offset+1}–${(offset+30).clamp(0,total)} / $total', style: const TextStyle(fontSize: 12)),
      IconButton(tooltip: 'Sonraki sayfa', onPressed: offset+30 < total && !acting ? () {offset += 30;load();} : null, icon: const Icon(Icons.chevron_right)),
    ])),
  ])));
  Widget overviewView() => ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
    const Text('Topluluğun bir bakışta.', style: TextStyle(fontSize: 24, color: navy, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),const Text('Menüden kullanıcıları, içerikleri ve şikâyetleri yönet.'),const SizedBox(height: 20),
    ...{'users':'Kullanıcılar','posts':'Görünür gönderiler','reports':'Açık şikâyetler','jobs':'İş ilanları','stories':'Aktif hikâyeler','suspended':'Askıdaki hesaplar'}.entries.map((entry) => Card(
      child: ListTile(title: Text(entry.value), trailing: Text('${summary?[entry.key] ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: blue)),
        onTap: () => navigate(entry.key == 'suspended' ? 'users' : entry.key)))),
  ]);
  Widget announcementView() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Topluluğuna seslen', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: navy)),
    const SizedBox(height: 12),const Text('Duyurun aktif kullanıcıların uygulama içindeki Bildirimler bölümünde görünür.'),const SizedBox(height: 20),
    TextField(controller: announcement, enabled: !acting, maxLines: 8, maxLength: 2000, onChanged: (_) => announcementRequest = null,
      decoration: const InputDecoration(hintText: 'Duyuru metni')),
    FilledButton.icon(onPressed: acting ? null : sendAnnouncement, icon: const Icon(Icons.campaign_outlined), label: const Text('Gözden geçir ve yayınla')),
  ]);
  Widget recordList() {
    if (rows.isEmpty) return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [Padding(padding: EdgeInsets.all(40), child: Text('Burada henüz kayıt yok.', textAlign: TextAlign.center))]);
    return ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (_, index) => recordCard(rows[index]));
  }
  Widget recordCard(Row record) {
    final id = '${record['id']}';
    if (section == 'users') return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${record['full_name'] ?? 'Kullanıcı'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      Text('${record['email']}'),Text('${record['profession'] ?? ''} · ${record['city'] ?? ''}'),
      Chip(label: Text(record['is_admin'] == true ? 'Yönetici' : record['suspended'] == true ? 'Askıda' : 'Aktif')),
      if ('${record['reason'] ?? ''}'.isNotEmpty) Text('${record['reason']}'),
      if (record['is_admin'] != true) OutlinedButton(onPressed: acting ? null : () => reasonAction(record['suspended'] == true ? 'Hesabı yeniden aç' : 'Hesabı askıya al',
        (reason) => widget.api.suspend(id, record['suspended'] != true, reason), detail: '${record['email']}'), child: Text(record['suspended'] == true ? 'Hesabı aç' : 'Askıya al')),
    ])));
    if (section == 'reports') return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Chip(label: Text(reportStatus('${record['status']}'))),Text('${record['reason']}', style: const TextStyle(fontSize: 16)),
      Text('Gönderen: ${record['reporter_name'] ?? 'Kullanıcı'}'),
      if (record['target_post_id'] != null) TextButton(onPressed: () => navigate('posts', query: record['target_post_id']), child: const Text('Gönderiyi incele')),
      if (record['target_user_id'] != null) TextButton(onPressed: () => navigate('users', query: record['target_user_id']), child: const Text('Kullanıcıyı incele')),
      if ('${record['admin_note'] ?? ''}'.isNotEmpty) Text('Yönetici notu: ${record['admin_note']}'),
      Wrap(spacing: 8, children: {'resolved':'Çözüldü','dismissed':'İşlem gerekmiyor','open':'Yeniden aç'}.entries.where((x) => x.key != record['status']).map((entry) => OutlinedButton(
        onPressed: acting ? null : () => reasonAction(entry.value, (note) => widget.api.review(id, entry.key, note), detail: '${record['reason']}'), child: Text(entry.value))).toList()),
    ])));
    if (section == 'audit') return Card(child: ListTile(title: Text('${record['action']}'), subtitle: Text('${record['note'] ?? ''}\n${displayDate(record['created_at'])}')));
    final hidden = record['moderated_at'] != null;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (record['title'] != null) Text('${record['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text('${record['body'] ?? record['caption'] ?? record['description'] ?? 'Medyalı içerik'}'),
      const SizedBox(height: 10),Text('${record['full_name'] ?? 'Kullanıcı'} · ${displayDate(record['created_at'])}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      Chip(label: Text(hidden ? 'Gizli' : section == 'stories' && DateTime.parse(record['expires_at']).isBefore(DateTime.now()) ? 'Süresi doldu' : 'Görünür')),
      if (safeMediaUrl(record['image_url']) case final String url) Image.network(url, height: 180, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Fotoğraf yüklenemedi.')),
      if (record['video_url'] != null || section == 'stories') TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaReview(record: record, story: section == 'stories'))),
        icon: const Icon(Icons.play_circle_outline), label: const Text('Medyayı incele')),
      OutlinedButton(onPressed: acting ? null : () => reasonAction(hidden ? 'İçeriği yeniden yayınla' : 'İçeriği gizle',
        (reason) => widget.api.moderate(section, id, !hidden, reason)), child: Text(hidden ? 'Yeniden yayınla' : 'Gizle')),
    ])));
  }
}

String reportStatus(String value) => {'open':'Açık','resolved':'Çözüldü','dismissed':'İşlem gerekmiyor'}[value] ?? value;
String displayDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? '' : '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
}
String? safeMediaUrl(dynamic value) {
  final url = Uri.tryParse('$value');
  return url != null && url.scheme == 'https' && url.host == 'ikoyhonpgujbughdsouu.supabase.co' && url.path.startsWith('/storage/v1/object/public/post-media/') ? url.toString() : null;
}

class ActionReason extends StatefulWidget {
  final String title;
  final String? detail;
  const ActionReason({super.key, required this.title, this.detail});
  @override State<ActionReason> createState() => _ActionReasonState();
}
class _ActionReasonState extends State<ActionReason> {
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  @override void dispose() {text.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title)), body: Form(key: form, child: ListView(padding: const EdgeInsets.all(16), children: [
    if (widget.detail != null) Text(widget.detail!), const SizedBox(height: 16),
    const Text('Bu işlem kaydedilir ve daha sonra geri alınabilir.'), const SizedBox(height: 16),
    TextFormField(controller: text, maxLines: 5, maxLength: 500, decoration: const InputDecoration(labelText: 'İşlem gerekçesi'),
      validator: (value) => (value?.trim().length ?? 0) >= 3 ? null : 'En az 3 karakterlik bir gerekçe yaz.'),
    FilledButton(onPressed: () {if (form.currentState!.validate()) Navigator.pop(context, text.text.trim());}, child: const Text('İşlemi onayla')),
  ])));
}

class MediaReview extends StatefulWidget {
  final Row record;
  final bool story;
  const MediaReview({super.key, required this.record, required this.story});
  @override State<MediaReview> createState() => _MediaReviewState();
}
class _MediaReviewState extends State<MediaReview> with WidgetsBindingObserver {
  String? url, error;
  VideoPlayerController? player;
  @override void initState() {super.initState();WidgetsBinding.instance.addObserver(this);load();}
  Future<void> load() async {
    try {
      String? media;
      if (widget.story) {
        media = await Supabase.instance.client.storage.from('story-media').createSignedUrl(widget.record['media_path'],120);
        final parsed = Uri.parse(media);
        if (parsed.scheme != 'https' || parsed.host != 'ikoyhonpgujbughdsouu.supabase.co' || !parsed.path.startsWith('/storage/v1/object/sign/story-media/')) throw StateError('Invalid media');
      } else {media = safeMediaUrl(widget.record['video_url']);}
      if (media == null) throw StateError('Invalid media');
      if (!mounted) return;
      url = media;
      if (widget.record['kind'] == 'video' || !widget.story) {
        player = VideoPlayerController.networkUrl(Uri.parse(media));
        await player!.initialize();
      }
      if (mounted) setState(() {});
    } catch (e) {if (mounted) setState(() => error = 'Medya açılamadı. İnternet bağlantını kontrol edip ekranı yeniden aç.');}
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {if (state != AppLifecycleState.resumed) player?.pause();}
  @override void dispose() {WidgetsBinding.instance.removeObserver(this);player?.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Medya inceleme')), body: Center(child:
    error != null ? Padding(padding: const EdgeInsets.all(20), child: Text(error!)) :
    url == null || (player != null && !player!.value.isInitialized) ? const CircularProgressIndicator() :
    player == null ? Image.network(url!, errorBuilder: (_, __, ___) => const Text('Fotoğraf yüklenemedi.')) :
    Column(mainAxisSize: MainAxisSize.min, children: [AspectRatio(aspectRatio: player!.value.aspectRatio, child: VideoPlayer(player!)),
      IconButton(tooltip: 'Oynat / duraklat', onPressed: () async {
        if (player!.value.isPlaying) {await player!.pause();} else {await player!.play();}
        if (mounted) setState(() {});
      }, icon: Icon(player!.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 40)),
    ])));
}
