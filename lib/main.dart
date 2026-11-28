import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class DownloadItem {
  DownloadItem({
    required this.name,
    required this.path,
    this.progress = 0,
    this.done = false,
    this.error,
  });

  final String name;
  final String path;
  double progress;
  bool done;
  String? error;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int page = 0;
  final controller = TextEditingController();
  final List<DownloadItem> downloads = [];
  final List<FileSystemEntity> libraryFiles = [];
  bool loadingLibrary = false;
  bool startingDownload = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<Directory> _downloadDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/VEDORO');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _loadLibrary() async {
    if (mounted) setState(() => loadingLibrary = true);
    try {
      final directory = await _downloadDirectory();
      final files = directory.listSync().whereType<File>().toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      if (mounted) setState(() {
        libraryFiles
          ..clear()
          ..addAll(files);
      });
    } catch (_) {
      // The library remains empty if storage is temporarily unavailable.
    } finally {
      if (mounted) setState(() => loadingLibrary = false);
    }
  }

  String _safeFileName(String raw) {
    var name = Uri.decodeComponent(raw).trim();
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    name = name.replaceAll(RegExp(r'\s+'), '_');
    if (name.isEmpty || name == '.' || name == '..') {
      name = 'vedoro_${DateTime.now().millisecondsSinceEpoch}.bin';
    }
    return name;
  }

  Future<void> _startDownload() async {
    final raw = controller.text.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      _message('أدخل رابطاً صحيحاً يبدأ بـ http أو https');
      return;
    }
    if (startingDownload) return;

    setState(() => startingDownload = true);
    final item = DownloadItem(name: 'جاري تجهيز الملف...', path: '');
    setState(() => downloads.insert(0, item));

    try {
      final directory = await _downloadDirectory();
      var name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (name.isEmpty || !name.contains('.')) {
        name = 'vedoro_${DateTime.now().millisecondsSinceEpoch}.bin';
      }
      name = _safeFileName(name);
      var target = '${directory.path}/$name';
      if (await File(target).exists()) {
        final dot = name.lastIndexOf('.');
        final stem = dot > 0 ? name.substring(0, dot) : name;
        final ext = dot > 0 ? name.substring(dot) : '';
        name = '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext';
        target = '${directory.path}/$name';
      }

      item.path = target;
      item.error = null;
      item.progress = 0;
      item.done = false;
      // Only direct HTTP/HTTPS file URLs are supported in this first release.
      await Dio().download(
        uri.toString(),
        target,
        deleteOnError: true,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
          headers: {'User-Agent': 'VEDORO/1.0'},
        ),
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            item.name = name;
            item.progress = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        item.name = name;
        item.progress = 1;
        item.done = true;
      });
      controller.clear();
      await _loadLibrary();
      _message('اكتمل التنزيل بنجاح');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        item.error = e.response?.statusCode != null
            ? 'تعذر التنزيل: HTTP ${e.response!.statusCode}'
            : 'فشل الاتصال أو أن الرابط ليس ملفاً مباشراً';
        item.name = 'فشل التنزيل';
      });
      _message(item.error!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item.error = 'حدث خطأ أثناء حفظ الملف';
        item.name = 'فشل التنزيل';
      });
      _message(item.error!);
    } finally {
      if (mounted) setState(() => startingDownload = false);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openFile(FileSystemEntity entity) async {
    if (entity is File) {
      await OpenFilex.open(entity.path);
    }
  }

  Future<void> _deleteFile(FileSystemEntity entity) async {
    await entity.delete();
    await _loadLibrary();
    _message('تم حذف الملف');
  }

  Widget _home() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 12),
      const Text('أهلاً بك في', style: TextStyle(color: Colors.white70, fontSize: 18)),
      const Text('VEDORO', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: purple)),
      const Text('عالم الفيديو والصوت بين يديك'),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF512B91), Color(0xFF201A38)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.download_for_offline, size: 45),
            const SizedBox(height: 12),
            const Text('تنزيل الوسائط', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('الصق رابط ملف مباشر بصيغة HTTP أو HTTPS'),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://example.com/video.mp4',
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                onPressed: startingDownload ? null : _startDownload,
                icon: startingDownload
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(startingDownload ? 'جارٍ التنزيل...' : 'ابدأ التنزيل'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 25),
      const Text('خدمات التطبيق', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      _feature(Icons.video_library, 'الفيديوهات', 'تشغيل وإدارة الفيديو'),
      _feature(Icons.music_note, 'الصوتيات', 'مكتبة الملفات الصوتية'),
      _feature(Icons.folder, 'ملفاتي', 'ملفاتك المحفوظة'),
      const SizedBox(height: 8),
      const Text('ملاحظة: تنزيل الروابط المباشرة مدعوم حالياً. روابط منصات التواصل تحتاج تكامل تحليل منفصل.', style: TextStyle(color: Colors.white54, fontSize: 12)),
    ],
  );

  Widget _feature(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17)),
    child: Row(children: [
      Icon(icon, color: purple, size: 30),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(subtitle, style: const TextStyle(color: Colors.white54)),
      ])),
      const Icon(Icons.chevron_right),
    ]),
  );

  Widget _downloadsPage() {
    if (downloads.isEmpty) {
      return _empty(Icons.downloading, 'لا توجد تنزيلات', 'التنزيلات التي تبدأها ستظهر هنا');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: downloads.length,
      itemBuilder: (context, index) {
        final item = downloads[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(item.done ? Icons.check_circle : item.error != null ? Icons.error : Icons.downloading, color: purple),
              const SizedBox(width: 10),
              Expanded(child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
              if (item.done) const Text('مكتمل', style: TextStyle(color: Colors.greenAccent)),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: item.progress, color: purple, backgroundColor: Colors.white12),
            if (item.error != null) ...[
              const SizedBox(height: 8),
              Text(item.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            if (item.done)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => OpenFilex.open(item.path),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('فتح الملف'),
                ),
              ),
          ]),
        );
      },
    );
  }

  Widget _libraryPage() {
    if (loadingLibrary) return const Center(child: CircularProgressIndicator(color: purple));
    if (libraryFiles.isEmpty) return _empty(Icons.video_library, 'مكتبتك فارغة', 'الملفات التي تنزّلها ستظهر هنا');
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      color: purple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: libraryFiles.length,
        itemBuilder: (context, index) {
          final file = libraryFiles[index];
          final name = file.path.split('/').last;
          final size = file is File ? file.lengthSync() : 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0x3325C6DA), child: Icon(Icons.insert_drive_file, color: purple)),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_formatBytes(size)),
              onTap: () => _openFile(file),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'open') _openFile(file);
                  if (value == 'delete') _deleteFile(file);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('فتح')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _empty(IconData icon, String title, String subtitle) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: purple, size: 75),
      const SizedBox(height: 15),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(color: Colors.white54)),
    ]),
  );

  Widget _about() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          const Icon(Icons.play_circle_fill, color: purple, size: 85),
          const SizedBox(height: 12),
          const Text('VEDORO', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: purple)),
          const Text('Your world. One app.', style: TextStyle(color: Colors.white54)),
          const Divider(height: 40),
          const Text('حول التطبيق', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('تم تطوير البرنامج بواسطة', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 8),
          const Text('أبو عوض الحجي', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          const Text('تابع المطور على إنستغرام'),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final uri = Uri.parse('https://www.instagram.com/h6v_l/');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: purple.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.camera_alt, color: purple),
                SizedBox(width: 10),
                Text('@h6v_l', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.open_in_new, color: purple),
              ]),
            ),
          ),
          const SizedBox(height: 30),
          const Text('الإصدار 1.1.0'),
          const SizedBox(height: 12),
          const Text('جميع الحقوق محفوظة © أبو عوض الحجي', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final titles = ['VEDORO', 'التنزيلات', 'مكتبتي', 'حول التطبيق'];
    final bodies = [_home(), _downloadsPage(), _libraryPage(), _about()];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        centerTitle: true,
        title: Text(titles[page], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: bodies[page],
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel,
        indicatorColor: purple.withValues(alpha: 0.25),
        selectedIndex: page,
        onDestinationSelected: (i) {
          setState(() => page = i);
          if (i == 2) _loadLibrary();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.download_outlined), label: 'التنزيلات'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'مكتبتي'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'حول'),
        ],
      ),
    );
  }
}
