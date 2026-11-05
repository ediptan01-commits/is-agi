part of 'main.dart';

final communityRoutes = RouteObserver<ModalRoute<void>>();
VideoPlayerController? playingCommunityVideo;

/// Refreshes visible screens without losing their content on a background fetch.
class CommunityList extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(Map<String, dynamic>) item;
  final String empty;
  final bool reverse;
  final Duration? interval;
  const CommunityList({super.key, required this.load, required this.item,
    this.empty = 'Henüz paylaşım yok. İlk paylaşımı sen yap!',
    this.reverse = false, this.interval});
  @override State<CommunityList> createState() => CommunityListState();
}

class CommunityListState extends State<CommunityList> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? items;
  Object? error;
  bool fetching = false;
  Timer? timer;
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    if (widget.interval != null) {
      timer = Timer.periodic(widget.interval!, (_) {
        if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
            (ModalRoute.of(context)?.isCurrent ?? false)) refresh();
      });
    }
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) refresh();
  }
  Future<void> refresh() async {
    if (fetching) return;
    fetching = true;
    try {
      final result = await widget.load();
      if (mounted) setState(() { items = result; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally { fetching = false; }
  }
  @override void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override Widget build(BuildContext context) {
    if (items == null && error == null) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      if (error != null) MaterialBanner(
        content: const Text('İçerik yenilenemedi. Bağlantını kontrol edip tekrar dene.'),
        actions: [TextButton(onPressed: refresh, child: const Text('Tekrar dene'))]),
      Expanded(child: RefreshIndicator(onRefresh: refresh, child:
        items?.isNotEmpty == true ? ListView.builder(
          reverse: widget.reverse, physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12), itemCount: items!.length,
          itemBuilder: (_, i) => widget.item(items![i])) :
        ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          Padding(padding: const EdgeInsets.all(32), child: Text(widget.empty, textAlign: TextAlign.center))]))),
    ]);
  }
}

class PickedMedia {
  final XFile file;
  final Uint8List bytes;
  final bool video;
  final String contentType, extension;
  const PickedMedia(this.file, this.bytes, this.video, this.contentType, this.extension);
}

String? imageContentType(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) return 'image/jpeg';
  if (bytes.length >= 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71 && bytes[4] == 13 && bytes[5] == 10 && bytes[6] == 26 && bytes[7] == 10) return 'image/png';
  if (bytes.length >= 12 && String.fromCharCodes(bytes.sublist(0,4)) == 'RIFF' && String.fromCharCodes(bytes.sublist(8,12)) == 'WEBP') return 'image/webp';
  return null;
}

Future<PickedMedia> readPickedMedia(XFile file, {required bool video}) async {
  final limit = video ? 25 * 1024 * 1024 : 5 * 1024 * 1024;
  if (await file.length() > limit) throw Exception(video ? 'Video en fazla 25 MB olabilir.' : 'Fotoğraf en fazla 5 MB olabilir.');
  final bytes = await file.readAsBytes();
  if (video) {
    if (bytes.length < 12 || String.fromCharCodes(bytes.sublist(4,8)) != 'ftyp') throw Exception('MP4 veya MOV video seç.');
    final quicktime = String.fromCharCodes(bytes.sublist(8,12)) == 'qt  ';
    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
      if (controller.value.duration > const Duration(seconds: 60)) throw Exception('Video en fazla 60 saniye olabilir.');
    } finally { await controller.dispose(); }
    return PickedMedia(file, bytes, true, quicktime ? 'video/quicktime' : 'video/mp4', quicktime ? 'mov' : 'mp4');
  }
  final mime = imageContentType(bytes);
  if (mime == null) throw Exception('JPG, PNG veya WebP fotoğraf seç.');
  return PickedMedia(file, bytes, false, mime, mime == 'image/jpeg' ? 'jpg' : mime.split('/').last);
}

Future<void> publishCommunityPost(String text, PickedMedia? media, bool story) async {
  String? path, url;
  if (media != null) {
    path = '$me/${DateTime.now().microsecondsSinceEpoch}.${media.extension}';
    final bucket = db.storage.from(story ? 'story-media' : 'post-media');
    await bucket.uploadBinary(path, media.bytes, fileOptions: FileOptions(contentType: media.contentType));
    if (!story) url = bucket.getPublicUrl(path);
  }
  if (story) {
    if (media == null) throw Exception('Hikâye için fotoğraf veya video ekle.');
    await db.from('stories').insert({'author_id': me, 'caption': text, 'media_path': path, 'kind': media.video ? 'video' : 'image'});
  } else {
    await db.from('posts').insert({'author_id': me, 'body': text,
      'image_url': media?.video == false ? url : null, 'video_url': media?.video == true ? url : null});
  }
}

class CommunityComposer extends StatefulWidget {
  final bool story;
  final Future<void> Function(String, PickedMedia?, bool)? onPublish;
  const CommunityComposer({super.key, this.story = false, this.onPublish});
  @override State<CommunityComposer> createState() => _CommunityComposerState();
}
class _CommunityComposerState extends State<CommunityComposer> {
  final text = TextEditingController();
  PickedMedia? media;
  bool busy = false, picking = false;
  @override void initState() { super.initState(); recoverSelection(); }
  Future<void> recoverSelection() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.files?.isNotEmpty == true) {
        final file = lost.files!.first;
        final video = (file.mimeType ?? '').startsWith('video/') || RegExp(r'\.(mp4|mov)$', caseSensitive: false).hasMatch(file.name);
        final selected = await readPickedMedia(file, video: video);
        if (mounted) setState(() => media = selected);
      }
    } catch (_) { /* A cancelled picker does not prevent writing a new post. */ }
  }
  Future<void> pick(bool video) async {
    setState(() => picking = true);
    try {
      final picker = ImagePicker();
      final file = video ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60)) :
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85, requestFullMetadata: false);
      if (file != null) {
        final selected = await readPickedMedia(file, video: video);
        if (mounted) setState(() => media = selected);
      }
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => picking = false); }
  }
  Future<void> submit() async {
    final body = text.text.trim();
    if (body.isEmpty && !widget.story) { notice(context, 'Paylaşımına kısa bir not ekle.'); return; }
    if (widget.story && media == null) { notice(context, 'Hikâyene fotoğraf veya video ekle.'); return; }
    setState(() => busy = true);
    try {
      await (widget.onPublish ?? publishCommunityPost)(body, media, widget.story);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { text.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => PopScope(canPop: !busy, child: Scaffold(
    appBar: AppBar(title: Text(widget.story ? 'Hikâye paylaş' : 'Yeni paylaşım')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text(widget.story ? 'Hikâyen 24 saat boyunca görünür.' : 'Gününden bir an, bir fikir veya yaptığın bir işi paylaş.', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      TextField(controller: text, enabled: !busy, maxLines: 5, maxLength: widget.story ? 500 : 3000,
        decoration: const InputDecoration(hintText: 'Ne paylaşmak istersin?')),
      if (media != null) ...[
        if (media!.video) ListTile(leading: const Icon(Icons.movie_outlined), title: Text(media!.file.name), subtitle: const Text('Video seçildi'))
        else ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(media!.bytes, height: 240, fit: BoxFit.contain)),
        TextButton.icon(onPressed: busy ? null : () => setState(() => media = null), icon: const Icon(Icons.close), label: const Text('Eki kaldır')),
      ],
      Wrap(spacing: 12, children: [
        OutlinedButton.icon(onPressed: busy || picking ? null : () => pick(false), icon: const Icon(Icons.photo_outlined), label: const Text('Fotoğraf')),
        OutlinedButton.icon(onPressed: busy || picking ? null : () => pick(true), icon: const Icon(Icons.videocam_outlined), label: const Text('Video')),
      ]),
      const Text('Fotoğraf: 5 MB · Video: 60 saniye / 25 MB'),
      const SizedBox(height: 20),
      FilledButton(onPressed: busy || picking ? null : submit, child: Padding(padding: const EdgeInsets.all(12), child:
        busy || picking ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Paylaş'))),
    ])));
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override State<FeedPage> createState() => _FeedPageState();
}
class _FeedPageState extends State<FeedPage> {
  bool followingOnly = false;
  int generation = 0;
  Future<List<Map<String, dynamic>>> load() async {
    var query = db.from('posts').select('id,author_id,body,image_url,video_url,created_at,profiles!posts_author_id_fkey(full_name,profession)');
    if (followingOnly) {
      final follows = await db.from('follows').select('following_id').eq('follower_id', me);
      final ids = [me, ...follows.map((x) => x['following_id'] as String)];
      query = query.inFilter('author_id', ids);
    }
    return (await query.order('created_at', ascending: false).limit(100)).map(row).toList();
  }
  Future<void> compose({bool story = false}) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => CommunityComposer(story: story)));
    if (changed == true && mounted) setState(() => generation++);
  }
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: SizedBox(width: double.infinity,
      child: FilledButton.icon(onPressed: compose, icon: const Icon(Icons.add), label: const Text('Bir şeyler paylaş')))),
    StoryStrip(key: ValueKey('stories-$generation'), onAdd: () => compose(story: true)),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
      ChoiceChip(label: const Text('Herkes'), selected: !followingOnly, onSelected: (_) => setState(() => followingOnly = false)),
      const SizedBox(width: 8),
      ChoiceChip(label: const Text('Takip ettiklerim'), selected: followingOnly, onSelected: (_) => setState(() => followingOnly = true)),
      const Spacer(), IconButton(tooltip: 'Akışı yenile', onPressed: () => setState(() => generation++), icon: const Icon(Icons.refresh)),
    ])),
    Expanded(child: CommunityList(key: ValueKey('$followingOnly-$generation'), load: load,
      empty: followingOnly ? 'Takip ettiğin kişilerin paylaşımları burada. Keşfet bölümünden yeni kişiler bulabilirsin.' : 'Henüz paylaşım yok. İlk paylaşımı sen yap!',
      item: (post) => PostTile(key: ValueKey(post['id']), post: post, onChange: () => setState(() => generation++)))),
  ]);
}

class CommunityVideo extends StatefulWidget {
  final String url;
  const CommunityVideo({super.key, required this.url});
  @override State<CommunityVideo> createState() => _CommunityVideoState();
}
class _CommunityVideoState extends State<CommunityVideo> with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? controller;
  bool loading = false;
  Object? error;
  Future<void> start() async {
    if (loading) return;
    if (controller != null && error == null) {
      if (controller!.value.isPlaying) { await controller!.pause(); } else {
        if (playingCommunityVideo != controller) await playingCommunityVideo?.pause();
        playingCommunityVideo = controller;
        await controller!.play();
      }
      if (mounted) setState(() {});
      return;
    }
    setState(() { loading = true; error = null; });
    await controller?.dispose();
    final player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller = player;
    try {
      await player.initialize();
      if (!mounted) return;
      if (playingCommunityVideo != player) await playingCommunityVideo?.pause();
      playingCommunityVideo = player;
      await player.play();
    } catch (e) { if (mounted) setState(() => error = e); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) communityRoutes.subscribe(this, route);
  }
  @override void didPushNext() { controller?.pause(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller?.pause();
  }
  @override void dispose() {
    communityRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    if (playingCommunityVideo == controller) playingCommunityVideo = null;
    controller?.dispose(); super.dispose();
  }
  @override Widget build(BuildContext context) => Column(children: [
    if (controller?.value.isInitialized == true && error == null)
      AspectRatio(aspectRatio: controller!.value.aspectRatio, child: VideoPlayer(controller!)),
    if (error != null) const Text('Video açılamadı. Tekrar deneyebilirsin.'),
    if (loading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
    else TextButton.icon(onPressed: start, icon: Icon(controller?.value.isPlaying == true ? Icons.pause : Icons.play_circle_outline),
      label: Text(controller?.value.isPlaying == true ? 'Duraklat' : 'Videoyu oynat')),
  ]);
}

class FollowButton extends StatefulWidget {
  final String userId;
  const FollowButton({super.key, required this.userId});
  @override State<FollowButton> createState() => _FollowButtonState();
}

class ProfileSocialStats extends StatelessWidget {
  final String userId;
  const ProfileSocialStats({super.key, required this.userId});
  Future<List<int>> load() async {
    final followers = await db.from('follows').select('follower_id').eq('following_id', userId);
    final following = await db.from('follows').select('following_id').eq('follower_id', userId);
    return [followers.length, following.length];
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<int>>(future: load(), builder: (_, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${snapshot.data![0]} takipçi · ${snapshot.data![1]} takip', style: const TextStyle(fontWeight: FontWeight.bold)));
  });
}
class _FollowButtonState extends State<FollowButton> {
  bool? following;
  bool busy = false;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final rows = await db.from('follows').select('following_id').eq('follower_id', me).eq('following_id', widget.userId);
      if (mounted) setState(() => following = rows.isNotEmpty);
    } catch (e) { if (mounted) notice(context, e); }
  }
  Future<void> toggle() async {
    if (following == null) { await load(); return; }
    setState(() => busy = true);
    try {
      if (following!) {
        await db.from('follows').delete().eq('follower_id', me).eq('following_id', widget.userId);
      } else {
        await db.from('follows').insert({'follower_id': me, 'following_id': widget.userId});
      }
      if (mounted) setState(() => following = !following!);
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => FilledButton.tonal(onPressed: busy ? null : toggle,
    child: Text(following == null ? 'Takip durumunu yükle' : following! ? 'Takibi bırak' : 'Takip et'));
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});
  Future<List<Map<String, dynamic>>> load() async {
    final messages = await db.from('messages').select('id,sender_id,recipient_id,body,created_at')
      .or('sender_id.eq.$me,recipient_id.eq.$me').order('created_at', ascending: false).limit(200);
    final latest = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      final id = (message['sender_id'] == me ? message['recipient_id'] : message['sender_id']) as String;
      latest.putIfAbsent(id, () => row(message));
    }
    if (latest.isEmpty) return [];
    final people = await db.from('profiles').select('id,full_name,profession').inFilter('id', latest.keys.toList());
    final byId = {for (final person in people) person['id']: row(person)};
    return latest.entries.where((entry) => byId.containsKey(entry.key)).map((entry) => {
      ...byId[entry.key]!, 'last_body': entry.value['body'], 'last_at': entry.value['created_at'],
    }).toList();
  }
  @override Widget build(BuildContext context) => CommunityList(load: load, interval: const Duration(seconds: 8),
    empty: 'Henüz sohbet yok. Keşfet bölümünden birine mesaj gönder.',
    item: (person) => panel(ListTile(leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
      title: Text('${person['full_name']}'), subtitle: Text('${person['last_body']}', maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(otherId: person['id'], name: '${person['full_name']}'))))));
}

class ChatPage extends StatefulWidget {
  final String otherId, name;
  const ChatPage({super.key, required this.otherId, required this.name});
  @override State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  final text = TextEditingController();
  final listKey = GlobalKey<CommunityListState>();
  bool sending = false;
  Future<List<Map<String, dynamic>>> load() async => (await db.from('messages')
    .select('id,sender_id,recipient_id,body,created_at')
    .or('and(sender_id.eq.$me,recipient_id.eq.${widget.otherId}),and(sender_id.eq.${widget.otherId},recipient_id.eq.$me)')
    .order('created_at', ascending: false).limit(100)).map(row).toList();
  Future<void> send() async {
    final body = text.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await db.from('messages').insert({'sender_id': me, 'recipient_id': widget.otherId, 'body': body});
      if (mounted) {
        if (text.text.trim() == body) text.clear();
        await listKey.currentState?.refresh();
      }
    } catch (e) { if (mounted) notice(context, e); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override void dispose() { text.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.name),
    actions: [IconButton(tooltip: 'Mesajları yenile', onPressed: () => listKey.currentState?.refresh(), icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: Column(children: [
      Expanded(child: CommunityList(key: listKey, load: load, reverse: true, interval: const Duration(seconds: 4),
        empty: 'Sohbeti başlat. Bir merhaba yaz!', item: (message) => Align(
          alignment: message['sender_id'] == me ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Card(
            color: message['sender_id'] == me ? Theme.of(context).colorScheme.primaryContainer : null,
            child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${message['body']}'), const SizedBox(height: 4),
              Text(messageTime('${message['created_at']}'), style: Theme.of(context).textTheme.labelSmall),
            ]))))))),
      Padding(padding: const EdgeInsets.all(10), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: text, minLines: 1, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'Mesaj yaz...'))),
        IconButton(tooltip: 'Mesaj gönder', onPressed: sending ? null : send,
          icon: sending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
      ])),
    ])));
}

String messageTime(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return '';
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override State<NotificationBell> createState() => _NotificationBellState();
}
class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  int count = 0;
  bool fetching = false;
  Timer? timer;
  Future<void> refresh() async {
    if (fetching || db.auth.currentUser == null) return;
    fetching = true;
    try {
      final result = await db.from('notifications').select('id').eq('user_id', me).eq('is_read', false).limit(100);
      if (mounted) setState(() => count = result.length);
    } catch (_) { /* Keep the last known badge during a temporary outage. */ }
    finally { fetching = false; }
  }
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); refresh();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) refresh();
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) refresh(); }
  @override void dispose() { timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override Widget build(BuildContext context) => IconButton(tooltip: 'Bildirimler', onPressed: () async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
    if (mounted) refresh();
  }, icon: Badge(isLabelVisible: count > 0, label: Text(count > 99 ? '99+' : '$count'), child: const Icon(Icons.notifications_none)));
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}
class _NotificationsPageState extends State<NotificationsPage> {
  final listKey = GlobalKey<CommunityListState>();
  Future<List<Map<String, dynamic>>> load() async => (await db.from('notifications')
    .select('id,actor_id,kind,body,is_read,created_at').eq('user_id', me).order('created_at', ascending: false).limit(100)).map(row).toList();
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Bildirimler'), actions: [
    TextButton(onPressed: () => runSafe(context, () async {
      await db.from('notifications').update({'is_read': true}).eq('user_id', me).eq('is_read', false);
      await listKey.currentState?.refresh();
    }), child: const Text('Tümünü okundu yap')),
  ]), body: CommunityList(key: listKey, load: load, interval: const Duration(seconds: 8), empty: 'Henüz bildirim yok.',
    item: (notification) => Card(color: notification['is_read'] == true ? null : Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(leading: Icon(notification['is_read'] == true ? Icons.notifications_none : Icons.notifications_active),
        title: Text('${notification['body']}'), subtitle: Text(messageTime('${notification['created_at']}')),
        onTap: () => runSafe(context, () async {
          await db.from('notifications').update({'is_read': true}).eq('id', notification['id']).eq('user_id', me);
          await listKey.currentState?.refresh();
          if (!context.mounted || notification['actor_id'] == null) return;
          if (notification['kind'] == 'messages') {
            final actor = await profile(notification['actor_id']);
            if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(otherId: actor['id'], name: '${actor['full_name']}')));
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: notification['actor_id'])));
          }
        })))));
}

class StoryStrip extends StatefulWidget {
  final VoidCallback onAdd;
  const StoryStrip({super.key, required this.onAdd});
  @override State<StoryStrip> createState() => _StoryStripState();
}
class _StoryStripState extends State<StoryStrip> {
  List<Map<String, dynamic>> stories = [];
  bool failed = false;
  Timer? timer;
  bool fetching = false;
  @override void initState() {
    super.initState(); load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed && (ModalRoute.of(context)?.isCurrent ?? false)) load();
    });
  }
  Future<void> load() async {
    if (fetching) return;
    fetching = true;
    try {
      final result = await db.from('stories').select('id,author_id,caption,kind,media_path,expires_at,profiles!stories_author_id_fkey(full_name)')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String()).order('created_at', ascending: false).limit(50);
      if (mounted) setState(() { stories = result.map(row).toList(); failed = false; });
    } catch (_) { if (mounted) setState(() => failed = true); }
    finally { fetching = false; }
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
      SizedBox(width: 78, child: InkWell(onTap: widget.onAdd, child: const Column(children: [
        CircleAvatar(radius: 27, child: Icon(Icons.add)), SizedBox(height: 6), Text('Hikâyen', maxLines: 1),
      ]))),
      if (failed) TextButton(onPressed: load, child: const Text('Hikâyeleri yenile')),
      ...stories.map((story) => SizedBox(width: 82, child: InkWell(onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => StoryPage(story: story)));
        if (mounted) load();
      }, child: Column(children: [
        CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primary, child:
          Icon(story['kind'] == 'video' ? Icons.videocam_outlined : Icons.photo_outlined, color: Colors.white)),
        const SizedBox(height: 6), Text('${row(story['profiles'] ?? {})['full_name'] ?? 'Kullanıcı'}', maxLines: 1, overflow: TextOverflow.ellipsis),
      ])))),
    ]));
}

class StoryPage extends StatefulWidget {
  final Map<String, dynamic> story;
  const StoryPage({super.key, required this.story});
  @override State<StoryPage> createState() => _StoryPageState();
}
class _StoryPageState extends State<StoryPage> {
  String? url;
  bool expired = false;
  Object? error;
  Timer? timer;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final remaining = DateTime.parse(widget.story['expires_at']).difference(DateTime.now().toUtc());
    if (remaining.inSeconds <= 0) { setState(() => expired = true); return; }
    timer = Timer(remaining, () { if (mounted) setState(() { expired = true; url = null; }); });
    try {
      final signed = await db.storage.from('story-media').createSignedUrl(widget.story['media_path'], remaining.inSeconds.clamp(1, 60).toInt());
      if (mounted && !expired) setState(() => url = signed);
    } catch (e) { if (mounted) setState(() => error = e); }
  }
  Future<void> delete() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Hikâyeyi sil?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil'))]));
    if (confirmed != true || !mounted) return;
    await runSafe(context, () async {
      await db.from('stories').delete().eq('id', widget.story['id']).eq('author_id', me);
      try { await db.storage.from('story-media').remove([widget.story['media_path'] as String]); } catch (_) { /* Expired objects remain inaccessible. */ }
      if (mounted) Navigator.pop(context);
    });
  }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('${row(widget.story['profiles'] ?? {})['full_name'] ?? 'Hikâye'}'), actions: [
    if (widget.story['author_id'] == me) IconButton(tooltip: 'Hikâyeyi sil', onPressed: delete, icon: const Icon(Icons.delete_outline))
    else IconButton(tooltip: 'Hikâyeyi şikâyet et', icon: const Icon(Icons.flag_outlined), onPressed: () => editText(context, title: 'Hikâyeyi şikâyet et', save: (reason) async {
      await db.from('reports').insert({'reporter_id': me, 'target_user_id': widget.story['author_id'], 'reason': 'Hikâye ${widget.story['id']}: ${reason.substring(0, reason.length.clamp(0, 420).toInt())}'});
    })),
  ]), body: expired ? const Center(child: Text('Bu hikâyenin süresi doldu.')) : error != null ? const Center(child: Text('Hikâye açılamadı. Süresi dolmuş veya kaldırılmış olabilir.')) :
    url == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.story['kind'] == 'video') CommunityVideo(url: url!)
      else Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Fotoğraf yüklenemedi.')),
      const SizedBox(height: 16), Text('${widget.story['caption'] ?? ''}'),
      if (widget.story['author_id'] != me) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
        otherId: widget.story['author_id'], name: '${row(widget.story['profiles'] ?? {})['full_name'] ?? 'Kullanıcı'}'))), icon: const Icon(Icons.chat_bubble_outline), label: const Text('Mesaj gönder')),
    ]));
}
