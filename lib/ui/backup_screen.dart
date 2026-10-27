import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../domain/backup.dart';
import '../domain/backup_service.dart';
import '../domain/sample_data.dart';
import 'ui_helpers.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.state});

  final AppState state;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final BackupService _service = BackupService(widget.state.db);
  bool _busy = false;

  String _stamp() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${t(n.month)}-${t(n.day)}_${t(n.hour)}${t(n.minute)}';
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await _service.exportJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/family_tree_backup_${_stamp()}.json');
      await file.writeAsString(json, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'نسخة احتياطية - شجرة عائلتي',
      );
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّر التصدير: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showErrors(List<String> errors) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعذّر قراءة النسخة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [for (final e in errors) Text('• $e')],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      if (mounted) showMessage(context, 'تعذّر قراءة الملف');
      return;
    }
    BackupData data;
    try {
      var text = utf8.decode(bytes);
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      data = BackupCodec.decode(text);
    } on BackupException catch (e) {
      await _showErrors(e.errors);
      return;
    } on FormatException {
      await _showErrors(['الملف ليس نصاً صالحاً']);
      return;
    }
    await _confirmAndRestore(data);
  }

  Future<void> _loadSample() => _confirmAndRestore(sampleFamily());

  Future<void> _confirmAndRestore(BackupData data) async {
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'استبدال البيانات؟',
      message: 'سيُستبدل ${widget.state.all.length} شخصاً حالياً بـ '
          '${data.persons.length} شخصاً و${data.marriages.length} علاقة زواج. '
          'يُنصح بتصدير نسخة من بياناتك الحالية أولاً. لا يمكن التراجع.',
      confirmLabel: 'استبدال',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.restore(data);
      await widget.state.load();
      if (mounted) {
        showMessage(context, 'تمت الاستعادة: ${data.persons.length} شخصاً');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'فشلت الاستعادة ولم تتغير بياناتك: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والبيانات')),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'عدد الأفراد الحاليين: ${widget.state.all.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.upload_file),
              label: const Text('تصدير نسخة احتياطية'),
            ),
            const SizedBox(height: 4),
            const Text(
              'يفتح قائمة المشاركة: احفظ الملف في «الملفات» أو Drive أو أرسله لنفسك.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.download),
              label: const Text('استعادة من ملف'),
            ),
            const SizedBox(height: 4),
            const Text(
              'يستبدل كل البيانات الحالية بمحتوى الملف. يُتحقق من الملف كاملاً أولاً، '
              'وإن فشل شيء لا تتغير بياناتك.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _busy ? null : _loadSample,
              icon: const Icon(Icons.science),
              label: const Text('تحميل بيانات تجريبية'),
            ),
            const SizedBox(height: 4),
            const Text(
              'عائلة وهمية من 4 أجيال لتجربة الشجرة والخريطة، وتستبدل البيانات الحالية.',
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'تنبيه: قد يحذف أندرويد بيانات التطبيق عند تثبيت نسخة APK جديدة '
                  'موقّعة بمفتاح مختلف. صدّر نسخة احتياطية قبل كل تثبيت جديد.',
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
