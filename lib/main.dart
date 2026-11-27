import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const VedoroApp());

const purple = Color(0xFF925CFF);
const bg = Color(0xFF0D0D18);
const panel = Color(0xFF1A1A2B);

class VedoroApp extends StatelessWidget {
  const VedoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VEDORO',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int page = 0;
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget home() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 15),
      const Text('أهلاً بك في',
          style: TextStyle(color: Colors.white70, fontSize: 18)),
      const Text('VEDORO',
          style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold,
              color: purple)),
      const Text('عالم الفيديو والصوت بين يديك'),
      const SizedBox(height: 30),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF512B91), Color(0xFF201A38)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.download_for_offline, size: 45),
            const SizedBox(height: 12),
            const Text('تنزيل الوسائط',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('الصق رابط الفيديو أو الملف المباشر'),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'https://example.com/video',
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.link, color: purple),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(controller.text.trim().isEmpty
                        ? 'أدخل الرابط أولاً'
                        : 'سيتم تفعيل تحليل الروابط في المرحلة القادمة'),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('تحليل الرابط'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 25),
      const Text('خدمات التطبيق',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      feature(Icons.video_library, 'الفيديوهات', 'تشغيل وإدارة الفيديو'),
      feature(Icons.music_note, 'الصوتيات', 'مكتبة الملفات الصوتية'),
      feature(Icons.folder, 'ملفاتي', 'ملفاتك المحفوظة'),
    ],
  );

  Widget feature(IconData icon, String title, String subtitle) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(children: [
          Icon(icon, color: purple, size: 30),
          const SizedBox(width: 15),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white54)),
            ],
          )),
          const Icon(Icons.chevron_right),
        ]),
      );

  Widget emptyPage(IconData icon, String title, String subtitle) =>
      Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: purple, size: 75),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
        ],
      ));

  Widget about() => Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: [
        const Icon(Icons.play_circle_fill, color: purple, size: 85),
        const SizedBox(height: 12),
        const Text('VEDORO', style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold, color: purple)),
        const Text('Your world. One app.',
            style: TextStyle(color: Colors.white54)),
        const Divider(height: 40),
        const Text('حول التطبيق',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const Text('تم تطوير البرنامج بواسطة',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 8),
        const Text('أبو عوض الحجي',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 25),
        const Text('تابع المطور على إنستغرام'),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final uri = Uri.parse('https://www.instagram.com/h6v_l/');
            await launchUrl(uri,
                mode: LaunchMode.externalApplication);
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, color: purple),
                SizedBox(width: 10),
                Text('@h6v_l', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.open_in_new, color: purple),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Text('الإصدار 1.0.0'),
        const SizedBox(height: 12),
        const Text('جميع الحقوق محفوظة © أبو عوض الحجي',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    ),
  ));

  @override
  Widget build(BuildContext context) {
    final widgets = [
      home(),
      emptyPage(Icons.downloading, 'التنزيلات', 'ستظهر تنزيلاتك هنا'),
      emptyPage(Icons.video_library, 'مكتبتي', 'ملفاتك المحفوظة'),
      about(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        centerTitle: true,
        title: Text(
          ['VEDORO', 'التنزيلات', 'مكتبتي', 'حول التطبيق'][page],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: widgets[page],
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel,
        indicatorColor: purple.withValues(alpha: 0.25),
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'الرئيسية'),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            label: 'التنزيلات'),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            label: 'مكتبتي'),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: 'حول'),
        ],
      ),
    );
  }
}
