#!/usr/bin/env bash
# شجرة عائلتي - المرحلة 4أ: النسخ الاحتياطي (تصدير/استعادة JSON) + بيانات تجريبية
# شغّله من جذر المستودع: bash setup_phase4a_backup.sh
set -euo pipefail

mkdir -p lib/domain lib/ui test

# ───────────────────────── 1) حزم جديدة ─────────────────────────
if ! grep -q "file_picker" pubspec.yaml; then
  sed -i 's/^  path: \^1.9.0$/  path: ^1.9.0\n  path_provider: ^2.1.4\n  share_plus: ^10.0.2\n  file_picker: ^8.1.2/' pubspec.yaml
fi
grep -q "file_picker" pubspec.yaml
grep -q "share_plus" pubspec.yaml
grep -q "path_provider" pubspec.yaml

# ───────────────────────── 2) AppState يحتفظ بالقاعدة ─────────────────────────
if ! grep -q "final Database db;" lib/app_state.dart; then
  sed -i 's/AppState(Database db)/AppState(this.db)/' lib/app_state.dart
  sed -i '/static const int maxNameParts = 4;/a\  final Database db;' lib/app_state.dart
fi
grep -q "AppState(this.db)" lib/app_state.dart
grep -q "final Database db;" lib/app_state.dart

# ───────────────────────── 3) صيغة النسخة والتحقق ─────────────────────────
cat > lib/domain/backup.dart <<'DART_EOF'
import 'dart:convert';

import '../data/models/marriage.dart';
import '../data/models/person.dart';

class BackupException implements Exception {
  BackupException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}

class BackupData {
  const BackupData({
    required this.persons,
    required this.marriages,
    this.exportedAt,
  });

  final List<Person> persons;
  final List<Marriage> marriages;
  final DateTime? exportedAt;
}

/// ترميز وفك ترميز النسخة الاحتياطية (JSON) مع تحقق كامل قبل أي كتابة.
class BackupCodec {
  BackupCodec._();

  static const String appId = 'family_tree';
  static const int formatVersion = 1;

  static String encode(
    List<Person> persons,
    List<Marriage> marriages, {
    DateTime? now,
  }) {
    return jsonEncode({
      'app': appId,
      'format': formatVersion,
      'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'persons': persons.map((p) => p.toMap()).toList(),
      'marriages': marriages.map((m) => m.toMap()).toList(),
    });
  }

  static BackupData decode(String source) {
    Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw BackupException(['الملف ليس بصيغة JSON صالحة']);
    }
    if (raw is! Map || raw['app'] != appId) {
      throw BackupException(['الملف ليس نسخة احتياطية من «شجرة عائلتي»']);
    }
    final format = raw['format'];
    if (format is! int || format < 1) {
      throw BackupException(['رقم صيغة النسخة غير صالح']);
    }
    if (format > formatVersion) {
      throw BackupException(['النسخة أحدث من هذا التطبيق. حدّث التطبيق أولاً']);
    }
    final rawPersons = raw['persons'];
    final rawMarriages = raw['marriages'];
    if (rawPersons is! List || rawMarriages is! List) {
      throw BackupException(['بنية الملف غير مكتملة']);
    }

    final errors = <String>[];
    void err(String message) {
      if (errors.length < 10) errors.add(message);
    }

    // ───── الأشخاص ─────
    final persons = <Person>[];
    final ids = <int>{};
    for (var i = 0; i < rawPersons.length; i++) {
      final label = 'شخص رقم ${i + 1}';
      final e = rawPersons[i];
      if (e is! Map) {
        err('$label: ليس كائناً صالحاً');
        continue;
      }
      var ok = true;
      void bad(String m) {
        ok = false;
        err('$label: $m');
      }

      final id = e['id'];
      if (id is! int || id <= 0) {
        bad('معرّف غير صالح');
      } else if (!ids.add(id)) {
        bad('معرّف مكرر ($id)');
      }
      final name = e['name'];
      if (name is! String || name.trim().isEmpty) {
        bad('الاسم مفقود');
      }
      final gender = e['gender'];
      if (gender is! String || !Gender.values.any((g) => g.name == gender)) {
        bad('قيمة الجنس غير صالحة');
      }
      for (final key in ['father_id', 'mother_id']) {
        final v = e[key];
        if (v != null && v is! int) bad('الحقل $key غير صالح');
      }
      for (final key in [
        'birth_date',
        'death_date',
        'notes',
        'created_at',
        'updated_at',
      ]) {
        final v = e[key];
        if (v != null && v is! String) bad('الحقل $key غير صالح');
      }
      if (ok) {
        persons.add(Person.fromMap(Map<String, Object?>.from(e)));
      }
    }

    final byId = {for (final p in persons) p.id!: p};
    for (final p in persons) {
      for (final parent in [p.fatherId, p.motherId]) {
        if (parent == null) continue;
        if (parent == p.id) {
          err('«${p.name}»: الشخص والد/والدة نفسه');
        } else if (!byId.containsKey(parent)) {
          err('«${p.name}»: الأب/الأم رقم $parent غير موجود في الملف');
        }
      }
      if (p.fatherId != null && p.fatherId == p.motherId) {
        err('«${p.name}»: الأب والأم الشخص نفسه');
      }
    }

    // حلقات النسب
    final visitState = <int, int>{};
    bool visit(int id) {
      final s = visitState[id];
      if (s == 1) return true;
      if (s == 2) return false;
      visitState[id] = 1;
      final p = byId[id]!;
      for (final parent in [p.fatherId, p.motherId]) {
        if (parent != null &&
            parent != id &&
            byId.containsKey(parent) &&
            visit(parent)) {
          return true;
        }
      }
      visitState[id] = 2;
      return false;
    }

    for (final p in persons) {
      if (visit(p.id!)) {
        err('حلقة في النسب عند «${p.name}»');
        break;
      }
    }

    // ───── الزواج ─────
    final marriages = <Marriage>[];
    final marriageIds = <int>{};
    for (var i = 0; i < rawMarriages.length; i++) {
      final label = 'زواج رقم ${i + 1}';
      final e = rawMarriages[i];
      if (e is! Map) {
        err('$label: ليس كائناً صالحاً');
        continue;
      }
      var ok = true;
      void bad(String m) {
        ok = false;
        err('$label: $m');
      }

      final id = e['id'];
      if (id is! int || id <= 0) {
        bad('معرّف غير صالح');
      } else if (!marriageIds.add(id)) {
        bad('معرّف مكرر ($id)');
      }
      final a = e['person1_id'];
      final b = e['person2_id'];
      if (a is! int || b is! int) {
        bad('الزوجان غير محددين');
      } else {
        if (a == b) bad('زواج شخص من نفسه');
        if (!byId.containsKey(a) || !byId.containsKey(b)) {
          bad('أحد الزوجين غير موجود في الملف');
        }
      }
      final status = e['status'];
      if (status is! String ||
          !MarriageStatus.values.any((s) => s.name == status)) {
        bad('حالة الزواج غير صالحة');
      }
      for (final key in [
        'start_date',
        'end_date',
        'notes',
        'created_at',
        'updated_at',
      ]) {
        final v = e[key];
        if (v != null && v is! String) bad('الحقل $key غير صالح');
      }
      if (ok) {
        marriages.add(Marriage.fromMap(Map<String, Object?>.from(e)));
      }
    }

    if (errors.isNotEmpty) {
      throw BackupException(errors);
    }

    final exportedAt = raw['exported_at'];
    return BackupData(
      persons: persons,
      marriages: marriages,
      exportedAt: exportedAt is String ? DateTime.tryParse(exportedAt) : null,
    );
  }
}
DART_EOF

# ───────────────────────── 4) خدمة التصدير والاستعادة ─────────────────────────
cat > lib/domain/backup_service.dart <<'DART_EOF'
import 'package:sqflite/sqflite.dart';

import '../data/repositories/marriage_repository.dart';
import '../data/repositories/person_repository.dart';
import 'backup.dart';

class BackupService {
  BackupService(Database db)
      : _db = db,
        _persons = PersonRepository(db),
        _marriages = MarriageRepository(db);

  final Database _db;
  final PersonRepository _persons;
  final MarriageRepository _marriages;

  Future<String> exportJson() async {
    final persons = await _persons.getAll();
    final marriages = await _marriages.getAll();
    return BackupCodec.encode(persons, marriages);
  }

  /// يستبدل كل البيانات بمحتوى [data] داخل معاملة واحدة:
  /// عند أي فشل يُتراجع عن كل شيء وتبقى البيانات الحالية كما هي.
  Future<void> restore(BackupData data) async {
    final now = DateTime.now().toUtc();
    await _db.transaction((txn) async {
      await txn.delete(MarriageRepository.table);
      await txn.delete(PersonRepository.table);

      final batch = txn.batch();
      // الأشخاص بلا والدين أولاً، ثم الربط، لتجنب ترتيب المفاتيح الأجنبية
      for (final p in data.persons) {
        final map = p
            .copyWith(
              createdAt: p.createdAt ?? now,
              updatedAt: p.updatedAt ?? now,
            )
            .toMap();
        map['father_id'] = null;
        map['mother_id'] = null;
        batch.insert(PersonRepository.table, map);
      }
      for (final p in data.persons) {
        if (p.fatherId == null && p.motherId == null) continue;
        batch.update(
          PersonRepository.table,
          {'father_id': p.fatherId, 'mother_id': p.motherId},
          where: 'id = ?',
          whereArgs: [p.id],
        );
      }
      for (final m in data.marriages) {
        batch.insert(
          MarriageRepository.table,
          m
              .copyWith(
                createdAt: m.createdAt ?? now,
                updatedAt: m.updatedAt ?? now,
              )
              .toMap(),
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
DART_EOF

# ───────────────────────── 5) بيانات تجريبية وهمية ─────────────────────────
cat > lib/domain/sample_data.dart <<'DART_EOF'
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import 'backup.dart';

/// عائلة وهمية من 4 أجيال لتجربة الشجرة والخريطة. لا تمثل أشخاصاً حقيقيين.
BackupData sampleFamily() {
  final t = DateTime.utc(2024, 1, 1);
  Person p(int id, String name, Gender g, {int? f, int? m}) => Person(
        id: id,
        name: name,
        gender: g,
        fatherId: f,
        motherId: m,
        createdAt: t,
        updatedAt: t,
      );
  Marriage mar(int id, int a, int b,
          {MarriageStatus s = MarriageStatus.married}) =>
      Marriage(
        id: id,
        person1Id: a,
        person2Id: b,
        status: s,
        createdAt: t,
        updatedAt: t,
      );

  const male = Gender.male;
  const female = Gender.female;
  return BackupData(
    persons: [
      p(1, 'سالم', male),
      p(2, 'آمنة', female),
      p(3, 'خالد', male, f: 1, m: 2),
      p(4, 'مريم', female, f: 1, m: 2),
      p(5, 'يوسف', male, f: 1, m: 2),
      p(6, 'هدى', female),
      p(7, 'عمر', male),
      p(8, 'أحمد', male, f: 3, m: 6),
      p(9, 'سارة', female, f: 3, m: 6),
      p(10, 'ليلى', female, f: 3, m: 6),
      p(11, 'زياد', male, f: 7, m: 4),
      p(12, 'نور', female, f: 7, m: 4),
      p(13, 'رنا', female),
      p(14, 'كريم', male, f: 5, m: 13),
      p(15, 'دانة', female),
      p(16, 'ياسر', male, f: 8, m: 15),
      p(17, 'فاطمة', female),
      p(18, 'بلال', male, f: 1, m: 17),
    ],
    marriages: [
      mar(1, 1, 2),
      mar(2, 3, 6),
      mar(3, 4, 7),
      mar(4, 5, 13),
      mar(5, 8, 15),
      mar(6, 1, 17, s: MarriageStatus.divorced),
    ],
  );
}
DART_EOF

# ───────────────────────── 6) شاشة النسخ الاحتياطي ─────────────────────────
cat > lib/ui/backup_screen.dart <<'DART_EOF'
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
DART_EOF

# ───────────────────────── 7) زر في قائمة الأفراد ─────────────────────────
if ! grep -q "backup_screen.dart" lib/ui/person_list_screen.dart; then
  test "$(grep -c 'appBar: AppBar(' lib/ui/person_list_screen.dart)" = "1"
  sed -i "/import 'person_form_screen.dart';/a\import 'backup_screen.dart';" lib/ui/person_list_screen.dart
  sed -i "/appBar: AppBar(\$/a\        actions: [\n          IconButton(\n            tooltip: 'النسخ الاحتياطي والبيانات',\n            icon: const Icon(Icons.save_alt),\n            onPressed: () => Navigator.of(context).push(\n              MaterialPageRoute(builder: (_) => BackupScreen(state: state)),\n            ),\n          ),\n        ]," lib/ui/person_list_screen.dart
fi
grep -q "BackupScreen(state: state)" lib/ui/person_list_screen.dart
grep -q "import 'backup_screen.dart';" lib/ui/person_list_screen.dart

# ───────────────────────── 8) الاختبارات ─────────────────────────
cat > test/backup_test.dart <<'DART_EOF'
import 'dart:convert';

import 'package:family_tree/app_state.dart';
import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/backup.dart';
import 'package:family_tree/domain/backup_service.dart';
import 'package:family_tree/domain/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

Map<String, Object?> pm(int id,
        {String name = 'س', String gender = 'unknown', int? f, int? m}) =>
    {'id': id, 'name': name, 'gender': gender, 'father_id': f, 'mother_id': m};

Map<String, Object?> mm(int id, int a, int b, {String status = 'married'}) =>
    {'id': id, 'person1_id': a, 'person2_id': b, 'status': status};

String doc(List<Object?> persons, [List<Object?> marriages = const []]) =>
    jsonEncode({
      'app': 'family_tree',
      'format': 1,
      'persons': persons,
      'marriages': marriages,
    });

void main() {
  group('BackupCodec.decode', () {
    final throwsBackup = throwsA(isA<BackupException>());

    test('يقبل ملفاً صالحاً', () {
      final data = BackupCodec.decode(doc([pm(1), pm(2, f: 1)], [mm(1, 1, 2)]));
      expect(data.persons.length, 2);
      expect(data.marriages.length, 1);
    });

    test('يرفض ما ليس JSON أو ليس من التطبيق أو أحدث صيغة', () {
      expect(() => BackupCodec.decode('ليس json'), throwsBackup);
      expect(() => BackupCodec.decode(jsonEncode({'app': 'other'})), throwsBackup);
      expect(
          () => BackupCodec.decode(jsonEncode({
                'app': 'family_tree',
                'format': 99,
                'persons': [],
                'marriages': [],
              })),
          throwsBackup);
    });

    test('يرفض أباً غير موجود وحلقة نسب ومعرفاً مكرراً', () {
      expect(() => BackupCodec.decode(doc([pm(1, f: 5)])), throwsBackup);
      expect(() => BackupCodec.decode(doc([pm(1, f: 2), pm(2, f: 1)])),
          throwsBackup);
      expect(() => BackupCodec.decode(doc([pm(1, f: 1)])), throwsBackup);
      expect(() => BackupCodec.decode(doc([pm(1), pm(1)])), throwsBackup);
    });

    test('يرفض اسماً فارغاً وجنساً وحالة زواج غير صالحين', () {
      expect(() => BackupCodec.decode(doc([pm(1, name: '  ')])), throwsBackup);
      expect(() => BackupCodec.decode(doc([pm(1, gender: 'x')])), throwsBackup);
      expect(
          () => BackupCodec.decode(
              doc([pm(1), pm(2)], [mm(1, 1, 2, status: 'bad')])),
          throwsBackup);
    });

    test('يرفض زواجاً من النفس أو من شخص غير موجود', () {
      expect(() => BackupCodec.decode(doc([pm(1)], [mm(1, 1, 1)])), throwsBackup);
      expect(() => BackupCodec.decode(doc([pm(1)], [mm(1, 1, 9)])), throwsBackup);
    });

    test('يجمع أكثر من خطأ في استثناء واحد', () {
      try {
        BackupCodec.decode(doc([pm(1, name: ''), pm(2, f: 9)]));
        fail('كان يجب أن يفشل');
      } on BackupException catch (e) {
        expect(e.errors.length, greaterThanOrEqualTo(2));
      }
    });
  });

  group('BackupService', () {
    late Database db;
    late AppState state;
    late BackupService backup;
    late int fatherId;
    late int childId;

    setUp(() async {
      db = await openTestDb();
      state = AppState(db);
      await state.load();
      backup = BackupService(db);
      fatherId =
          await state.addPerson(const Person(name: 'أب', gender: Gender.male));
      final motherId = await state
          .addPerson(const Person(name: 'أم', gender: Gender.female));
      childId = await state.addPerson(
          Person(name: 'ابن', fatherId: fatherId, motherId: motherId));
      await state.addMarriage(Marriage(person1Id: fatherId, person2Id: motherId));
    });

    tearDown(() => db.close());

    test('تصدير ثم تغيير ثم استعادة يعيد الحال مع نفس المعرفات', () async {
      final json = await backup.exportJson();

      await state.addPerson(const Person(name: 'دخيل'));
      await state.deletePerson(fatherId);
      expect(state.byId(fatherId), isNull);

      await backup.restore(BackupCodec.decode(json));
      await state.load();

      expect(state.all.map((p) => p.name).toSet(), {'أب', 'أم', 'ابن'});
      expect(state.byId(childId)!.fatherId, fatherId);
      expect(state.displayName(state.byId(childId)!), 'ابن أب');
      expect((await state.marriagesOf(fatherId)).length, 1);
    });

    test('فشل الاستعادة يتراجع كلياً ولا تتغير البيانات', () async {
      final bad = BackupData(
        persons: const [Person(id: 1, name: 'س')],
        marriages: const [Marriage(id: 1, person1Id: 1, person2Id: 99)],
      );
      await expectLater(backup.restore(bad), throwsA(isA<Exception>()));
      await state.load();
      expect(state.all.length, 3);
      expect(state.byId(childId)!.fatherId, fatherId);
      expect((await state.marriagesOf(fatherId)).length, 1);
    });

    test('البيانات التجريبية صالحة وتُستعاد كاملة', () async {
      final sample = sampleFamily();
      final roundTrip = BackupCodec.decode(
          BackupCodec.encode(sample.persons, sample.marriages));
      expect(roundTrip.persons.length, 18);

      await backup.restore(roundTrip);
      await state.load();
      expect(state.all.length, 18);
      expect((await state.marriages.getAll()).length, 6);
      expect(state.displayName(state.byId(16)!), 'ياسر أحمد خالد سالم');
    });
  });
}
DART_EOF

echo "تم إنشاء ملفات المرحلة 4أ."
