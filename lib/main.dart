import 'dart:async';
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
              const SnackBar(content: Text('تم نشر الفيديو بنجاح على VEDORO 💜')),
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
        'moderation_status': 'approved',
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
            const Text('سيُنشر الفيديو مباشرة بعد رفعه. أبلغ عن أي محتوى مخالف حتى تتم مراجعته.',
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
        .select('id, author_id, caption, media_path, moderation_status, created_at')
        .eq('visibility', 'public')
        .or('moderation_status.eq.approved,author_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(40);
    if (rows.isEmpty) return [];

    final blockRows = await client.from('user_blocks')
        .select('blocker_id, blocked_id')
        .or('blocker_id.eq.${user.id},blocked_id.eq.${user.id}');
    final blockedIds = <String>{};
    for (final block in blockRows) {
      final blocker = block['blocker_id'].toString();
      final blocked = block['blocked_id'].toString();
      blockedIds.add(blocker == user.id ? blocked : blocker);
    }
    final visibleRows = rows.where((row) => !blockedIds.contains(row['author_id'].toString())).toList();
    if (visibleRows.isEmpty) return [];

    final postIds = visibleRows.map((row) => row['id'] as String).toList();
    final authorIds = visibleRows.map((row) => row['author_id'] as String).toSet().toList();
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

    final popularity = <String, int>{};
    for (final id in postIds) {
      popularity[id] = (likeCounts[id] ?? 0) * 3 + (commentCounts[id] ?? 0) * 2;
    }
    final now = DateTime.now().toUtc();
    visibleRows.sort((a, b) {
      double score(Map<String, dynamic> row) {
        final id = row['id'].toString();
        final author = row['author_id'].toString();
        final created = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toUtc() ?? now;
        final ageHours = now.difference(created).inHours.clamp(0, 24 * 30);
        final freshness = (720 - ageHours) / 24;
        final followBoost = followedUsers.contains(author) ? 12.0 : 0.0;
        final ownBoost = author == user.id ? 2.0 : 0.0;
        return (popularity[id] ?? 0).toDouble() + freshness + followBoost + ownBoost;
      }
      return score(b).compareTo(score(a));
    });

    final result = <DemoVideo>[];
    for (final row in visibleRows) {
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
  bool savingBusy = false;
  final List<Map<String, dynamic>> comments = [];
  Map<String, dynamic>? _replyTo;
  bool commentsLoading = false;
  bool actionBusy = false;
  Timer? _viewTimer;
  String? _viewRecordId;
  int _watchedMs = 0;

  @override
  void initState() {
    super.initState();
    liked = widget.video.isLiked;
    following = widget.video.isFollowing;
    likeCount = widget.video.likeCount;
    commentCount = widget.video.commentCount;
    _loadSavedState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        if (widget.active) { controller!.play(); _startViewTracking(); }
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
        _startViewTracking();
      } else {
        controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _saveViewProgress();
    controller?.dispose();
    super.dispose();
  }

  void _startViewTracking() {
    if (_viewTimer != null || widget.video.postId == null) return;
    _viewTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !widget.active || controller?.value.isPlaying != true) return;
      _watchedMs += 5000;
      _saveViewProgress();
    });
  }

  Future<void> _saveViewProgress() async {
    final postId = widget.video.postId;
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null || _watchedMs <= 0) return;
    try {
      final duration = controller?.value.duration.inMilliseconds ?? 0;
      final completed = duration > 0 && _watchedMs >= duration * 0.9;
      if (_viewRecordId == null) {
        final inserted = await Supabase.instance.client.from('post_views').insert({
          'post_id': postId,
          'viewer_id': user.id,
          'watch_duration_ms': _watchedMs,
          'video_duration_ms': duration > 0 ? duration : null,
          'completed': completed,
        }).select('id').single();
        _viewRecordId = inserted['id'].toString();
      } else {
        await Supabase.instance.client.from('post_views').update({
          'watch_duration_ms': _watchedMs,
          'video_duration_ms': duration > 0 ? duration : null,
          'completed': completed,
        }).eq('id', _viewRecordId!).eq('viewer_id', user.id);
      }
    } catch (_) {}
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

  Future<void> _loadSavedState() async {
    final postId = widget.video.postId;
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null) return;
    try {
      final row = await Supabase.instance.client.from('saved_posts')
        .select('post_id').eq('user_id', user.id).eq('post_id', postId).maybeSingle();
      if (mounted) setState(() => saved = row != null);
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    final postId = widget.video.postId;
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null || savingBusy) return;
    final wasSaved = saved;
    setState(() { saved = !wasSaved; savingBusy = true; });
    try {
      if (wasSaved) {
        await Supabase.instance.client.from('saved_posts')
          .delete().eq('user_id', user.id).eq('post_id', postId);
      } else {
        await Supabase.instance.client.from('saved_posts')
          .insert({'user_id': user.id, 'post_id': postId});
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasSaved ? 'أزلنا الفيديو من المحفوظات' : 'انحفظ الفيديو بالمفضلة 💜')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => saved = wasSaved);
        _showActionError('تعذر حفظ الفيديو: $e');
      }
    } finally {
      if (mounted) setState(() => savingBusy = false);
    }
  }

  Future<void> _reportPost() async {
    final postId = widget.video.postId;
    final user = Supabase.instance.client.auth.currentUser;
    if (postId == null || user == null) return;
    final reasons = ['محتوى مسيء أو تنمّر', 'عنف أو محتوى خطير', 'محتوى جنسي', 'احتيال أو انتحال', 'حقوق ملكية', 'سبب آخر'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171720),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('الإبلاغ عن الفيديو', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ...reasons.map((item) => ListTile(title: Text(item), onTap: () => Navigator.pop(ctx, item))),
      ])),
    );
    if (reason == null) return;
    try {
      await Supabase.instance.client.from('content_reports').insert({
        'reporter_id': user.id, 'post_id': postId, 'reason': reason,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وصل بلاغك، شكراً لمساعدتنا في حماية المجتمع.')),
      );
    } catch (e) {
      if (mounted) _showActionError('تعذر إرسال البلاغ: $e');
    }
  }

  Future<void> _loadComments(StateSetter refreshSheet) async {
    final postId = widget.video.postId;
    if (postId == null) return;
    refreshSheet(() => commentsLoading = true);
    try {
      final client = Supabase.instance.client;
      final rows = await client.from('comments').select('id, body, author_id, parent_comment_id, created_at')
          .eq('post_id', postId).order('created_at', ascending: true).limit(100);
      final authorIds = rows.map((row) => row['author_id'].toString()).toSet().toList();
      final commentIds = rows.map((row) => row['id'].toString()).toList();
      final profiles = authorIds.isEmpty ? [] : await client.from('profiles')
          .select('id, username, avatar_path').inFilter('id', authorIds);
      final byId = {for (final p in profiles) p['id'].toString(): p};
      final likes = commentIds.isEmpty ? [] : await client.from('comment_likes').select('comment_id, user_id').inFilter('comment_id', commentIds);
      final counts = <String, int>{};
      final mine = <String>{};
      for (final like in likes) {
        final id = like['comment_id'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
        if (like['user_id'] == client.auth.currentUser!.id) mine.add(id);
      }
      comments..clear()..addAll(rows.map((row) {
        final id = row['id'].toString();
        return <String, dynamic>{...Map<String, dynamic>.from(row),
          'username': byId[row['author_id'].toString()]?['username'] ?? 'user',
          'avatar_path': byId[row['author_id'].toString()]?['avatar_path'],
          'like_count': counts[id] ?? 0, 'is_liked': mine.contains(id)};
      }));
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
        if (_replyTo != null) 'parent_comment_id': _replyTo!['id'],
      });
      _replyTo = null;
      await _loadComments(refreshSheet);
      if (mounted) setState(() => commentCount++);
      refreshSheet(() {});
    } catch (e) {
      if (mounted) _showActionError('تعذر إرسال التعليق: $e');
    }
  }
  Future<void> _toggleCommentLike(Map<String, dynamic> comment, StateSetter refreshSheet) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final id = comment['id'].toString();
    final wasLiked = comment['is_liked'] == true;
    refreshSheet(() { comment['is_liked'] = !wasLiked; comment['like_count'] = (comment['like_count'] as int? ?? 0) + (wasLiked ? -1 : 1); });
    try {
      if (wasLiked) { await client.from('comment_likes').delete().eq('comment_id', id).eq('user_id', uid); }
      else { await client.from('comment_likes').insert({'comment_id': id, 'user_id': uid}); }
    } catch (e) {
      refreshSheet(() { comment['is_liked'] = wasLiked; comment['like_count'] = (comment['like_count'] as int? ?? 0) + (wasLiked ? 1 : -1); });
      if (mounted) _showActionError('تعذر تسجيل الإعجاب: $e');
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
                    : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) {
                      final item = comments[i];
                      final reply = item['parent_comment_id'] != null;
                      return Padding(
                        padding: EdgeInsets.only(left: reply ? 32 : 0),
                        child: ListTile(
                          dense: true,
                          leading: VedoroAvatar(path: item['avatar_path']?.toString(), radius: 19),
                          title: Text('@${item['username']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (reply) const Text('رد على تعليق', style: TextStyle(color: accent, fontSize: 10)),
                            Text(item['body'].toString()),
                            Row(children: [
                              TextButton.icon(
                                onPressed: () {
                                  refreshSheet(() => _replyTo = item);
                                  input.text = '@${item['username']} ';
                                  input.selection = TextSelection.collapsed(offset: input.text.length);
                                },
                                icon: const Icon(Icons.reply, size: 16), label: const Text('رد'),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _toggleCommentLike(item, refreshSheet),
                                icon: Icon(item['is_liked'] == true ? Icons.favorite : Icons.favorite_border,
                                  color: item['is_liked'] == true ? Colors.pinkAccent : Colors.white60, size: 18),
                              ),
                              Text('${item['like_count']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),
                          ]),
                        ),
                      );
                    })),
                if (_replyTo != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Expanded(child: Text('الرد على @${_replyTo!['username']}', style: const TextStyle(color: accent, fontSize: 12))),
                      IconButton(onPressed: () => refreshSheet(() => _replyTo = null), icon: const Icon(Icons.close, size: 18)),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Row(children: [
                    Expanded(child: TextField(controller: input, textInputAction: TextInputAction.send, onSubmitted: (_) async {
                      final value = input.text.trim();
                      if (value.isNotEmpty) { input.clear(); await _sendComment(value, refreshSheet); }
                    }, decoration: InputDecoration(hintText: 'اكتب تعليقاً أو @اسم المستخدم...', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
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
            _ActionButton(icon: saved ? Icons.bookmark : Icons.bookmark_border, label: saved ? 'محفوظ' : 'حفظ', color: saved ? accent : Colors.white, onTap: _toggleSaved),
            const SizedBox(height: 20),
            _ActionButton(icon: Icons.share_outlined, label: 'مشاركة', onTap: () async { await Clipboard.setData(ClipboardData(text: widget.video.url)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط الفيديو'))); }),
            const SizedBox(height: 20),
            _ActionButton(icon: muted ? Icons.volume_off : Icons.music_note, label: muted ? 'صامت' : 'الصوت', onTap: () async { setState(() => muted = !muted); if (controller?.value.isInitialized == true) await controller!.setVolume(muted ? 0 : 1); }),
            const SizedBox(height: 18),
            _ActionButton(icon: Icons.flag_outlined, label: 'إبلاغ', onTap: _reportPost),
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



class VedoroAvatar extends StatelessWidget {
  const VedoroAvatar({super.key, this.path, this.radius = 22});
  final String? path;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final value = path?.trim();
    final url = value == null || value.isEmpty ? null
      : Supabase.instance.client.storage.from('vedoro-avatars').getPublicUrl(value);
    return CircleAvatar(radius: radius, backgroundColor: accent,
      backgroundImage: url == null ? null : NetworkImage(url),
      child: url == null ? Icon(Icons.person, size: radius * 1.1, color: Colors.white) : null);
  }
}


class StoryTray extends StatefulWidget {
  const StoryTray({super.key});
  @override
  State<StoryTray> createState() => _StoryTrayState();
}

class _StoryTrayState extends State<StoryTray> {
  late Future<List<Map<String, dynamic>>> _stories;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _stories = _loadStories();
  }

  Future<List<Map<String, dynamic>>> _loadStories() async {
    final client = Supabase.instance.client;
    final rows = await client.from('stories')
      .select('id, user_id, media_path, caption, created_at, expires_at')
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: false).limit(100);
    final stories = List<Map<String, dynamic>>.from(rows);
    final ids = stories.map((x) => x['user_id'].toString()).toSet().toList();
    if (ids.isNotEmpty) {
      final profiles = await client.from('profiles')
        .select('id, username, avatar_path').inFilter('id', ids);
      final byId = {for (final p in profiles) p['id'].toString(): p};
      for (final story in stories) {
        story['profile'] = byId[story['user_id'].toString()];
      }
    }
    return stories;
  }

  Future<void> _addStory() async {
    if (_uploading) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final size = await file.length();
    if (size > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حجم صورة القصة يجب ألا يتجاوز 10 ميغابايت')),
      );
      return;
    }
    final ext = picked.path.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => '',
    };
    if (mime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الصيغ المدعومة: JPG وPNG وWEBP')),
      );
      return;
    }
    setState(() => _uploading = true);
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    var uploaded = false;
    try {
      final client = Supabase.instance.client;
      await client.storage.from('vedoro-stories').upload(
        path, file, fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      uploaded = true;
      await client.from('stories').insert({
        'user_id': user.id,
        'media_path': path,
        'media_type': 'image',
        'caption': '',
        'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
      });
      if (mounted) {
        setState(() => _stories = _loadStories());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('نُشرت قصتك لمدة 24 ساعة 💜')),
        );
      }
    } catch (e) {
      if (uploaded) {
        try { await Supabase.instance.client.storage.from('vedoro-stories').remove([path]); } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر نشر القصة: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _stories,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final story in all) {
          grouped.putIfAbsent(story['user_id'].toString(), () => []).add(story);
        }
        final users = grouped.entries.toList();
        final uid = Supabase.instance.client.auth.currentUser?.id;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('القصص', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Builder(builder: (context) {
                final mine = grouped[uid] ?? [];
                return SizedBox(width: 72, child: Column(children: [
                  GestureDetector(
                    onTap: mine.isNotEmpty ? () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StoryViewerPage(stories: mine),
                    )).then((_) { if (mounted) setState(() => _stories = _loadStories()); }) : null,
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      const VedoroAvatar(radius: 25),
                      Container(width: 20, height: 20,
                        decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: const Icon(Icons.auto_stories, size: 13, color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text(mine.isEmpty ? 'قصتك' : 'قصتك', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: _uploading ? null : _addStory,
                      child: const Icon(Icons.add_circle, size: 17, color: accent)),
                  ]),
                ]));
              }),
              ...users.where((entry) => entry.key != uid).map((entry) {
                final first = entry.value.first;
                final profile = first['profile'] as Map<String, dynamic>?;
                final username = (profile?['username'] ?? 'user').toString();
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StoryViewerPage(stories: entry.value),
                  )).then((_) { if (mounted) setState(() => _stories = _loadStories()); }),
                  child: SizedBox(width: 72, child: Column(children: [
                    Container(padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 2)),
                      child: VedoroAvatar(path: profile?['avatar_path']?.toString(), radius: 23)),
                    const SizedBox(height: 5),
                    Text(username, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  ])),
                );
              }),
            ],
          )),
        ]);
      },
    ),
  );
}

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({super.key, required this.stories});
  final List<Map<String, dynamic>> stories;
  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  int _index = 0;
  late Future<String> _url;
  final _reply = TextEditingController();
  bool _reacting = false;
  bool _replying = false;
  static const _reactions = ['❤️','😂','😮','🔥','👏','😍'];

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _react(String emoji) async {
    if (_reacting) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _reacting = true);
    try {
      await Supabase.instance.client.from('story_reactions').upsert({
        'story_id': widget.stories[_index]['id'],
        'user_id': user.id,
        'reaction': emoji,
      }, onConflict: 'story_id,user_id');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أرسلت تفاعلك $emoji')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال التفاعل: $e')),
      );
    } finally {
      if (mounted) setState(() => _reacting = false);
    }
  }

  Future<void> _replyToStory() async {
    final body = _reply.text.trim();
    if (body.isEmpty || _replying) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final storyOwner = widget.stories[_index]['user_id'].toString();
    if (user == null || storyOwner == user.id) return;
    setState(() => _replying = true);
    try {
      final mine = await client.from('conversation_members')
        .select('conversation_id').eq('user_id', user.id);
      final myIds = mine.map((x) => x['conversation_id'].toString()).toList();
      String? conversationId;
      if (myIds.isNotEmpty) {
        final theirs = await client.from('conversation_members')
          .select('conversation_id').eq('user_id', storyOwner).inFilter('conversation_id', myIds);
        if (theirs.isNotEmpty) conversationId = theirs.first['conversation_id'].toString();
      }
      if (conversationId == null) {
        final conversation = await client.from('conversations')
          .insert({'created_by': user.id, 'is_group': false})
          .select('id').single();
        conversationId = conversation['id'].toString();
        await client.from('conversation_members').insert([
          {'conversation_id': conversationId, 'user_id': user.id},
          {'conversation_id': conversationId, 'user_id': storyOwner},
        ]);
      }
      await client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': user.id,
        'body': 'رد على القصة: $body',
      });
      _reply.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الرد إلى الرسائل الخاصة 💬')),
        );
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatPage(conversationId: conversationId!, title: 'محادثة VEDORO'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الرد: $e')),
      );
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _setUrl();
    _recordView();
  }

  Future<void> _recordView() async {
    final user = Supabase.instance.client.auth.currentUser;
    final story = widget.stories[_index];
    if (user == null || story['user_id'].toString() == user.id) return;
    try {
      await Supabase.instance.client.from('story_views').upsert({
        'story_id': story['id'], 'viewer_id': user.id,
      }, onConflict: 'story_id,viewer_id', ignoreDuplicates: true);
    } catch (_) {}
  }

  Future<void> _showStoryInsights() async {
    final storyId = widget.stories[_index]['id'];
    try {
      final client = Supabase.instance.client;
      final views = await client.from('story_views')
        .select('viewer_id, viewed_at').eq('story_id', storyId)
        .order('viewed_at', ascending: false);
      final reactions = await client.from('story_reactions')
        .select('user_id, reaction, created_at').eq('story_id', storyId)
        .order('created_at', ascending: false);
      final ids = <String>{
        ...views.map((x) => x['viewer_id'].toString()),
        ...reactions.map((x) => x['user_id'].toString()),
      }.toList();
      final profiles = ids.isEmpty ? [] : await client.from('profiles')
        .select('id, username, avatar_path').inFilter('id', ids);
      final byId = {for (final p in profiles) p['id'].toString(): p};
      if (!mounted) return;
      showModalBottomSheet(
        context: context, backgroundColor: const Color(0xFF171720),
        isScrollControlled: true, showDragHandle: true,
        builder: (ctx) => SafeArea(child: SizedBox(height: 440, child: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Text(
            'مشاهدو القصة والتفاعلات • ${views.length} مشاهدة',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          Expanded(child: ListView(children: [
            const ListTile(title: Text('المشاهدات', style: TextStyle(color: accent, fontWeight: FontWeight.bold))),
            if (views.isEmpty) const ListTile(title: Text('لا توجد مشاهدات بعد')),
            ...views.map((v) {
              final p = byId[v['viewer_id'].toString()];
              return ListTile(
                leading: VedoroAvatar(path: p?['avatar_path']?.toString(), radius: 20),
                title: Text('@${p?['username'] ?? 'user'}'),
                subtitle: const Text('شاهد القصة'),
              );
            }),
            const Divider(color: Colors.white12),
            const ListTile(title: Text('التفاعلات', style: TextStyle(color: accent, fontWeight: FontWeight.bold))),
            if (reactions.isEmpty) const ListTile(title: Text('لا توجد تفاعلات بعد')),
            ...reactions.map((r) {
              final p = byId[r['user_id'].toString()];
              return ListTile(
                leading: VedoroAvatar(path: p?['avatar_path']?.toString(), radius: 20),
                title: Text('@${p?['username'] ?? 'user'}'),
                trailing: Text(r['reaction'].toString(), style: const TextStyle(fontSize: 25)),
              );
            }),
          ])),
        ]))),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل إحصاءات القصة: $e')),
      );
    }
  }

  void _setUrl() {
    final path = widget.stories[_index]['media_path'].toString();
    _url = Supabase.instance.client.storage.from('vedoro-stories').createSignedUrl(path, 600);
  }

  void _next() {
    if (_index + 1 >= widget.stories.length) { Navigator.pop(context); return; }
    setState(() { _index++; _setUrl(); });
    _recordView();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    final profile = story['profile'] as Map<String, dynamic>?;
    final isOwner = story['user_id'].toString() == Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(children: [
          VedoroAvatar(path: profile?['avatar_path']?.toString(), radius: 17),
          const SizedBox(width: 9),
          Text('@${profile?['username'] ?? 'user'}', style: const TextStyle(fontSize: 14)),
        ]),
      ),
      body: FutureBuilder<String>(
        future: _url,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل القصة'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: accent));
          return Stack(fit: StackFit.expand, children: [
            GestureDetector(onTap: _next,
              child: InteractiveViewer(child: Center(child: Image.network(snapshot.data!, fit: BoxFit.contain)))),
            Positioned(top: 12, left: 16, right: 16,
              child: LinearProgressIndicator(value: (_index + 1) / widget.stories.length,
                backgroundColor: Colors.white24, color: accent)),
            if ((story['caption'] ?? '').toString().isNotEmpty)
              Positioned(bottom: 112, left: 20, right: 20,
                child: IgnorePointer(child: Text(story['caption'].toString(), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
            if (isOwner)
              Positioned(left: 16, bottom: 112, child: Material(
                color: Colors.black.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: _showStoryInsights,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.visibility_outlined, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text('المشاهدات والتفاعلات', style: TextStyle(fontSize: 11)),
                    ]),
                  ),
                ),
              )),
            if (isOwner)
              Positioned(left: 12, right: 12, bottom: 18,
                child: Center(child: Text('قصتك • اسحب/اضغط للانتقال', style: TextStyle(color: Colors.white70, fontSize: 11)))),
            if (!isOwner)
            Positioned(left: 12, right: 12, bottom: 18,
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _reactions.map((emoji) => IconButton(
                    onPressed: _reacting ? null : () => _react(emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 27)),
                  )).toList()),
                Row(children: [
                  Expanded(child: TextField(controller: _reply,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _replyToStory(),
                    decoration: InputDecoration(
                      hintText: 'رد على القصة برسالة...',
                      filled: true, fillColor: Colors.black87,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ))),
                  const SizedBox(width: 6),
                  IconButton(onPressed: _replying ? null : _replyToStory,
                    icon: _replying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: accent)),
                ]),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}
class _ExplorePageState extends State<ExplorePage> {
  final _search = TextEditingController();
  Future<List<Map<String, dynamic>>>? _results;

  @override
  void initState() {
    super.initState();
    _results = _searchUsers('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String value) async {
    final client = Supabase.instance.client;
    final currentId = client.auth.currentUser?.id;
    var request = client.from('profiles').select('id, username, avatar_path');
    if (value.trim().isNotEmpty) {
      request = request.ilike('username', '%${value.trim()}%');
    }
    final rows = await request.limit(50);
    if (currentId == null) return [];
    final blockRows = await client.from('user_blocks')
        .select('blocker_id, blocked_id')
        .or('blocker_id.eq.$currentId,blocked_id.eq.$currentId');
    final blockedIds = <String>{};
    for (final block in blockRows) {
      final blocker = block['blocker_id'].toString();
      final blocked = block['blocked_id'].toString();
      blockedIds.add(blocker == currentId ? blocked : blocker);
    }
    return List<Map<String, dynamic>>.from(rows)
      .where((row) => row['id'] != currentId && !blockedIds.contains(row['id'].toString()))
      .take(30).toList();
  }

  void _onSearch(String value) {
    setState(() => _results = _searchUsers(value));
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('اكتشف', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const StoryTray(),
      const SizedBox(height: 10),
      TextField(
        controller: _search,
        onChanged: _onSearch,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'ابحث عن اسم المستخدم...',
          suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: () {
            _search.clear();
            _onSearch('');
          }),
          filled: true, fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 18),
      const Text('مستخدمو VEDORO', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _results,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر البحث: ${snapshot.error}', textAlign: TextAlign.center));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('ما لقينا حسابات مطابقة. جرّب اسم ثاني.', style: TextStyle(color: Colors.white54)));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
            itemBuilder: (context, index) {
              final item = users[index];
              final username = (item['username'] ?? 'user').toString();
              return ListTile(
                leading: VedoroAvatar(path: item['avatar_path']?.toString(), radius: 23),
                title: Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('عضو في VEDORO'),
                trailing: const Icon(Icons.verified_user_outlined, color: Colors.white38),
              );
            },
          );
        },
      )),
    ]),
  ));
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}
class _MessagesPageState extends State<MessagesPage> {
  late Future<List<Map<String, dynamic>>> _chats;
  @override
  void initState() { super.initState(); _chats = _loadChats(); }

  Future<List<Map<String, dynamic>>> _loadChats() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    final memberships = await client.from('conversation_members')
      .select('conversation_id').eq('user_id', uid);
    final ids = memberships.map((x) => x['conversation_id'] as String).toList();
    if (ids.isEmpty) return [];
    final messages = await client.from('messages')
      .select('conversation_id, body, sender_id, created_at')
      .inFilter('conversation_id', ids).order('created_at', ascending: false).limit(100);
    final latest = <String, Map<String, dynamic>>{};
    for (final row in messages) {
      latest.putIfAbsent(row['conversation_id'] as String, () => Map<String, dynamic>.from(row));
    }
    return latest.values.toList();
  }

  Future<void> _newChat() async {
    final client = Supabase.instance.client;
    final query = TextEditingController();
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF171720),
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('ابدأ محادثة جديدة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: query, autofocus: true, onChanged: (_) => refresh(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'اكتب اسم المستخدم')),
            const SizedBox(height: 8),
            SizedBox(height: 250, child: FutureBuilder<List<Map<String, dynamic>>>(
              future: client.from('profiles').select('id, username, avatar_path').ilike('username', '%${query.text.trim()}%').limit(20)
                .then((rows) => List<Map<String, dynamic>>.from(rows).where((r) => r['id'] != client.auth.currentUser!.id).toList()),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: accent));
                return ListView(children: (snap.data ?? []).map((u) => ListTile(
                  leading: VedoroAvatar(path: u['avatar_path']?.toString(), radius: 22),
                  title: Text('@${u['username']}'),
                  onTap: () => Navigator.pop(ctx, u),
                )).toList());
              },
            )),
          ]),
        ),
      )),
    );
    query.dispose();
    if (chosen == null || !mounted) return;
    try {
      final uid = client.auth.currentUser!.id;
      final conversation = await client.from('conversations')
        .insert({'created_by': uid, 'is_group': false}).select('id').single();
      final conversationId = conversation['id'] as String;
      await client.from('conversation_members').insert([
        {'conversation_id': conversationId, 'user_id': uid},
        {'conversation_id': conversationId, 'user_id': chosen['id']},
      ]);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
        conversationId: conversationId, title: '@${chosen['username']}',
      ))).then((_) { if (mounted) setState(() => _chats = _loadChats()); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر بدء المحادثة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 18, 16, 12), child: Row(children: [
      const Expanded(child: Text('الرسائل', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold))),
      IconButton(onPressed: _newChat, icon: const Icon(Icons.edit_square, color: accent), tooltip: 'محادثة جديدة'),
    ])),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
      future: _chats,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: accent));
        if (snap.hasError) return Center(child: Text('تعذر تحميل المحادثات: ${snap.error}'));
        final chats = snap.data ?? [];
        if (chats.isEmpty) return const Center(child: Text('ما عندك محادثات بعد. اضغط زر القلم لبدء محادثة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));
        return ListView.separated(
          itemCount: chats.length, separatorBuilder: (_, __) => const Divider(color: Colors.white12),
          itemBuilder: (context, i) {
            final item = chats[i];
            return ListTile(
              leading: const VedoroAvatar(radius: 23),
              title: const Text('محادثة VEDORO'),
              subtitle: Text(item['body'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                conversationId: item['conversation_id'].toString(), title: 'محادثة',
              ))).then((_) { if (mounted) setState(() => _chats = _loadChats()); }),
            );
          },
        );
      },
    )),
  ]));
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversationId, required this.title});
  final String conversationId;
  final String title;
  @override
  State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  late Future<List<Map<String, dynamic>>> _messages;
  bool _sending = false;
  bool _otherTyping = false;
  Map<String, dynamic>? _replyTo;
  Timer? _typingDebounce;
  Timer? _typingExpiry;
  RealtimeChannel? _channel;
  static const _reactionEmojis = ['❤️', '😂', '😮', '😢', '🔥', '👏'];
  @override
  void initState() {
    super.initState();
    _messages = _load();
    _channel = Supabase.instance.client.channel('chat-' + widget.conversationId)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.conversationId),
        callback: (_) { if (mounted) setState(() => _messages = _load()); },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_reactions',
        callback: (_) { if (mounted) setState(() => _messages = _load()); },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'chat_typing_status',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.conversationId),
        callback: (_) => _refreshTyping(),
      )..subscribe();
  }
  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    _publishTyping(false);
    _input.dispose();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }
  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from('messages').select('id, sender_id, body, created_at, read_at, message_type, media_path, media_mime, reply_to_message_id')
      .eq('conversation_id', widget.conversationId).order('created_at');
    final messages = List<Map<String, dynamic>>.from(rows);
    final unreadIds = messages.where((m) => m['sender_id'] != client.auth.currentUser!.id && m['read_at'] == null)
      .map((m) => m['id'].toString()).toList();
    if (unreadIds.isNotEmpty) {
      final readAt = DateTime.now().toUtc().toIso8601String();
      await client.from('messages').update({'read_at': readAt}).inFilter('id', unreadIds);
      for (final message in messages) {
        if (unreadIds.contains(message['id'].toString())) message['read_at'] = readAt;
      }
    }
    final ids = messages.map((m) => m['sender_id'].toString()).toSet().toList();
    if (ids.isNotEmpty) {
      final profiles = await client.from('profiles').select('id, username, avatar_path').inFilter('id', ids);
      final byId = {for (final p in profiles) p['id'].toString(): p};
      for (final message in messages) { message['sender_profile'] = byId[message['sender_id'].toString()]; }
    }
    final replyIds = messages.map((m) => m['reply_to_message_id']).where((v) => v != null).map((v) => v.toString()).toSet().toList();
    if (replyIds.isNotEmpty) {
      final replyRows = await client.from('messages').select('id,body,message_type').inFilter('id', replyIds);
      final replyMap = {for (final r in replyRows) r['id'].toString(): r};
      for (final message in messages) {
        final replyId = message['reply_to_message_id']?.toString();
        if (replyId != null) message['reply_message'] = replyMap[replyId];
      }
    }
    for (final message in messages) {
      final path = message['media_path']?.toString();
      if (path != null && path.isNotEmpty) {
        try {
          message['media_url'] = await client.storage.from('vedoro-chat-media').createSignedUrl(path, 3600);
        } catch (_) {
          message['media_url'] = null;
        }
      }
    }
    if (messages.isNotEmpty) {
      final messageIds = messages.map((m) => m['id'].toString()).toList();
      final reactionRows = await client.from('message_reactions')
          .select('message_id,user_id,emoji')
          .inFilter('message_id', messageIds);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final reaction in reactionRows) {
        grouped.putIfAbsent(reaction['message_id'].toString(), () => []).add(Map<String, dynamic>.from(reaction));
      }
      for (final message in messages) {
        message['reactions'] = grouped[message['id'].toString()] ?? <Map<String, dynamic>>[];
      }
    }
    return messages;
  }
  Future<void> _publishTyping(bool typing) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from('chat_typing_status').upsert({
        'conversation_id': widget.conversationId,
        'user_id': uid,
        'is_typing': typing,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }
  void _handleTyping(String value) {
    _typingDebounce?.cancel();
    _typingExpiry?.cancel();
    if (value.trim().isEmpty) {
      _publishTyping(false);
      return;
    }
    _typingDebounce = Timer(const Duration(milliseconds: 450), () => _publishTyping(true));
    _typingExpiry = Timer(const Duration(seconds: 3), () => _publishTyping(false));
  }
  Future<void> _refreshTyping() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await Supabase.instance.client.from('chat_typing_status')
          .select('user_id,is_typing,updated_at')
          .eq('conversation_id', widget.conversationId)
          .neq('user_id', uid);
      final now = DateTime.now().toUtc();
      final active = rows.any((r) {
        if (r['is_typing'] != true) return false;
        final updated = DateTime.tryParse(r['updated_at'].toString());
        return updated != null && now.difference(updated).inSeconds < 5;
      });
      if (mounted && active != _otherTyping) setState(() => _otherTyping = active);
    } catch (_) {}
  }
  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الرسالة؟'),
        content: const Text('سيتم حذف الرسالة من المحادثة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.from('messages').delete().eq('id', messageId);
      if (mounted) setState(() => _messages = _load());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف الرسالة: $e')),
      );
    }
  }
  void _startReply(Map<String, dynamic> message) {
    setState(() => _replyTo = message);
  }
  Future<void> _toggleReaction(String messageId, String emoji) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final existing = await client.from('message_reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', uid)
          .eq('emoji', emoji)
          .maybeSingle();
      if (existing != null) {
        await client.from('message_reactions').delete().eq('id', existing['id']);
      } else {
        await client.from('message_reactions').insert({
          'message_id': messageId, 'user_id': uid, 'emoji': emoji,
        });
      }
      if (mounted) setState(() => _messages = _load());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إضافة التفاعل: $e')),
      );
    }
  }
  Future<void> _showReactions(String messageId, {required bool canDelete}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171720),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _reactionEmojis.map((emoji) => InkWell(
              onTap: () { Navigator.pop(ctx); _toggleReaction(messageId, emoji); },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            )).toList(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.reply, color: accent),
            title: const Text('الرد على الرسالة'),
            onTap: () {
              Navigator.pop(ctx);
              _load().then((rows) {
                for (final found in rows) {
                  if (found['id'].toString() == messageId && mounted) {
                    _startReply(found);
                    break;
                  }
                }
              });
            },
          ),
          if (canDelete) ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('حذف الرسالة'),
            onTap: () { Navigator.pop(ctx); _deleteMessage(messageId); },
          ),
        ]),
      )),
    );
  }
  Future<void> _pickAndSendMedia(bool video) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _sending) return;
    try {
      final picker = ImagePicker();
      final picked = video
          ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2))
          : await picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final limit = video ? 50 * 1024 * 1024 : 10 * 1024 * 1024;
      if (bytes.length > limit) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(video ? 'حجم الفيديو يجب ألا يتجاوز 50 ميغابايت' : 'حجم الصورة يجب ألا يتجاوز 10 ميغابايت'),
        ));
        return;
      }
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : (video ? 'mp4' : 'jpg');
      const imageTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'heic': 'image/heic'};
      const videoTypes = {'mp4': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm'};
      final mime = (video ? videoTypes : imageTypes)[ext];
      if (mime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صيغة الملف غير مدعومة')));
        return;
      }
      setState(() => _sending = true);
      final path = '${widget.conversationId}/${user.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage.from('vedoro-chat-media').uploadBinary(
        path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'body': video ? '🎬 فيديو' : '📷 صورة',
        'message_type': video ? 'video' : 'image',
        'media_path': path,
        'media_mime': mime,
      });
      if (mounted) setState(() => _messages = _load());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الملف: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
  Future<void> _showMediaOptions() async {
    await showModalBottomSheet<void>(
      context: context, backgroundColor: const Color(0xFF171720),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.image_outlined, color: accent), title: const Text('إرسال صورة'),
          onTap: () { Navigator.pop(ctx); _pickAndSendMedia(false); }),
        ListTile(leading: const Icon(Icons.video_library_outlined, color: accent), title: const Text('إرسال فيديو'),
          onTap: () { Navigator.pop(ctx); _pickAndSendMedia(true); }),
      ])),
    );
  }
  Future<void> _openVideo(String url) async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatVideoPage(url: url)));
  }
  Future<void> _blockUser() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final members = await client.from('conversation_members')
        .select('user_id').eq('conversation_id', widget.conversationId);
      final other = members.map((m) => m['user_id'].toString()).firstWhere((id) => id != uid, orElse: () => '');
      if (other.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ما لقينا الطرف الآخر بالمحادثة')));
        return;
      }
      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('حظر هذا الحساب؟'),
        content: const Text('بعد الحظر لن يتمكن هذا الحساب من إرسال رسائل إليك، ولن تتمكن أنت أيضاً من مراسلته.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حظر')),
        ],
      ));
      if (confirmed != true || !mounted) return;
      await client.from('user_blocks').insert({'blocker_id': uid, 'blocked_id': other});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حظر الحساب')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حظر الحساب: $e')));
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    final user = Supabase.instance.client.auth.currentUser;
    if (body.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId, 'sender_id': user.id, 'body': body,
        if (_replyTo != null) 'reply_to_message_id': _replyTo!['id'],
      });
      _input.clear();
      _publishTyping(false);
      if (mounted) setState(() { _replyTo = null; _messages = _load(); });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    } finally { if (mounted) setState(() => _sending = false); }
  }
  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(tooltip: 'تحديث المحادثة', onPressed: () => setState(() => _messages = _load()), icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'حظر الحساب', onPressed: _blockUser, icon: const Icon(Icons.block, color: Colors.redAccent)),
        ],
      ),
      body: Column(children: [
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _messages,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: accent));
            final rows = snap.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(14), itemCount: rows.length,
              itemBuilder: (context, i) {
                final mine = rows[i]['sender_id'] == uid;
                final profile = rows[i]['sender_profile'] as Map<String, dynamic>?;
                return Padding(padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (!mine) ...[VedoroAvatar(path: profile?['avatar_path']?.toString(), radius: 15), const SizedBox(width: 7)],
                    Flexible(child: GestureDetector(
                      onLongPress: () => _showReactions(rows[i]['id'].toString(), canDelete: mine),
                      child: Container(padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(color: mine ? accent.withValues(alpha: .35) : Colors.white12, borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!mine) Text('@${profile?['username'] ?? 'user'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        if (rows[i]['reply_message'] != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Text('↪ ${rows[i]['reply_message']['body'] ?? 'مرفق'}',
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          ),
                        if (rows[i]['message_type'] == 'image' && rows[i]['media_url'] != null)
                          GestureDetector(
                            onTap: () => showDialog<void>(context: context, builder: (ctx) => Dialog(
                              backgroundColor: Colors.black,
                              child: InteractiveViewer(child: Image.network(rows[i]['media_url'].toString(), fit: BoxFit.contain)),
                            )),
                            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(
                              rows[i]['media_url'].toString(), width: 220, height: 190, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48),
                            )),
                          ),
                        if (rows[i]['message_type'] == 'video')
                          InkWell(
                            onTap: rows[i]['media_url'] == null ? null : () => _openVideo(rows[i]['media_url'].toString()),
                            child: Container(width: 220, height: 130, decoration: BoxDecoration(
                              color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.play_circle_fill, size: 52, color: accent),
                                Text('تشغيل الفيديو'),
                              ]),
                            ),
                          ),
                        if ((rows[i]['message_type'] ?? 'text') == 'text')
                          Text(rows[i]['body'].toString()),
                        if (mine) Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            rows[i]['read_at'] == null ? 'تم الإرسال' : 'تمت القراءة',
                            style: TextStyle(fontSize: 10, color: rows[i]['read_at'] == null ? Colors.white54 : const Color(0xFFBFA4FF)),
                          ),
                        ),
                        if ((rows[i]['reactions'] as List? ?? []).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: (() {
                                final reactions = rows[i]['reactions'] as List;
                                final counts = <String, int>{};
                                for (final reaction in reactions) {
                                  final emoji = reaction['emoji'].toString();
                                  counts[emoji] = (counts[emoji] ?? 0) + 1;
                                }
                                return counts.entries.map((entry) => InkWell(
                                  onTap: () => _toggleReaction(rows[i]['id'].toString(), entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: reactions.any((r) => r['emoji'] == entry.key && r['user_id'] == uid)
                                          ? accent.withValues(alpha: .3) : Colors.black26,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text('${entry.key} ${entry.value}', style: const TextStyle(fontSize: 12)),
                                  ),
                                )).toList();
                              })(),
                            ),
                          ),
                      ]))),
                    )),
                    if (mine) ...[const SizedBox(width: 7), VedoroAvatar(path: profile?['avatar_path']?.toString(), radius: 15)],
                  ]));
              },
            );
          },
        )),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 12), child: Row(children: [
          IconButton(onPressed: _sending ? null : _showMediaOptions, icon: const Icon(Icons.add_circle_outline, color: accent)),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_otherTyping) const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 12, bottom: 4), child: Text('يكتب الآن...', style: TextStyle(color: accent, fontSize: 11)))),
            if (_replyTo != null) Container(
              margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(child: Text('الرد على: ${_replyTo!['body'] ?? 'مرفق'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                IconButton(onPressed: () => setState(() => _replyTo = null), icon: const Icon(Icons.close, size: 16)),
              ]),
            ),
            TextField(controller: _input, textInputAction: TextInputAction.send,
            onChanged: _handleTyping,
            onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'اكتب رسالة...', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
          ])),
          IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send, color: accent)),
        ]))),
      ]),
    );
  }
}


class ChatVideoPage extends StatefulWidget {
  const ChatVideoPage({super.key, required this.url});
  final String url;
  @override
  State<ChatVideoPage> createState() => _ChatVideoPageState();
}
class _ChatVideoPageState extends State<ChatVideoPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialized;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialized = _controller.initialize().then((_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مشاهدة الفيديو')),
    body: Center(child: FutureBuilder<void>(
      future: _initialized,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('تعذر تشغيل الفيديو');
        if (snapshot.connectionState != ConnectionState.done) return const CircularProgressIndicator(color: accent);
        return AspectRatio(aspectRatio: _controller.value.aspectRatio, child: Stack(
          alignment: Alignment.center, children: [
            VideoPlayer(_controller),
            IconButton(iconSize: 64, color: Colors.white, icon: Icon(_controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: () { setState(() { _controller.value.isPlaying ? _controller.pause() : _controller.play(); }); }),
          ],
        ));
      },
    )),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, int>> _stats;
  late Future<Map<String, dynamic>> _profile;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _stats = _loadStats();
    _profile = _loadProfile();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser!;
    final row = await Supabase.instance.client.from('profiles')
      .select('username, display_name, bio, avatar_path')
      .eq('id', user.id).maybeSingle();
    return row ?? {
      'username': user.userMetadata?['username'] ?? 'user',
      'display_name': user.userMetadata?['display_name'] ?? 'عضو جديد',
      'bio': '',
    };
  }


  Future<void> _changeAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _editing) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حجم الصورة يجب أن يكون أقل من 5 ميغابايت')),
        );
        return;
      }
      final ext = picked.path.split('.').last.toLowerCase();
      const types = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
      final mime = types[ext];
      if (mime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الصيغ المدعومة: JPG و PNG و WEBP')),
        );
        return;
      }
      setState(() => _editing = true);
      final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
      final storage = Supabase.instance.client.storage.from('vedoro-avatars');
      await storage.upload(
        path,
        file,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      await Supabase.instance.client.from('profiles').update({
        'avatar_path': path,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      setState(() => _profile = _loadProfile());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث صورتك الشخصية 💜')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير الصورة: $e')),
      );
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _editProfile(Map<String, dynamic> current) async {
    final username = TextEditingController(text: current['username']?.toString() ?? '');
    final displayName = TextEditingController(text: current['display_name']?.toString() ?? '');
    final bio = TextEditingController(text: current['bio']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    final save = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF171720),
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
          child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تعديل الملف الشخصي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextFormField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم'), validator: (v) => (v == null || v.trim().length < 3) ? 'اكتب 3 أحرف على الأقل' : null),
            TextFormField(controller: displayName, decoration: const InputDecoration(labelText: 'الاسم الظاهر'), validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null),
            TextFormField(controller: bio, maxLength: 160, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة عنك')),
            const SizedBox(height: 12),
            FilledButton(onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            }, style: FilledButton.styleFrom(backgroundColor: accent, minimumSize: const Size.fromHeight(46)), child: const Text('حفظ التغييرات')),
          ])),
        ),
      )),
    );
    if (save == true) {
      setState(() => _editing = true);
      try {
        await Supabase.instance.client.from('profiles').update({
          'username': username.text.trim(),
          'display_name': displayName.text.trim(),
          'bio': bio.text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', Supabase.instance.client.auth.currentUser!.id);
        if (mounted) {
          setState(() => _profile = _loadProfile());
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث ملفك الشخصي 💜')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الملف: $e')));
      } finally {
        if (mounted) setState(() => _editing = false);
      }
    }
    username.dispose(); displayName.dispose(); bio.dispose();
  }

  Future<Map<String, int>> _loadStats() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return {'videos': 0, 'followers': 0, 'following': 0};
    final results = await Future.wait([
      client.from('posts').select('id').eq('author_id', user.id).eq('moderation_status', 'approved'),
      client.from('follows').select('follower_id').eq('followed_id', user.id),
      client.from('follows').select('followed_id').eq('follower_id', user.id),
    ]);
    return {
      'videos': (results[0] as List).length,
      'followers': (results[1] as List).length,
      'following': (results[2] as List).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return SafeArea(child: Column(children: [
      const SizedBox(height: 24),
      FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          final path = snapshot.data?['avatar_path']?.toString();
          final url = path == null || path.isEmpty
              ? null
              : Supabase.instance.client.storage.from('vedoro-avatars').getPublicUrl(path);
          return Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: accent,
                backgroundImage: url == null ? null : NetworkImage(url),
                child: url == null ? const Icon(Icons.person, size: 48, color: Colors.white) : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: accent,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'تغيير الصورة الشخصية',
                    onPressed: _editing ? null : _changeAvatar,
                    icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          final p = snapshot.data ?? {};
          final username = (p['username'] ?? 'user').toString();
          final displayName = (p['display_name'] ?? username).toString();
          final bio = (p['bio'] ?? '').toString();
          return Column(children: [
            Text('@$username', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            Text(displayName, style: const TextStyle(color: Colors.white70)),
            if (bio.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 0), child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _editing ? null : () => _editProfile(p),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('تعديل الملف الشخصي'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
              icon: const Icon(Icons.notifications_none, size: 18),
              label: const Text('الإشعارات'),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedAccountsPage())),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('الحسابات المحظورة'),
            ),
          ]);
        },
      ),
      if (user?.email != null)
        Text(user!.email!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, int>>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.data ?? {'videos': 0, 'followers': 0, 'following': 0};
          return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ProfileStat(value: '${stats['videos']}', label: 'فيديو'),
            _ProfileStat(value: '${stats['followers']}', label: 'متابعون'),
            _ProfileStat(value: '${stats['following']}', label: 'يتابع'),
          ]);
        },
      ),
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
      Expanded(child: DefaultTabController(
        length: 2,
        child: Column(children: [
          const TabBar(tabs: [Tab(icon: Icon(Icons.grid_on), text: 'فيديوهاتي'), Tab(icon: Icon(Icons.bookmarks_outlined), text: 'المحفوظات')]),
          Expanded(child: TabBarView(children: [
            _ProfilePostList(savedOnly: false),
            _ProfilePostList(savedOnly: true),
          ])),
        ]),
      )),
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
class BlockedAccountsPage extends StatefulWidget {
  const BlockedAccountsPage({super.key});
  @override
  State<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends State<BlockedAccountsPage> {
  late Future<List<Map<String, dynamic>>> _blocked;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _blocked = _loadBlocked();
  }

  Future<List<Map<String, dynamic>>> _loadBlocked() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    final rows = await client.from('user_blocks')
        .select('blocked_id, created_at')
        .eq('blocker_id', uid)
        .order('created_at', ascending: false);
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['blocked_id'].toString()).toList();
    final profiles = await client.from('profiles')
        .select('id, username, display_name, avatar_path')
        .inFilter('id', ids);
    final byId = {for (final p in profiles) p['id'].toString(): p};
    return rows.map((r) {
      final profile = byId[r['blocked_id'].toString()];
      return <String, dynamic>{
        'id': r['blocked_id'].toString(),
        'created_at': r['created_at'],
        'profile': profile,
      };
    }).toList();
  }

  Future<void> _unblock(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    if (_busy.contains(id)) return;
    final profile = item['profile'] as Map<String, dynamic>?;
    final name = (profile?['username'] ?? 'هذا الحساب').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الحظر؟'),
        content: Text('تريد ترفع الحظر عن @$name؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء الحظر')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await Supabase.instance.client.from('user_blocks')
          .delete()
          .eq('blocker_id', Supabase.instance.client.auth.currentUser!.id)
          .eq('blocked_id', id);
      if (!mounted) return;
      setState(() => _blocked = _loadBlocked());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الحظر')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إلغاء الحظر: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('الحسابات المحظورة'),
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => setState(() => _blocked = _loadBlocked()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _blocked,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: accent));
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('تعذر تحميل الحسابات المحظورة: ${snapshot.error}', textAlign: TextAlign.center),
          ));
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return const Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 56, color: accent),
              SizedBox(height: 12),
              Text('ما عندك حسابات محظورة'),
              SizedBox(height: 6),
              Text('الحسابات التي تحظرها راح تظهر هنا', style: TextStyle(color: Colors.white54)),
            ],
          ));
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, index) {
            final item = rows[index];
            final profile = item['profile'] as Map<String, dynamic>?;
            final username = (profile?['username'] ?? 'user').toString();
            final displayName = (profile?['display_name'] ?? username).toString();
            return ListTile(
              leading: VedoroAvatar(path: profile?['avatar_path']?.toString(), radius: 22),
              title: Text('@$username'),
              subtitle: Text(displayName),
              trailing: TextButton(
                onPressed: _busy.contains(item['id']) ? null : () => _unblock(item),
                child: _busy.contains(item['id'])
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إلغاء الحظر'),
              ),
            );
          },
        );
      },
    ),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Stream<List<Map<String, dynamic>>> _notifications;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    _notifications = client.from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', uid)
        .order('created_at', ascending: false);
  }

  IconData _icon(String type) => switch (type) {
    'follow' => Icons.person_add_alt_1,
    'like' => Icons.favorite,
    'comment' => Icons.mode_comment_outlined,
    _ => Icons.notifications,
  };

  Future<void> _markRead(String id) async {
    await Supabase.instance.client.from('notifications')
        .update({'is_read': true}).eq('id', id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإشعارات')),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notifications,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل الإشعارات: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: accent));
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('ما عندك إشعارات حالياً 💜'));
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, index) {
            final row = rows[index];
            final type = (row['type'] ?? '').toString();
            final read = row['is_read'] == true;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: accent.withValues(alpha: .18),
                child: Icon(_icon(type), color: accent),
              ),
              title: Text(row['message']?.toString() ?? 'لديك إشعار جديد'),
              subtitle: Text(row['created_at']?.toString().replaceFirst('T', ' ').split('.').first ?? ''),
              trailing: read ? null : Container(
                width: 9, height: 9,
                decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              tileColor: read ? null : accent.withValues(alpha: .06),
              onTap: () async {
                await _markRead(row['id'].toString());
                if (row['post_id'] != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت قراءة الإشعار')),
                  );
                }
              },
            );
          },
        );
      },
    ),
  );
}

class _ProfilePostList extends StatelessWidget {
  const _ProfilePostList({required this.savedOnly});
  final bool savedOnly;

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    if (savedOnly) {
      final saved = await client.from('saved_posts').select('post_id, posts(id, caption, media_path, author_id)')
        .eq('user_id', uid).order('created_at', ascending: false);
      return saved.map((x) => Map<String, dynamic>.from(x['posts'] as Map)).toList();
    }
    final rows = await client.from('posts').select('id, caption, media_path, author_id')
      .eq('author_id', uid).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _load(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: accent));
      if (snap.hasError) return Center(child: Text('تعذر تحميل القائمة: ${snap.error}'));
      final rows = snap.data ?? [];
      if (rows.isEmpty) return Center(child: Text(savedOnly ? 'ما عندك فيديوهات محفوظة بعد' : 'ما نشرت فيديوهات بعد', style: const TextStyle(color: Colors.white54)));
      return ListView.separated(
        padding: const EdgeInsets.all(12), itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12),
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.play_circle_outline, color: accent, size: 34),
          title: Text((rows[i]['caption'] ?? 'فيديو بدون وصف').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(savedOnly ? 'ضمن المحفوظات' : 'منشورك'),
        ),
      );
    },
  );
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