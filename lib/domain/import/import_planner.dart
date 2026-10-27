import 'dart:math' as math;

import '../../core/arabic_text.dart';
import '../../data/models/person.dart';
import 'table_reader.dart';

enum ColumnField { id, name, gender, father, mother, spouse, notes }

String columnFieldLabel(ColumnField f) => switch (f) {
      ColumnField.id => 'المعرّف (اختياري)',
      ColumnField.name => 'الاسم الأول *',
      ColumnField.gender => 'الجنس',
      ColumnField.father => 'الأب (اسم أو معرّف)',
      ColumnField.mother => 'الأم (اسم أو معرّف)',
      ColumnField.spouse => 'الزوج/الزوجة (اسم أو معرّف)',
      ColumnField.notes => 'ملاحظات',
    };

String _headerKey(String h) => normalizeArabic(h)
    .replaceAll(RegExp(r'[^\u0621-\u064A0-9a-z#]'), '');

/// ربط حقول التطبيق بأعمدة الملف (فهرس العمود).
class ColumnMapping {
  ColumnMapping([Map<ColumnField, int>? initial]) : _m = {...?initial};

  final Map<ColumnField, int> _m;

  int? operator [](ColumnField f) => _m[f];

  ColumnMapping withField(ColumnField f, int? col) {
    final next = Map<ColumnField, int>.from(_m);
    if (col == null) {
      next.remove(f);
    } else {
      next[f] = col;
    }
    return ColumnMapping(next);
  }

  static const Map<ColumnField, List<String>> _synonyms = {
    ColumnField.id: ['id', 'رقم', 'معرف', 'المعرف', 'المعرّف', 'الرقم', 'كود', 'م', '#'],
    ColumnField.name: ['الاسم', 'اسم', 'الاسم الأول', 'اسم الشخص', 'name', 'first name'],
    ColumnField.gender: ['الجنس', 'النوع', 'gender', 'sex'],
    ColumnField.father: ['الأب', 'اب', 'اسم الأب', 'معرّف الأب', 'رقم الأب', 'father', 'father id'],
    ColumnField.mother: ['الأم', 'ام', 'اسم الأم', 'معرّف الأم', 'رقم الأم', 'mother', 'mother id'],
    ColumnField.spouse: [
      'الزوج',
      'الزوجة',
      'زوج',
      'زوجة',
      'الزوج/الزوجة',
      'الزوج أو الزوجة',
      'اسم الزوج',
      'اسم الزوجة',
      'معرّف الزوج',
      'معرّف الزوجة',
      'spouse',
      'partner',
    ],
    ColumnField.notes: ['ملاحظات', 'ملاحظة', 'notes', 'note', 'تعليق'],
  };

  /// تخمين الربط من عناوين الأعمدة.
  static ColumnMapping autoDetect(List<String> headers) {
    final used = <int>{};
    final result = <ColumnField, int>{};
    for (final field in ColumnField.values) {
      final names = _synonyms[field]!.map(_headerKey).toSet();
      for (var c = 0; c < headers.length; c++) {
        if (used.contains(c)) continue;
        if (names.contains(_headerKey(headers[c]))) {
          result[field] = c;
          used.add(c);
          break;
        }
      }
    }
    return ColumnMapping(result);
  }
}

class ImportRow {
  ImportRow({
    required this.rowNumber,
    required this.name,
    this.gender = Gender.unknown,
    this.key,
    this.notes,
    this.fatherRef,
    this.motherRef,
    this.spouseRef,
  });

  final int rowNumber;
  final String name;
  Gender gender;
  final String? key;
  final String? notes;
  final String? fatherRef;
  final String? motherRef;
  final String? spouseRef;

  int? fatherIndex;
  int? motherIndex;
  int? spouseIndex;

  final List<String> errors = [];
  final List<String> warnings = [];
  bool importable = true;

  bool get hasError => errors.isNotEmpty;
}

class ImportPlan {
  ImportPlan(this.rows);

  final List<ImportRow> rows;

  int get errorCount => rows.where((r) => r.hasError).length;
  int get warningCount =>
      rows.where((r) => !r.hasError && r.warnings.isNotEmpty).length;
  int get okCount =>
      rows.where((r) => !r.hasError && r.warnings.isEmpty).length;

  /// الصفوف التي ستُستورد: مع [skipInvalid] الصالحة فقط، وبدونه الكل بشرط عدم وجود أخطاء.
  List<int> indicesToImport({required bool skipInvalid}) {
    if (skipInvalid) {
      return [
        for (var i = 0; i < rows.length; i++)
          if (rows[i].importable) i,
      ];
    }
    if (errorCount > 0) return const [];
    return [for (var i = 0; i < rows.length; i++) i];
  }

  /// أزواج الزواج (بلا تكرار) بين الصفوف المستوردة.
  List<List<int>> marriagePairs(Set<int> included) {
    final seen = <String>{};
    final pairs = <List<int>>[];
    for (final i in included) {
      final s = rows[i].spouseIndex;
      if (s == null || s == i || !included.contains(s)) continue;
      final a = math.min(i, s);
      final b = math.max(i, s);
      if (seen.add('$a-$b')) pairs.add([a, b]);
    }
    return pairs;
  }
}

enum _Look { none, resolved, notFound, ambiguous, self }

String _norm(String s) {
  const digits = '٠١٢٣٤٥٦٧٨٩';
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    final d = digits.indexOf(c);
    buf.write(d >= 0 ? '$d' : c);
  }
  return normalizeArabic(buf.toString());
}

/// null = غير مفهوم. الفارغ = غير محدد.
Gender? _parseGender(String raw) {
  final t = _norm(raw);
  if (t.isEmpty) return Gender.unknown;
  const male = {'ذكر', 'ذ', 'm', 'male', 'رجل', 'ولد', 'ابن'};
  const female = {'انثي', 'ا', 'ث', 'f', 'female', 'امراه', 'بنت'};
  const unknown = {'غير محدد', 'unknown', '-', '؟', '?'};
  if (male.contains(t)) return Gender.male;
  if (female.contains(t)) return Gender.female;
  if (unknown.contains(t)) return Gender.unknown;
  return null;
}

List<String> _chain(List<ImportRow> rows, int i, int max) {
  final parts = <String>[];
  final seen = <int>{};
  int? cur = i;
  while (cur != null && parts.length < max && seen.add(cur)) {
    parts.add(_norm(rows[cur].name));
    cur = rows[cur].fatherIndex;
  }
  return parts;
}

bool _reachesSelf(List<ImportRow> rows, int start) {
  final seen = <int>{};
  final stack = <int>[
    if (rows[start].fatherIndex != null) rows[start].fatherIndex!,
    if (rows[start].motherIndex != null) rows[start].motherIndex!,
  ];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    if (c == start) return true;
    if (!seen.add(c)) continue;
    final r = rows[c];
    if (r.fatherIndex != null) stack.add(r.fatherIndex!);
    if (r.motherIndex != null) stack.add(r.motherIndex!);
  }
  return false;
}

/// يبني خطة الاستيراد: يقرأ الصفوف، يحلّ مراجع الأب/الأم/الزوج، ويتحقق من كل شيء دون كتابة أي بيانات.
///
/// المرجع قد يكون: معرّفاً من عمود المعرّف، أو اسماً أول فريداً، أو اسماً مع سلسلة آبائه
/// (مثل «محمد علي») للتفريق بين الأسماء المكررة.
ImportPlan planImport(
  RawTable table,
  ColumnMapping mapping, {
  Set<String> existingDisplayNames = const {},
  int maxNameParts = 4,
}) {
  String cell(List<String> r, ColumnField f) {
    final c = mapping[f];
    if (c == null || c >= r.length) return '';
    return r[c].trim();
  }

  String? orNull(String s) => s.isEmpty ? null : s;

  // ───── 1) قراءة الصفوف ─────
  final rows = <ImportRow>[];
  for (var k = 0; k < table.rows.length; k++) {
    final r = table.rows[k];
    final name = cell(r, ColumnField.name).replaceAll(RegExp(r'\s+'), ' ');
    final idText = cell(r, ColumnField.id);
    final genderText = cell(r, ColumnField.gender);
    final father = cell(r, ColumnField.father);
    final mother = cell(r, ColumnField.mother);
    final spouse = cell(r, ColumnField.spouse);
    final notes = cell(r, ColumnField.notes);
    if ([name, idText, genderText, father, mother, spouse, notes]
        .every((s) => s.isEmpty)) {
      continue;
    }
    final row = ImportRow(
      rowNumber: table.rowNumbers[k],
      name: name,
      key: orNull(idText),
      notes: orNull(notes),
      fatherRef: orNull(father),
      motherRef: orNull(mother),
      spouseRef: orNull(spouse),
    );
    if (name.isEmpty) {
      row.errors.add('الاسم مفقود');
    } else if (name.length > 200) {
      row.errors.add('الاسم أطول من 200 حرف');
    }
    final g = _parseGender(genderText);
    if (g == null) {
      row.warnings.add('جنس غير مفهوم «$genderText»، سيُسجَّل غير محدد');
    } else {
      row.gender = g;
    }
    rows.add(row);
  }

  // ───── 2) فهارس البحث ─────
  final byKey = <String, List<int>>{};
  final byName = <String, List<int>>{};
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if (r.key != null) (byKey[_norm(r.key!)] ??= []).add(i);
    if (r.name.isNotEmpty) (byName[_norm(r.name)] ??= []).add(i);
  }
  for (final e in byKey.entries) {
    if (e.value.length > 1) {
      for (final i in e.value) {
        rows[i].errors.add('المعرّف «${rows[i].key}» مكرر');
      }
    }
  }

  bool compatible(int i, ColumnField f) {
    final g = rows[i].gender;
    if (f == ColumnField.father) return g != Gender.female;
    if (f == ColumnField.mother) return g != Gender.male;
    return true;
  }

  // ───── 3) حلّ المراجع (معرّف، ثم اسم فريد) ─────
  _Look resolve(int self, ColumnField f, String ref, void Function(int) set) {
    final t = _norm(ref);
    int? found;
    final keyHits = byKey[t];
    if (keyHits != null) {
      if (keyHits.length != 1) return _Look.ambiguous;
      found = keyHits.first;
    } else {
      final hits = byName[t];
      if (hits == null) return _Look.notFound;
      final others = hits.where((i) => i != self).toList();
      if (others.isEmpty) return _Look.self;
      final compat = others.where((i) => compatible(i, f)).toList();
      final cands = compat.isNotEmpty ? compat : others;
      if (cands.length != 1) return _Look.ambiguous;
      found = cands.first;
    }
    if (found == self) return _Look.self;
    set(found);
    return _Look.resolved;
  }

  const fields = [ColumnField.father, ColumnField.mother, ColumnField.spouse];
  String? refOf(ImportRow r, int f) =>
      f == 0 ? r.fatherRef : (f == 1 ? r.motherRef : r.spouseRef);
  void setIdx(ImportRow r, int f, int? v) {
    if (f == 0) {
      r.fatherIndex = v;
    } else if (f == 1) {
      r.motherIndex = v;
    } else {
      r.spouseIndex = v;
    }
  }

  final looks = [
    for (var f = 0; f < 3; f++) List<_Look>.filled(rows.length, _Look.none),
  ];
  for (var i = 0; i < rows.length; i++) {
    for (var f = 0; f < 3; f++) {
      final ref = refOf(rows[i], f);
      if (ref == null) continue;
      looks[f][i] =
          resolve(i, fields[f], ref, (x) => setIdx(rows[i], f, x));
    }
  }

  // ───── 4) التفريق بسلسلة الآباء ─────
  var progress = true;
  var loops = 0;
  while (progress && loops++ < 10) {
    progress = false;
    final chains = [
      for (var i = 0; i < rows.length; i++) _chain(rows, i, 6).join(' '),
    ];
    for (var f = 0; f < 3; f++) {
      for (var i = 0; i < rows.length; i++) {
        final look = looks[f][i];
        if (look != _Look.ambiguous && look != _Look.notFound) continue;
        final ref = refOf(rows[i], f);
        if (ref == null) continue;
        final t = _norm(ref);
        if (t.isEmpty) continue;
        final matches = <int>[];
        for (var j = 0; j < rows.length; j++) {
          if (j == i || !compatible(j, fields[f])) continue;
          final c = chains[j];
          if (c == t || c.startsWith('$t ')) matches.add(j);
        }
        if (matches.length == 1) {
          setIdx(rows[i], f, matches.first);
          looks[f][i] = _Look.resolved;
          progress = true;
        }
      }
    }
  }

  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    for (var f = 0; f < 3; f++) {
      final look = looks[f][i];
      final ref = refOf(r, f);
      if (ref == null || look == _Look.resolved || look == _Look.none) continue;
      final label = f == 0 ? 'الأب' : (f == 1 ? 'الأم' : 'الزوج/الزوجة');
      final msg = switch (look) {
        _Look.ambiguous =>
          '$label «$ref» ينطبق على أكثر من شخص؛ استخدم عمود المعرّف أو اسماً أوضح (مثل «محمد علي»)',
        _Look.notFound => '$label «$ref» غير موجود في الملف',
        _Look.self => '$label «$ref» هو الشخص نفسه',
        _ => '',
      };
      if (f == 2) {
        r.warnings.add('$msg (تم تجاهل الزواج)');
      } else {
        r.errors.add(msg);
      }
    }
  }

  // ───── 5) تحقق العلاقات ─────
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final f = r.fatherIndex;
    final m = r.motherIndex;
    if (f != null && rows[f].gender == Gender.female) {
      r.errors.add('الأب «${rows[f].name}» مسجّل أنثى');
    }
    if (m != null && rows[m].gender == Gender.male) {
      r.errors.add('الأم «${rows[m].name}» مسجّلة ذكراً');
    }
    if (f != null && f == m) {
      r.errors.add('الأب والأم هما الشخص نفسه');
    }
    if (_reachesSelf(rows, i)) {
      r.errors.add('حلقة في النسب (الشخص من أسلاف نفسه)');
    }
  }

  // ───── 6) تنبيهات التكرار ─────
  final seen = <String, int>{};
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if (r.name.isEmpty) continue;
    final k = '${_norm(r.name)}|${r.fatherIndex}|${r.motherIndex}';
    final first = seen[k];
    if (first != null) {
      r.warnings
          .add('يشبه الصف ${rows[first].rowNumber} (نفس الاسم والوالدين)');
    } else {
      seen[k] = i;
    }
  }
  if (existingDisplayNames.isNotEmpty) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].name.isEmpty) continue;
      final full = _chain(rows, i, maxNameParts).join(' ');
      if (existingDisplayNames.contains(full)) {
        rows[i]
            .warnings
            .add('يوجد شخص بالاسم الكامل نفسه في البيانات الحالية');
      }
    }
  }

  // ───── 7) الصفوف القابلة للاستيراد (انتشار الرفض إلى الأبناء) ─────
  for (final r in rows) {
    r.importable = !r.hasError;
  }
  var changed = true;
  while (changed) {
    changed = false;
    for (final r in rows) {
      if (!r.importable) continue;
      for (final p in [r.fatherIndex, r.motherIndex]) {
        if (p != null && !rows[p].importable) {
          r.importable = false;
          r.errors.add(
              'مرتبط بصف مرفوض (الأب/الأم في الصف ${rows[p].rowNumber})');
          changed = true;
          break;
        }
      }
    }
  }

  return ImportPlan(rows);
}
