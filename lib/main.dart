import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ybgclxavkdakegfpxgqh.supabase.co',
    publishableKey: 'sb_publishable_7zS8HOMf7qQaT0U_MYvcfw_IKA-lQIb',
  );
  runApp(const VedoroApp());
}

const accent = Color(0xFF9B6DFF);
const background = Color(0xFF08080D);

class VedoroApp extends StatelessWidget {
  const VedoroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'VEDORO',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const AuthGate(),
  );
}

class DemoVideo {
  const DemoVideo({
    required this.url, required this.user, required this.caption,
    required this.music, required this.likes, this.status = 'approved',
    this.postId, this.authorId, this.likeCount = 0, this.commentCount = 0,
    this.isLiked = false, this.isFollowing = false,
  });
  final String url;
  final String user;
  final String caption;
  final String music;
  final String likes;
  final String status;
  final String? postId;
  final String? authorId;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isFollowing;
}

const demoVideos = [
  DemoVideo(
    url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    user: '@vedoro', caption: 'أهلاً بيكم بعالم VEDORO 💜 بداية مجتمعنا الجديد!',
    music: 'الصوت الأصلي - VEDORO', likes: '12.8K',
  ),
  DemoVideo(
    url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
    user: '@creator', caption: 'كل لحظة بيها قصة تستحق تنشاف ✨',
    music: 'موسيقى هادئة', likes: '8,420',
  ),
];

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int tab = 0;
  int activeVideo = 0;
  int feedRefresh = 0;

  void openTab(int index) {
    if (index == 2) {
      _showCreateNotice();
      return;
    }
    setState(() => tab = index);
  }

  void _showCreateNotice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191922),
      showDragHandle: true,
      builder: (sheetContext) => CreateVideoSheet(
        onUploaded: () {
          if (mounted) {
            setState(() {
              feedRefresh++;
              tab = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم رفع الفيديو. سيظهر عندك بحالة قيد المراجعة 💜')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedScreen(key: ValueKey(feedRefresh), onPageChanged: (i) => activeVideo = i),
      const ExplorePage(),
      const SizedBox.shrink(),
      const MessagesPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 66,
        backgroundColor: const Color(0xFF111118),
        indicatorColor: accent.withValues(alpha: .18),
        selectedIndex: tab,
        onDestinationSelected: openTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'اكتشف'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'نشر'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'الرسائل'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

class CreateVideoSheet extends StatefulWidget {
  const CreateVideoSheet({super.key, required this.onUploaded});
  final VoidCallback onUploaded;

  @override
  State<CreateVideoSheet> createState() => _CreateVideoSheetState();
}

class _CreateVideoSheetState extends State<CreateVideoSheet> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  XFile? _video;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 100 * 1024 * 1024) {
        _showError('حجم الفيديو أكبر من 100 ميغابايت.');
        return;
      }
      final extension = picked.path.split('.').last.toLowerCase();
      if (!['mp4', 'mov', 'webm'].contains(extension)) {
        _showError('صيغة الفيديو غير مدعومة. استخدم MP4 أو MOV أو WEBM.');
        return;
      }
      setState(() => _video = picked);
    } catch (e) {
      _showError('تعذر اختيار الفيديو: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _upload() async {
    final selected = _video;
    final user = Supabase.instance.client.auth.currentUser;
    if (selected == null || user == null || _busy) return;

    setState(() => _busy = true);
    final storage = Supabase.instance.client.storage.from('vedoro-videos');
    final extension = selected.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    var uploaded = false;

    try {
      await storage.upload(
        path,
        File(selected.path),
        fileOptions: FileOptions(contentType: mimeType, upsert: false),
      );
      uploaded = true;

      await Supabase.instance.client.from('posts').insert({
        'author_id': user.id,
        'post_type': 'video',
        'caption': _caption.text.trim(),
        'media_path': path,
        'visibility': 'public',
        'moderation_status': 'pending',
      });

      if (!mounted) return;
      Navigator.pop(context);
      widget.onUploaded();
    } catch (e) {
      if (uploaded) {
        try {
          await storage.remove([path]);
        } catch (_) {}
      }
      _showError('فشل رفع الفيديو: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.video_call_rounded, size: 46, color: accent),
            const SizedBox(height: 10),
            const Text('انشر فيديوك على VEDORO',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_video == null ? 'اختيار فيديو من الهاتف' : 'تم اختيار: ${_video!.name}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب وصف الفيديو...',
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            const Text('سيُرفع الفيديو إلى التخزين الخاص ويُرسل للمراجعة قبل ظهوره للآخرين.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _video == null || _busy ? null : _upload,
              style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 15)),
              child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('رفع الفيديو'),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.onPageChanged});
  final ValueChanged<int> onPageChanged;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int current = 0;
  late Future<List<DemoVideo>> _videos;

  @override
  void initState() {
    super.initState();
    _videos = _loadVideos();
  }

  Future<List<DemoVideo>> _loadVideos() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];
    final rows = await client.from('posts')
        .select('id, author_id, caption, media_path, moderation_status')
        .eq('visibility', 'public')
        .or('moderation_status.eq.approved,author_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(40);
    if (rows.isEmpty) return [];

    final postIds = rows.map((row) => row['id'] as String).toList();
    final authorIds = rows.map((row) => row['author_id'] as String).toSet().toList();
    final profileRows = await client.from('profiles')
        .select('id, username')
        .inFilter('id', authorIds);
    final names = <String, String>{
      for (final profile in profileRows)
        profile['id'] as String: '@${profile['username'] ?? 'user'}',
    };

    final likeRows = await client.from('post_likes')
        .select('post_id, user_id').inFilter('post_id', postIds);
    final commentRows = await client.from('comments')
        .select('post_id').inFilter('post_id', postIds);
    final followRows = await client.from('follows')
        .select('followed_id').eq('follower_id', user.id).inFilter('followed_id', authorIds);
    final likeCounts = <String, int>{};
    final commentCounts = <String, int>{};
    final likedPosts = <String>{};
    final followedUsers = followRows.map((x) => x['followed_id'] as String).toSet();
    for (final item in likeRows) {
      final id = item['post_id'] as String;
      likeCounts[id] = (likeCounts[id] ?? 0) + 1;
      if (item['user_id'] == user.id) likedPosts.add(id);
    }
    for (final item in commentRows) {
      final id = item['post_id'] as String;
      commentCounts[id] = (commentCounts[id] ?? 0) + 1;
    }

    final result = <DemoVideo>[];
    for (final row in rows) {
      final path = row['media_path'] as String?;
      if (path == null || path.isEmpty) continue;
      final postId = row['id'] as String;
      final authorId = row['author_id'] as String;
      try {
        final url = await client.storage.from('vedoro-videos').createSignedUrl(path, 3600);
        result.add(DemoVideo(
          postId: postId,
          authorId: authorId,
          url: url,
          user: names[authorId] ?? '@vedoro',
          caption: (row['caption'] ?? '').toString(),
          music: 'الصوت الأصلي',
          likes: '${likeCounts[postId] ?? 0}',
          likeCount: likeCounts[postId] ?? 0,
          commentCount: commentCounts[postId] ?? 0,
          isLiked: likedPosts.contains(postId),
          isFollowing: followedUsers.contains(authorId),
          status: (row['moderation_status'] ?? 'pending').toString(),
        ));
      } catch (_) {
        // Skip media that the current user is not allowed to read.
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DemoVideo>>(
    future: _videos,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: accent));
      }
      if (snapshot.hasError) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('تعذر تحميل الفيديوهات: ${snapshot.error}', textAlign: TextAlign.center),
        ));
      }
      final videos = snapshot.data ?? [];
      if (videos.isEmpty) {
        return const Center(child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.video_library_outlined, size: 66, color: accent),
            SizedBox(height: 14),
            Text('ماكو فيديوهات منشورة بعد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('انشر أول فيديو إلك، وبعد الموافقة راح يظهر هنا للجميع.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
          ]),
        ));
      }
      return Stack(children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: videos.length,
          onPageChanged: (index) {
            setState(() => current = index);
            widget.onPageChanged(index);
          },
          itemBuilder: (context, index) => VideoFeedItem(
            key: ValueKey(videos[index].url), video: videos[index], active: current == index,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('لك', style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 16)),
              const SizedBox(width: 22),
              const Text('متابَعون', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]);
    },
  );
}

class VideoFeedItem extends StatefulWidget {
  const VideoFeedItem({super.key, required this.video, required this.active});
  final DemoVideo video;
  final bool active;
  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  VideoPlayerController? controller;
  late bool liked;
  late bool following;
  late int likeCount;
  late int commentCount;
  bool showControls = false;
  bool failed = false;
  bool muted = false;
  bool saved = false;
  final List<String> comments = [];
  bool commentsLoading = false;
  bool actionBusy = false;

  @override
  void initState() {
    super.initState();
    liked = widget.video.isLiked;
    following = widget.video.isFollowing;
    likeCount = widget.video.likeCount;
    commentCount = widget.video.commentCount;
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        if (widget.active) controller!.play();
      }).catchError((_) {
        if (mounted) setState(() => failed = true);
      });
  }

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active && controller?.value.isInitialized == true) {
      if (widget.active) {
        controller!.play();
      } else {
        controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlayback() {
    if (controller?.value.isInitialized != true) return;
    setState(() {
      if (controller!.value.isPlaying) {
        controller!.pause();
      } else {
        controller!.play();
      }
      showControls = true;
    });
  }

  Future<void> _loadComments(StateSetter refreshSheet) async {
    final postId = widget.video.postId;
    if (postId == null) return;
    refreshSheet(() => commentsLoading = true);
    try {
      final rows = await Supabase.instance.client.from('comments')
          .select('body').eq('post_id', postId)
          .order('created_at', ascending: true).limit(100);
      comments
        ..clear()
        ..addAll(rows.map((row) => row['body'].toString()));
    } catch (e) {
      if (mounted) _showActionError('تعذر تحميل التعليقات: $e');
    } finally {
      refreshSheet(() => commentsLoading = false);
    }
  }

  Future<void> _sendComment(String value, StateSetter refreshSheet) async {
    final postId = widget.video.postId;
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null || value.trim().isEmpty) return;
    try {
      await Supabase.instance.client.from('comments').insert({
        'post_id': postId, 'author_id': user.id, 'body': value.trim(),
      });
      comments.add(value.trim());
      if (mounted) setState(() => commentCount++);
      refreshSheet(() {});
    } catch (e) {
      if (mounted) _showActionError('تعذر إرسال التعليق: $e');
    }
  }

  void _showActionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _toggleLike() async {
    final postId = widget.video.postId;
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null || actionBusy) return;
    final wasLiked = liked;
    setState(() {
      liked = !wasLiked;
      likeCount += wasLiked ? -1 : 1;
      actionBusy = true;
    });
    try {
      if (wasLiked) {
        await Supabase.instance.client.from('post_likes')
            .delete().eq('post_id', postId).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('post_likes')
            .insert({'post_id': postId, 'user_id': user.id});
      }
    } catch (e) {
      if (mounted) {
        setState(() { liked = wasLiked; likeCount += wasLiked ? 1 : -1; });
        _showActionError('تعذر تحديث الإعجاب: $e');
      }
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final authorId = widget.video.authorId;
    final user = Supabase.instance.client.auth.currentUser;
    if (authorId == null || user == null || authorId == user.id || actionBusy) return;
    final wasFollowing = following;
    setState(() { following = !wasFollowing; actionBusy = true; });
    try {
      if (wasFollowing) {
        await Supabase.instance.client.from('follows')
            .delete().eq('follower_id', user.id).eq('followed_id', authorId);
      } else {
        await Supabase.instance.client.from('follows')
            .insert({'follower_id': user.id, 'followed_id': authorId});
      }
    } catch (e) {
      if (mounted) {
        setState(() => following = wasFollowing);
        _showActionError('تعذرت عملية المتابعة: $e');
      }
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  void showComments() {
    final input = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171720),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) {
          if (!commentsLoading && comments.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (sheetContext.mounted && !commentsLoading) _loadComments(refreshSheet);
            });
          }
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              height: 430,
              child: Column(children: [
                const SizedBox(height: 18),
                Text('التعليقات $commentCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white12),
                Expanded(child: commentsLoading
                  ? const Center(child: CircularProgressIndicator(color: accent))
                  : comments.isEmpty
                    ? const Center(child: Text('كن أول من يعلّق على هذا الفيديو', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(comments[i])))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Row(children: [
                    Expanded(child: TextField(controller: input, textInputAction: TextInputAction.send, onSubmitted: (_) async {
                      final value = input.text.trim();
                      if (value.isNotEmpty) { input.clear(); await _sendComment(value, refreshSheet); }
                    }, decoration: InputDecoration(hintText: 'اكتب تعليقاً...', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
                    IconButton(onPressed: () async {
                      final value = input.text.trim();
                      if (value.isNotEmpty) { input.clear(); await _sendComment(value, refreshSheet); }
                    }, icon: const Icon(Icons.send, color: accent)),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    ).whenComplete(input.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized == true;
    return GestureDetector(
      onTap: togglePlayback,
      child: Stack(fit: StackFit.expand, children: [
        Container(
          color: const Color(0xFF171323),
          child: ready
            ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: controller!.value.size.width, height: controller!.value.size.height, child: VideoPlayer(controller!)))
            : Center(child: failed
              ? const Icon(Icons.play_circle_outline, size: 76, color: Colors.white54)
              : const CircularProgressIndicator(color: accent)),
        ),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87], stops: [0, .2, .55, 1]))),
        if (showControls && ready && !controller!.value.isPlaying)
          const Center(child: Icon(Icons.play_arrow_rounded, size: 78, color: Colors.white)),
        Positioned(
          right: 12, bottom: 24,
          child: Column(children: [
            const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
            const SizedBox(height: 22),
            _ActionButton(icon: liked ? Icons.favorite : Icons.favorite_border, label: '$likeCount', color: liked ? Colors.pinkAccent : Colors.white, onTap: _toggleLike),
            const SizedBox(height: 20),
            _ActionButton(icon: Icons.mode_comment_outlined, label: '$commentCount', onTap: showComments),
            const SizedBox(height: 20),
            _ActionButton(icon: saved ? Icons.bookmark : Icons.bookmark_border, label: saved ? 'محفوظ' : 'حفظ', color: saved ? accent : Colors.white, onTap: () => setState(() => saved = !saved)),
            const SizedBox(height: 20),
            _ActionButton(icon: Icons.share_outlined, label: 'مشاركة', onTap: () async { await Clipboard.setData(ClipboardData(text: widget.video.url)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط الفيديو'))); }),
            const SizedBox(height: 20),
            _ActionButton(icon: muted ? Icons.volume_off : Icons.music_note, label: muted ? 'صامت' : 'الصوت', onTap: () async { setState(() => muted = !muted); if (controller?.value.isInitialized == true) await controller!.setVolume(muted ? 0 : 1); }),
          ]),
        ),
        if (widget.video.status == 'pending')
          Positioned(
            top: 76, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(18)),
              child: const Text('قيد المراجعة - ظاهر لك فقط', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        Positioned(
          left: 16, right: 86, bottom: 28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(widget.video.user, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _toggleFollow,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70), padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 30)),
                child: Text(following ? 'تتابعه' : 'متابعة'),
              ),
            ]),
            const SizedBox(height: 8),
            Text(widget.video.caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.music_note, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.video.music, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            ]),
          ]),
        ),
        if (ready)
          Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(controller!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: accent, backgroundColor: Colors.white24, bufferedColor: Colors.white38))),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Column(children: [
      Icon(icon, size: 32, color: color, shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
    ]),
  );
}


class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}
class _ExplorePageState extends State<ExplorePage> {
  String query = '';
  final creators = const ['@vedoro', '@creator', '@iraq_video', '@daily_story'];
  @override
  Widget build(BuildContext context) {
    final results = creators.where((name) => name.toLowerCase().contains(query.toLowerCase())).toList();
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('اكتشف', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث عن حساب...', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 18),
        const Text('حسابات مقترحة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        Expanded(child: ListView(children: results.map((name) => ListTile(leading: const CircleAvatar(backgroundColor: accent, child: Icon(Icons.person, color: Colors.white)), title: Text(name), subtitle: const Text('صانع محتوى على VEDORO'), trailing: const Icon(Icons.chevron_right))).toList())),
      ]),
    ));
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerRight, child: Text('الرسائل', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)))),
    const ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('فريق VEDORO'), subtitle: Text('أهلاً بك في مجتمع VEDORO'), trailing: Text('')),
    const Divider(color: Colors.white12),
    const Expanded(child: Center(child: Text('محادثاتك الخاصة ستظهر هنا بعد تسجيل الدخول وربط الرسائل.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))),
  ]));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final username = (metadata['username'] ?? 'عضو جديد').toString();
    final displayName = (metadata['display_name'] ?? username).toString();
    return SafeArea(child: Column(children: [
      const SizedBox(height: 34),
      const CircleAvatar(radius: 46, backgroundColor: accent, child: Icon(Icons.person, size: 48, color: Colors.white)),
      const SizedBox(height: 12),
      Text('@$username', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      Text(displayName, style: const TextStyle(color: Colors.white70)),
      if (user?.email != null)
        Text(user!.email!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 24),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _ProfileStat(value: '0', label: 'فيديو'),
        _ProfileStat(value: '0', label: 'متابعون'),
        _ProfileStat(value: '0', label: 'يتابع'),
      ]),
      const Divider(height: 34, color: Colors.white12),
      FutureBuilder<bool>(
        future: Supabase.instance.client.from('app_admins').select('user_id')
          .eq('user_id', user?.id ?? '').maybeSingle().then((row) => row != null),
        builder: (context, snapshot) => snapshot.data == true
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewPage())),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('مراجعة المنشورات'),
                style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size.fromHeight(46)),
              ),
            )
          : const SizedBox.shrink(),
      ),
      const Expanded(child: Center(child: Text('ملفك الشخصي على VEDORO. ستظهر فيديوهاتك وإحصاءاتك هنا.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: OutlinedButton.icon(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size.fromHeight(48)),
        ),
      ),
    ]));
  }
}
class AdminReviewPage extends StatefulWidget {
  const AdminReviewPage({super.key});
  @override
  State<AdminReviewPage> createState() => _AdminReviewPageState();
}

class _AdminReviewPageState extends State<AdminReviewPage> {
  late Future<List<Map<String, dynamic>>> _pending;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pending = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('posts')
      .select('id, author_id, caption, media_path, created_at')
      .eq('moderation_status', 'pending')
      .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _review(Map<String, dynamic> post, String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.from('posts')
        .update({'moderation_status': status}).eq('id', post['id']);
      if (status == 'rejected' && post['media_path'] != null) {
        try {
          await Supabase.instance.client.storage.from('vedoro-videos')
            .remove([post['media_path'].toString()]);
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved' ? 'تمت الموافقة ونشر الفيديو 💜' : 'تم رفض الفيديو')),
      );
      setState(() => _pending = _load());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنفيذ المراجعة: $e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مراجعة المنشورات')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: accent));
        }
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل الطلبات: ${snapshot.error}'));
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return const Center(child: Text('ماكو فيديوهات بانتظار المراجعة حالياً'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              color: const Color(0xFF171720),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text((post['caption'] ?? '').toString().isEmpty ? 'فيديو بدون وصف' : post['caption'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('صاحب المنشور: ${post['author_id']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: FilledButton(
                      onPressed: _busy ? null : () => _review(post, 'approved'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                      child: const Text('موافقة ونشر'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(
                      onPressed: _busy ? null : () => _review(post, 'rejected'),
                      child: const Text('رفض'),
                    )),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    ),
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white54)),
  ]);
}

class SimplePage extends StatelessWidget {
  const SimplePage({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('VEDORO', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 27, letterSpacing: 2)),
        const SizedBox(height: 28),
        Icon(icon, size: 68, color: accent),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.6)),
      ]),
    ),
  );
}
