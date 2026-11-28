import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const VedoroApp());

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
    home: const MainScreen(),
  );
}

class DemoVideo {
  const DemoVideo({required this.url, required this.user, required this.caption, required this.music, required this.likes});
  final String url;
  final String user;
  final String caption;
  final String music;
  final String likes;
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
      backgroundColor: const Color(0xFF191922),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.video_call_rounded, size: 48, color: accent),
            const SizedBox(height: 12),
            const Text('انشر فيديوك على VEDORO', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('ميزة اختيار الفيديو ورفعه من الهاتف قيد التطوير بالمرحلة القادمة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedScreen(onPageChanged: (i) => activeVideo = i),
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

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.onPageChanged});
  final ValueChanged<int> onPageChanged;
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int current = 0;
  @override
  Widget build(BuildContext context) => Stack(children: [
    PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: demoVideos.length,
      onPageChanged: (index) {
        setState(() => current = index);
        widget.onPageChanged(index);
      },
      itemBuilder: (context, index) => VideoFeedItem(
        key: ValueKey(index), video: demoVideos[index], active: current == index,
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
  bool liked = false;
  bool following = false;
  bool showControls = false;
  bool failed = false;
  bool muted = false;
  final List<String> comments = [];

  @override
  void initState() {
    super.initState();
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

  void showComments() {
    final input = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171720),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: 430,
            child: Column(children: [
              const SizedBox(height: 18),
              Text('التعليقات ${comments.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white12),
              Expanded(child: comments.isEmpty
                ? const Center(child: Text('كن أول من يعلّق على هذا الفيديو', style: TextStyle(color: Colors.white54)))
                : ListView.builder(itemCount: comments.length, itemBuilder: (_, i) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(comments[i])))),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                child: Row(children: [
                  Expanded(child: TextField(controller: input, textInputAction: TextInputAction.send, onSubmitted: (_) {
                    final value = input.text.trim();
                    if (value.isNotEmpty) { setState(() => comments.add(value)); input.clear(); refreshSheet(() {}); }
                  }, decoration: InputDecoration(hintText: 'اكتب تعليقاً...', filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
                  IconButton(onPressed: () {
                    final value = input.text.trim();
                    if (value.isNotEmpty) { setState(() => comments.add(value)); input.clear(); refreshSheet(() {}); }
                  }, icon: const Icon(Icons.send, color: accent)),
                ]),
              ),
            ]),
          ),
        ),
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
            _ActionButton(icon: liked ? Icons.favorite : Icons.favorite_border, label: liked ? 'أعجبني' : widget.video.likes, color: liked ? Colors.pinkAccent : Colors.white, onTap: () => setState(() => liked = !liked)),
            const SizedBox(height: 20),
            _ActionButton(icon: Icons.mode_comment_outlined, label: 'تعليق', onTap: showComments),
            const SizedBox(height: 20),
            _ActionButton(icon: Icons.share_outlined, label: 'مشاركة', onTap: () async { await Clipboard.setData(ClipboardData(text: widget.video.url)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط الفيديو'))); }),
            const SizedBox(height: 20),
            _ActionButton(icon: muted ? Icons.volume_off : Icons.music_note, label: muted ? 'صامت' : 'الصوت', onTap: () async { setState(() => muted = !muted); if (controller?.value.isInitialized == true) await controller!.setVolume(muted ? 0 : 1); }),
          ]),
        ),
        Positioned(
          left: 16, right: 86, bottom: 28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(widget.video.user, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() => following = !following),
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
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    const SizedBox(height: 34),
    const CircleAvatar(radius: 46, backgroundColor: accent, child: Icon(Icons.person, size: 48, color: Colors.white)),
    const SizedBox(height: 12),
    const Text('@vedoro_user', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
    const Text('عضو جديد في VEDORO', style: TextStyle(color: Colors.white54)),
    const SizedBox(height: 24),
    const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _ProfileStat(value: '0', label: 'فيديو'),
      _ProfileStat(value: '0', label: 'متابعون'),
      _ProfileStat(value: '0', label: 'يتابع'),
    ]),
    const Divider(height: 34, color: Colors.white12),
    const Expanded(child: Center(child: Text('سجّل الدخول حتى تنشئ ملفك وتنشر فيديوهاتك.', style: TextStyle(color: Colors.white54)))),
  ]));
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
