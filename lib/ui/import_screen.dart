import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../core/arabic_text.dart';
import '../domain/import/csv_template.dart';
import '../domain/import/import_planner.dart';
import '../domain/import/import_service.dart';
import '../domain/import/table_reader.dart';
import 'ui_helpers.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  RawTable? _table;
  String? _fileName;
  ColumnMapping _mapping = ColumnMapping();
  ImportPlan? _plan;
  bool _skipInvalid = false;
  bool _replace = false;
  String _filter = 'all';
  bool _busy = false;

  static const int _maxShown = 300;

  void _replan() {
    final t = _table;
    if (t == null || _mapping[ColumnField.name] == null) {
      _plan = null;
      return;
    }
    final existing = _replace
        ? <String>{}
        : {
            for (final p in widget.state.all)
              normalizeArabic(widget.state.displayName(p)),
          };
    _plan = planImport(t, _mapping, existingDisplayNames: existing);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (!mounted) return;
    if (bytes == null) {
      showMessage(context, 'تعذّر قراءة الملف');
      return;
    }
    try {
      final table = readTable(bytes);
      setState(() {
        _table = table;
        _fileName = file.name;
        _mapping = ColumnMapping.autoDetect(table.headers);
        _replan();
      });
    } on ImportFormatException catch (e) {
      showMessage(context, e.message);
    } catch (e) {
      showMessage(context, 'تعذّر قراءة الملف: $e');
    }
  }

  Future<void> _shareTemplate() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/family_tree_template.csv');
      await file.writeAsString(templateCsv(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'قالب استيراد - شجرة عائلتي',
      );
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّر إنشاء القالب: $e');
    }
  }

  Future<void> _commit() async {
    final plan = _plan;
    if (plan == null) return;
    final count = plan.indicesToImport(skipInvalid: _skipInvalid).length;
    final message = _replace
        ? 'سيُستبدل ${widget.state.all.length} شخصاً حالياً بـ $count شخصاً من الملف. لا يمكن التراجع.'
        : 'ستُضاف $count شخصاً إلى البيانات الحالية (${widget.state.all.length}).';
    final ok = await confirmDialog(
      context,
      title: 'تأكيد الاستيراد',
      message: message,
      confirmLabel: 'استيراد',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await ImportService(widget.state.db)
          .commit(plan, replace: _replace, skipInvalid: _skipInvalid);
      await widget.state.load();
      if (mounted) {
        showMessage(context,
            'تم استيراد ${r.persons} شخصاً و${r.marriages} علاقة زواج');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'فشل الاستيراد ولم تتغير بياناتك: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _sample(int col) {
    final t = _table!;
    for (final r in t.rows) {
      if (col < r.length && r[col].trim().isNotEmpty) return r[col].trim();
    }
    return null;
  }

  Widget _pickBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'ملف Excel (.xlsx) أو CSV، الصف الأول عناوين الأعمدة، وكل صف بعده شخص.',
        ),
        const SizedBox(height: 12),
        const Text(
          '• عمود «الاسم» يحوي الاسم الأول فقط، وتُضاف أسماء الآباء تلقائياً.\n'
          '• الأب والأم والزوج/الزوجة: اكتب اسماً، أو معرّفاً من عمود «المعرّف».\n'
          '• للتفريق بين الأسماء المكررة اكتب اسم الأب مع جده (مثل «محمد علي»)، أو استخدم المعرّف.\n'
          '• كل الأسماء المرجعية يجب أن تكون صفوفاً في الملف نفسه.\n'
          '• ملفات xls القديمة غير مدعومة: احفظها بصيغة xlsx.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('اختيار ملف'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _shareTemplate,
          icon: const Icon(Icons.description),
          label: const Text('تنزيل قالب CSV جاهز'),
        ),
      ],
    );
  }

  Widget _previewBody(RawTable table) {
    final plan = _plan;
    final rows = plan?.rows ?? const <ImportRow>[];
    final shownAll = [
      for (final r in rows)
        if (_filter == 'all' ||
            (_filter == 'error' && r.hasError) ||
            (_filter == 'warn' && !r.hasError && r.warnings.isNotEmpty))
          r,
    ];
    final shown = shownAll.take(_maxShown).toList();

    final controls = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text('الملف: $_fileName (${table.rows.length} صفاً)'),
          ),
          TextButton(onPressed: _pickFile, child: const Text('تغيير')),
        ],
      ),
      const SizedBox(height: 8),
      for (final field in ColumnField.values) ...[
        DropdownButtonFormField<int?>(
          value: _mapping[field],
          isExpanded: true,
          decoration: InputDecoration(
            labelText: columnFieldLabel(field),
            border: const OutlineInputBorder(),
            helperText: _mapping[field] == null
                ? null
                : 'مثال: ${_sample(_mapping[field]!) ?? '—'}',
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('— بدون —')),
            for (var c = 0; c < table.headers.length; c++)
              DropdownMenuItem<int?>(
                value: c,
                child: Text(
                  table.headers[c].isEmpty ? 'عمود ${c + 1}' : table.headers[c],
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => setState(() {
            _mapping = _mapping.withField(field, v);
            _replan();
          }),
        ),
        const SizedBox(height: 12),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('استبدال كل البيانات الحالية'),
        subtitle: const Text('وإلا تُضاف الصفوف إلى الموجود'),
        value: _replace,
        onChanged: (v) => setState(() {
          _replace = v;
          _replan();
        }),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('تجاهل الصفوف الخاطئة واستيراد الباقي'),
        subtitle: const Text('وإلا يُمنع الاستيراد حتى تصحيح كل الأخطاء'),
        value: _skipInvalid,
        onChanged: (v) => setState(() => _skipInvalid = v),
      ),
      const Divider(),
      if (plan == null)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('اختر عمود «الاسم الأول» لعرض المعاينة.'),
        )
      else ...[
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('سليم: ${plan.okCount}')),
            Chip(label: Text('تحذيرات: ${plan.warningCount}')),
            Chip(label: Text('أخطاء: ${plan.errorCount}')),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('الكل')),
            ButtonSegment(value: 'warn', label: Text('تحذيرات')),
            ButtonSegment(value: 'error', label: Text('أخطاء')),
          ],
          selected: {_filter},
          onSelectionChanged: (s) => setState(() => _filter = s.first),
        ),
        if (shownAll.length > _maxShown)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('يُعرض أول $_maxShown صف من ${shownAll.length}.'),
          ),
      ],
    ];

    final canCommit = plan != null &&
        plan.indicesToImport(skipInvalid: _skipInvalid).isNotEmpty &&
        !_busy;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(delegate: SliverChildListDelegate(controls)),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final r = shown[i];
                    final icon = r.hasError
                        ? const Icon(Icons.error, color: Colors.red)
                        : (r.warnings.isNotEmpty
                            ? const Icon(Icons.warning_amber,
                                color: Colors.orange)
                            : const Icon(Icons.check_circle,
                                color: Colors.green));
                    return ListTile(
                      dense: true,
                      leading: icon,
                      title: Text(r.name.isEmpty ? '(بلا اسم)' : r.name),
                      subtitle: Text(
                        ['الصف ${r.rowNumber}', ...r.errors, ...r.warnings]
                            .join('\n'),
                      ),
                    );
                  },
                  childCount: shown.length,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canCommit ? _commit : null,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_done),
                label: Text(
                  plan == null
                      ? 'استيراد'
                      : (!_skipInvalid && plan.errorCount > 0
                          ? 'صحّح الأخطاء أو فعّل التجاهل'
                          : 'استيراد ${plan.indicesToImport(skipInvalid: _skipInvalid).length} شخصاً'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final table = _table;
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد Excel / CSV')),
      body: table == null ? _pickBody() : _previewBody(table),
    );
  }
}
