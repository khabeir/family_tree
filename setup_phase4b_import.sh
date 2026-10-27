#!/usr/bin/env bash
# شجرة عائلتي - المرحلة 4ب: استيراد Excel (.xlsx) وCSV
# شغّله من جذر المستودع: bash setup_phase4b_import.sh
set -euo pipefail

mkdir -p lib/domain/import lib/ui test

# ───────────────────────── 1) حزم: archive وxml لقراءة xlsx ─────────────────────────
if ! grep -q "archive:" pubspec.yaml; then
  sed -i 's/^  file_picker: \^8.1.2$/  file_picker: ^8.1.2\n  archive: ^3.6.1\n  xml: ^6.5.0/' pubspec.yaml
fi
grep -q "archive:" pubspec.yaml
grep -q "xml:" pubspec.yaml

# ───────────────────────── 2) قراءة الجداول (CSV + xlsx) ─────────────────────────
cat > lib/domain/import/table_reader.dart <<'DART_EOF'
import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ImportFormatException implements Exception {
  ImportFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// جدول خام: الصف الأول غير الفارغ هو العناوين، وتُحذف الصفوف الفارغة.
class RawTable {
  const RawTable({
    required this.headers,
    required this.rows,
    required this.rowNumbers,
  });

  final List<String> headers;
  final List<List<String>> rows;

  /// رقم كل صف كما يظهر في Excel (للرسائل).
  final List<int> rowNumbers;
}

const int maxImportRows = 20000;

/// يقرأ xlsx أو CSV تلقائياً (بالتعرّف على بداية ملف zip).
RawTable readTable(List<int> bytes) {
  final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  final grid = isZip ? parseXlsx(bytes) : parseCsv(_decodeText(bytes));
  return tableFromGrid(grid);
}

String _decodeText(List<int> bytes) {
  var data = bytes;
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = data.sublist(3);
  }
  try {
    return utf8.decode(data);
  } on FormatException {
    throw ImportFormatException(
        'ترميز الملف غير مدعوم. احفظه بصيغة CSV UTF-8 أو بصيغة xlsx.');
  }
}

RawTable tableFromGrid(List<List<String>> grid) {
  bool isEmpty(List<String> r) => r.every((c) => c.trim().isEmpty);
  final h = grid.indexWhere((r) => !isEmpty(r));
  if (h < 0) {
    throw ImportFormatException('الملف فارغ');
  }
  final width =
      grid.skip(h).fold<int>(0, (m, r) => math.max(m, r.length));
  List<String> pad(List<String> r) =>
      [for (var i = 0; i < width; i++) i < r.length ? r[i] : ''];

  final headers = pad(grid[h]).map((s) => s.trim()).toList();
  final rows = <List<String>>[];
  final numbers = <int>[];
  for (var i = h + 1; i < grid.length; i++) {
    if (isEmpty(grid[i])) continue;
    rows.add(pad(grid[i]));
    numbers.add(i + 1);
  }
  if (rows.isEmpty) {
    throw ImportFormatException('لا توجد صفوف بيانات بعد صف العناوين');
  }
  if (rows.length > maxImportRows) {
    throw ImportFormatException('عدد الصفوف أكبر من الحد ($maxImportRows)');
  }
  return RawTable(headers: headers, rows: rows, rowNumbers: numbers);
}

// ───────────────────────── CSV ─────────────────────────

String _detectDelimiter(String text) {
  var inQuotes = false;
  final counts = <String, int>{',': 0, ';': 0, '\t': 0};
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (!inQuotes) {
      if (c == '\n') break;
      if (counts.containsKey(c)) counts[c] = counts[c]! + 1;
    }
  }
  var best = ',';
  var n = counts[',']!;
  for (final e in counts.entries) {
    if (e.value > n) {
      best = e.key;
      n = e.value;
    }
  }
  return best;
}

/// قارئ CSV (RFC 4180): علامات اقتباس، فواصل داخل الحقول، \r\n، واكتشاف الفاصل (, ; Tab).
List<List<String>> parseCsv(String input, {String? delimiter}) {
  final text = input.startsWith('\uFEFF') ? input.substring(1) : input;
  final d = delimiter ?? _detectDelimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"' && field.isEmpty) {
      inQuotes = true;
    } else if (c == d) {
      endField();
    } else if (c == '\n') {
      endRow();
    } else if (c == '\r') {
      final nextIsLf = i + 1 < text.length && text[i + 1] == '\n';
      if (!nextIsLf) endRow();
    } else {
      field.write(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    endRow();
  }
  return rows;
}

/// يكتب CSV بترميز UTF-8 مع BOM ليفتحه Excel بالعربية بشكل صحيح.
String toCsv(List<List<String>> rows) {
  String q(String s) {
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  return '\uFEFF${rows.map((r) => r.map(q).join(',')).join('\r\n')}\r\n';
}

// ───────────────────────── xlsx ─────────────────────────

String _siText(XmlElement si) {
  final buf = StringBuffer();
  for (final child in si.childElements) {
    final name = child.name.local;
    if (name == 't') {
      buf.write(child.innerText);
    } else if (name == 'r') {
      for (final t in child.childElements) {
        if (t.name.local == 't') buf.write(t.innerText);
      }
    }
  }
  return buf.toString();
}

int _colIndex(String ref) {
  var idx = 0;
  for (var i = 0; i < ref.length; i++) {
    final code = ref.codeUnitAt(i);
    if (code >= 65 && code <= 90) {
      idx = idx * 26 + (code - 64);
    } else if (code >= 97 && code <= 122) {
      idx = idx * 26 + (code - 96);
    } else {
      break;
    }
  }
  return math.max(idx - 1, 0);
}

String _cleanNumber(String v) {
  final t = v.trim();
  return RegExp(r'^-?\d+\.0+$').hasMatch(t) ? t.substring(0, t.indexOf('.')) : t;
}

/// يقرأ أول ورقة في ملف xlsx ويعيدها شبكة نصية (فهرس الصف = رقم الصف - 1).
List<List<String>> parseXlsx(List<int> bytes) {
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw ImportFormatException('ملف Excel غير صالح أو تالف');
  }

  String? readText(String path) {
    final f = archive.findFile(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>);
  }

  try {
    final shared = <String>[];
    final sst = readText('xl/sharedStrings.xml');
    if (sst != null) {
      for (final si in XmlDocument.parse(sst).findAllElements('si')) {
        shared.add(_siText(si));
      }
    }

    var sheetPath = 'xl/worksheets/sheet1.xml';
    final wb = readText('xl/workbook.xml');
    final rels = readText('xl/_rels/workbook.xml.rels');
    if (wb != null && rels != null) {
      final sheets = XmlDocument.parse(wb).findAllElements('sheet');
      if (sheets.isNotEmpty) {
        String? rid;
        for (final a in sheets.first.attributes) {
          if (a.name.local == 'id') rid = a.value;
        }
        if (rid != null) {
          for (final rel in XmlDocument.parse(rels).findAllElements('Relationship')) {
            if (rel.getAttribute('Id') == rid) {
              final target = rel.getAttribute('Target');
              if (target != null) {
                sheetPath =
                    target.startsWith('/') ? target.substring(1) : 'xl/$target';
              }
            }
          }
        }
      }
    }

    final sheetXml = readText(sheetPath);
    if (sheetXml == null) {
      throw ImportFormatException('لم يُعثر على ورقة بيانات في الملف');
    }

    final rows = <List<String>>[];
    for (final rowEl in XmlDocument.parse(sheetXml).findAllElements('row')) {
      final rowNum = int.tryParse(rowEl.getAttribute('r') ?? '');
      final cells = <int, String>{};
      var maxCol = -1;
      var next = 0;
      for (final c in rowEl.findElements('c')) {
        final ref = c.getAttribute('r');
        final col = ref == null ? next : _colIndex(ref);
        next = col + 1;
        final type = c.getAttribute('t');
        var value = '';
        if (type == 'inlineStr') {
          final isEl = c.getElement('is');
          if (isEl != null) value = _siText(isEl);
        } else {
          final v = c.getElement('v')?.innerText ?? '';
          if (type == 's') {
            final idx = int.tryParse(v.trim());
            value = (idx != null && idx >= 0 && idx < shared.length)
                ? shared[idx]
                : '';
          } else {
            value = _cleanNumber(v);
          }
        }
        cells[col] = value;
        maxCol = math.max(maxCol, col);
      }
      final list = List<String>.filled(maxCol + 1, '');
      cells.forEach((k, v) => list[k] = v);

      final target = rowNum ?? rows.length + 1;
      while (rows.length < target - 1) {
        rows.add(<String>[]);
      }
      rows.add(list);
    }
    return rows;
  } on ImportFormatException {
    rethrow;
  } catch (_) {
    throw ImportFormatException('تعذّر قراءة محتوى ملف Excel');
  }
}
DART_EOF

# ───────────────────────── 3) مخطط الاستيراد: ربط الأعمدة والتحقق ─────────────────────────
cat > lib/domain/import/import_planner.dart <<'DART_EOF'
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
DART_EOF

# ───────────────────────── 4) تنفيذ الاستيراد بمعاملة واحدة ─────────────────────────
cat > lib/domain/import/import_service.dart <<'DART_EOF'
import 'package:sqflite/sqflite.dart';

import '../../data/repositories/marriage_repository.dart';
import '../../data/repositories/person_repository.dart';
import 'import_planner.dart';
import 'table_reader.dart';

class ImportResult {
  const ImportResult(this.persons, this.marriages);

  final int persons;
  final int marriages;
}

class ImportService {
  ImportService(this._db);

  final Database _db;

  /// يكتب الخطة في معاملة واحدة: عند أي فشل يُتراجع عن كل شيء.
  /// [replace] يحذف البيانات الحالية أولاً (داخل المعاملة نفسها).
  Future<ImportResult> commit(
    ImportPlan plan, {
    required bool replace,
    required bool skipInvalid,
  }) async {
    final indices = plan.indicesToImport(skipInvalid: skipInvalid);
    if (indices.isEmpty) {
      throw ImportFormatException('لا توجد صفوف صالحة للاستيراد');
    }
    final included = indices.toSet();
    final pairs = plan.marriagePairs(included);
    final now = DateTime.now().toUtc().toIso8601String();
    final newIds = <int, int>{};

    await _db.transaction((txn) async {
      if (replace) {
        await txn.delete(MarriageRepository.table);
        await txn.delete(PersonRepository.table);
      }
      for (final i in indices) {
        final r = plan.rows[i];
        newIds[i] = await txn.insert(PersonRepository.table, {
          'name': r.name,
          'gender': r.gender.name,
          'notes': r.notes,
          'created_at': now,
          'updated_at': now,
        });
      }
      for (final i in indices) {
        final r = plan.rows[i];
        final f = r.fatherIndex == null ? null : newIds[r.fatherIndex];
        final m = r.motherIndex == null ? null : newIds[r.motherIndex];
        if (f == null && m == null) continue;
        await txn.update(
          PersonRepository.table,
          {'father_id': f, 'mother_id': m},
          where: 'id = ?',
          whereArgs: [newIds[i]],
        );
      }
      for (final p in pairs) {
        await txn.insert(MarriageRepository.table, {
          'person1_id': newIds[p[0]],
          'person2_id': newIds[p[1]],
          'status': 'married',
          'created_at': now,
          'updated_at': now,
        });
      }
    });
    return ImportResult(indices.length, pairs.length);
  }
}
DART_EOF

# ───────────────────────── 5) قالب CSV جاهز ─────────────────────────
cat > lib/domain/import/csv_template.dart <<'DART_EOF'
import '../../data/models/person.dart';
import '../sample_data.dart';
import 'table_reader.dart';

/// قالب CSV بالأعمدة المدعومة، مملوء بالعائلة التجريبية الوهمية لتعرف الشكل المطلوب.
String templateCsv() {
  final s = sampleFamily();
  final spouseOf = <int, int>{};
  for (final m in s.marriages) {
    spouseOf.putIfAbsent(m.person1Id, () => m.person2Id);
    spouseOf.putIfAbsent(m.person2Id, () => m.person1Id);
  }
  String g(Gender x) => x == Gender.male ? 'ذكر' : (x == Gender.female ? 'أنثى' : '');
  return toCsv([
    ['المعرّف', 'الاسم', 'الجنس', 'معرّف الأب', 'معرّف الأم', 'الزوج/الزوجة', 'ملاحظات'],
    for (final p in s.persons)
      [
        '${p.id}',
        p.name,
        g(p.gender),
        p.fatherId == null ? '' : '${p.fatherId}',
        p.motherId == null ? '' : '${p.motherId}',
        spouseOf[p.id] == null ? '' : '${spouseOf[p.id]}',
        '',
      ],
  ]);
}
DART_EOF

# ───────────────────────── 6) شاشة الاستيراد ─────────────────────────
cat > lib/ui/import_screen.dart <<'DART_EOF'
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
DART_EOF

# ───────────────────────── 7) زر الاستيراد في قائمة الأفراد ─────────────────────────
if ! grep -q "import_screen.dart" lib/ui/person_list_screen.dart; then
  test "$(grep -c 'actions: \[' lib/ui/person_list_screen.dart)" = "1"
  sed -i "/import 'backup_screen.dart';/a\import 'import_screen.dart';" lib/ui/person_list_screen.dart
  sed -i "/actions: \[\$/a\          IconButton(\n            tooltip: 'استيراد Excel / CSV',\n            icon: const Icon(Icons.table_chart),\n            onPressed: () => Navigator.of(context).push(\n              MaterialPageRoute(builder: (_) => ImportScreen(state: state)),\n            ),\n          )," lib/ui/person_list_screen.dart
fi
grep -q "ImportScreen(state: state)" lib/ui/person_list_screen.dart
grep -q "import 'import_screen.dart';" lib/ui/person_list_screen.dart

# ───────────────────────── 8) الاختبارات ─────────────────────────
cat > test/import_test.dart <<'DART_EOF'
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:family_tree/app_state.dart';
import 'package:family_tree/core/arabic_text.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/import/csv_template.dart';
import 'package:family_tree/domain/import/import_planner.dart';
import 'package:family_tree/domain/import/import_service.dart';
import 'package:family_tree/domain/import/table_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

RawTable tbl(List<String> headers, List<List<String>> rows) => RawTable(
      headers: headers,
      rows: rows,
      rowNumbers: [for (var i = 0; i < rows.length; i++) i + 2],
    );

const h4 = ['الاسم', 'الجنس', 'الأب', 'الأم'];
ColumnMapping map4() => ColumnMapping({
      ColumnField.name: 0,
      ColumnField.gender: 1,
      ColumnField.father: 2,
      ColumnField.mother: 3,
    });

List<int> buildXlsx() {
  final a = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    a.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('xl/workbook.xml',
      '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>');
  add('xl/_rels/workbook.xml.rels',
      '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>');
  add('xl/sharedStrings.xml',
      '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>الاسم</t></si><si><t>الجنس</t></si><si><t>سالم</t></si></sst>');
  add('xl/worksheets/sheet1.xml',
      '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
      '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
      '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2" t="inlineStr"><is><t>ذكر</t></is></c></row>'
      '<row r="4"><c r="A4"><v>5</v></c><c r="C4" t="inlineStr"><is><t>x</t></is></c></row>'
      '</sheetData></worksheet>');
  return ZipEncoder().encode(a)!;
}

void main() {
  group('CSV', () {
    test('فاصلة منقوطة واقتباس وفاصلة داخل الحقل و CRLF', () {
      final g = parseCsv('الاسم;الجنس\r\nسالم;ذكر\r\n"آمنة، الكبرى";أنثى\r\n');
      expect(g, [
        ['الاسم', 'الجنس'],
        ['سالم', 'ذكر'],
        ['آمنة، الكبرى', 'أنثى'],
      ]);
    });

    test('اقتباس مزدوج داخل الحقل وBOM', () {
      final g = parseCsv('\uFEFFa,"he said ""hi""",c\n');
      expect(g, [
        ['a', 'he said "hi"', 'c']
      ]);
    });

    test('toCsv ثم parseCsv يعيد القيم نفسها', () {
      final rows = [
        ['أ', 'ب، ج', 'د"هـ'],
        ['1', '', '3'],
      ];
      expect(parseCsv(toCsv(rows)), rows);
    });

    test('readTable يتجاوز الصفوف الفارغة ويحفظ أرقام الصفوف', () {
      final t = readTable(utf8.encode(',\nالاسم,الجنس\nسالم,ذكر\n,\nخالد,ذكر\n'));
      expect(t.headers, ['الاسم', 'الجنس']);
      expect(t.rows.length, 2);
      expect(t.rowNumbers, [3, 5]);
    });

    test('ملف فارغ أو بلا بيانات يرفض', () {
      expect(() => readTable(utf8.encode('')), throwsA(isA<ImportFormatException>()));
      expect(() => readTable(utf8.encode('الاسم,الجنس\n')),
          throwsA(isA<ImportFormatException>()));
    });
  });

  group('xlsx', () {
    test('قراءة نصوص مشتركة ونصوص مضمنة وأرقام وخلايا فارغة', () {
      final t = readTable(buildXlsx());
      expect(t.headers, ['الاسم', 'الجنس', '']);
      expect(t.rows, [
        ['سالم', 'ذكر', ''],
        ['5', '', 'x'],
      ]);
      expect(t.rowNumbers, [2, 4]);
    });

    test('ملف zip تالف يرفض برسالة', () {
      expect(() => readTable([0x50, 0x4B, 0x00, 0x00, 1, 2, 3]),
          throwsA(isA<ImportFormatException>()));
    });
  });

  group('ColumnMapping.autoDetect', () {
    test('عناوين عربية شائعة', () {
      final m = ColumnMapping.autoDetect(
          ['م', 'الاسم', 'الجنس', 'الأب', 'الأم', 'الزوج/الزوجة', 'ملاحظات']);
      expect(m[ColumnField.id], 0);
      expect(m[ColumnField.name], 1);
      expect(m[ColumnField.gender], 2);
      expect(m[ColumnField.father], 3);
      expect(m[ColumnField.mother], 4);
      expect(m[ColumnField.spouse], 5);
      expect(m[ColumnField.notes], 6);
    });

    test('عناوين القالب نفسها تُكتشف', () {
      final t = readTable(utf8.encode(templateCsv()));
      final m = ColumnMapping.autoDetect(t.headers);
      expect(m[ColumnField.id], isNotNull);
      expect(m[ColumnField.name], isNotNull);
      expect(m[ColumnField.father], isNotNull);
      expect(m[ColumnField.mother], isNotNull);
      expect(m[ColumnField.spouse], isNotNull);
    });
  });

  group('planImport', () {
    test('أسماء فريدة تُربط بالأب والأم', () {
      final plan = planImport(
        tbl(h4, [
          ['سالم', 'ذكر', '', ''],
          ['آمنة', 'أنثى', '', ''],
          ['خالد', 'ذكر', 'سالم', 'آمنة'],
        ]),
        map4(),
      );
      expect(plan.errorCount, 0);
      expect(plan.rows[2].fatherIndex, 0);
      expect(plan.rows[2].motherIndex, 1);
    });

    test('تفريق الأسماء المكررة بسلسلة الآباء', () {
      final plan = planImport(
        tbl(h4, [
          ['علي', 'ذكر', '', ''],
          ['محمد', 'ذكر', 'علي', ''],
          ['حسن', 'ذكر', '', ''],
          ['محمد', 'ذكر', 'حسن', ''],
          ['ابن1', 'ذكر', 'محمد علي', ''],
          ['ابن2', 'ذكر', 'محمد', ''],
        ]),
        map4(),
      );
      expect(plan.rows[4].hasError, isFalse);
      expect(plan.rows[4].fatherIndex, 1);
      expect(plan.rows[5].hasError, isTrue);
      expect(plan.rows[5].errors.first, contains('أكثر من شخص'));
    });

    test('أب غير موجود خطأ، والابن يُرفض تبعاً، والتجاهل يستورد الباقي', () {
      final plan = planImport(
        tbl(h4, [
          ['أ', 'ذكر', 'غائب', ''],
          ['ب', 'ذكر', 'أ', ''],
          ['ج', 'ذكر', '', ''],
        ]),
        map4(),
      );
      expect(plan.rows[0].hasError, isTrue);
      expect(plan.rows[1].importable, isFalse);
      expect(plan.rows[2].importable, isTrue);
      expect(plan.indicesToImport(skipInvalid: true), [2]);
      expect(plan.indicesToImport(skipInvalid: false), isEmpty);
    });

    test('أب مسجّل أنثى وحلقة نسب', () {
      final plan = planImport(
        tbl(h4, [
          ['آمنة', 'أنثى', '', ''],
          ['ابن', 'ذكر', 'آمنة', ''],
          ['س', '', 'ص', ''],
          ['ص', '', 'س', ''],
        ]),
        map4(),
      );
      expect(plan.rows[1].errors.any((e) => e.contains('أنثى')), isTrue);
      expect(plan.rows[2].errors.any((e) => e.contains('حلقة')), isTrue);
      expect(plan.rows[3].errors.any((e) => e.contains('حلقة')), isTrue);
    });

    test('المعرّف له أولوية على الاسم', () {
      final plan = planImport(
        tbl(['المعرّف', 'الاسم', 'الأب'], [
          ['1', 'أحمد', ''],
          ['2', 'أحمد', '1'],
        ]),
        ColumnMapping({
          ColumnField.id: 0,
          ColumnField.name: 1,
          ColumnField.father: 2,
        }),
      );
      expect(plan.errorCount, 0);
      expect(plan.rows[1].fatherIndex, 0);
    });

    test('أرقام عربية هندية في المعرّفات', () {
      final plan = planImport(
        tbl(['المعرّف', 'الاسم', 'الأب'], [
          ['1', 'أ', ''],
          ['٢', 'ب', '1'],
          ['3', 'ج', '٢'],
        ]),
        ColumnMapping({
          ColumnField.id: 0,
          ColumnField.name: 1,
          ColumnField.father: 2,
        }),
      );
      expect(plan.errorCount, 0);
      expect(plan.rows[2].fatherIndex, 1);
    });

    test('جنس غير مفهوم تحذير ويصبح غير محدد، والاسم الفارغ خطأ', () {
      final plan = planImport(
        tbl(h4, [
          ['س', 'xyz', '', ''],
          ['', 'ذكر', '', ''],
        ]),
        map4(),
      );
      expect(plan.rows[0].gender, Gender.unknown);
      expect(plan.rows[0].warnings, isNotEmpty);
      expect(plan.rows[1].hasError, isTrue);
    });

    test('الزواج المتبادل يُحتسب مرة واحدة', () {
      final plan = planImport(
        tbl(['الاسم', 'الجنس', 'الزوج/الزوجة'], [
          ['سالم', 'ذكر', 'آمنة'],
          ['آمنة', 'أنثى', 'سالم'],
        ]),
        ColumnMapping({
          ColumnField.name: 0,
          ColumnField.gender: 1,
          ColumnField.spouse: 2,
        }),
      );
      expect(plan.marriagePairs({0, 1}), [
        [0, 1]
      ]);
    });

    test('تنبيه تكرار مع الموجود وبين الصفوف', () {
      final plan = planImport(
        tbl(h4, [
          ['سالم', 'ذكر', '', ''],
          ['سالم', 'ذكر', '', ''],
        ]),
        map4(),
        existingDisplayNames: {normalizeArabic('سالم')},
      );
      expect(plan.rows[0].warnings.any((w) => w.contains('الحالية')), isTrue);
      expect(plan.rows[1].warnings.any((w) => w.contains('يشبه')), isTrue);
    });

    test('قالب CSV يمر بلا أخطاء ويعطي 18 شخصاً و6 زيجات', () {
      final t = readTable(utf8.encode(templateCsv()));
      final plan = planImport(t, ColumnMapping.autoDetect(t.headers));
      expect(plan.rows.length, 18);
      expect(plan.errorCount, 0);
      expect(plan.marriagePairs({for (var i = 0; i < 18; i++) i}).length, 6);
    });
  });

  group('ImportService', () {
    late Database db;
    late AppState state;

    RawTable family() => tbl(['الاسم', 'الجنس', 'الأب', 'الأم', 'الزوج'], [
          ['سالم', 'ذكر', '', '', 'آمنة'],
          ['آمنة', 'أنثى', '', '', ''],
          ['خالد', 'ذكر', 'سالم', 'آمنة', ''],
        ]);
    final mapping = ColumnMapping({
      ColumnField.name: 0,
      ColumnField.gender: 1,
      ColumnField.father: 2,
      ColumnField.mother: 3,
      ColumnField.spouse: 4,
    });

    setUp(() async {
      db = await openTestDb();
      state = AppState(db);
      await state.load();
      await state.addPerson(const Person(name: 'قديم'));
    });

    tearDown(() => db.close());

    test('الإضافة تُبقي الموجود وتربط الوالدين والزواج', () async {
      final plan = planImport(family(), mapping);
      final r = await ImportService(db)
          .commit(plan, replace: false, skipInvalid: false);
      await state.load();
      expect(r.persons, 3);
      expect(r.marriages, 1);
      expect(state.all.length, 4);
      final khaled = state.all.firstWhere((p) => p.name == 'خالد');
      expect(state.displayName(khaled), 'خالد سالم');
      expect((await state.marriages.getAll()).length, 1);
    });

    test('الاستبدال يحذف الموجود', () async {
      final plan = planImport(family(), mapping);
      await ImportService(db).commit(plan, replace: true, skipInvalid: false);
      await state.load();
      expect(state.all.length, 3);
      expect(state.all.any((p) => p.name == 'قديم'), isFalse);
    });

    test('خطة بها أخطاء ترفض دون تغيير البيانات', () async {
      final plan = planImport(
        tbl(['الاسم', 'الأب'], [
          ['أ', 'غائب'],
        ]),
        ColumnMapping({ColumnField.name: 0, ColumnField.father: 1}),
      );
      await expectLater(
        ImportService(db).commit(plan, replace: true, skipInvalid: false),
        throwsA(isA<ImportFormatException>()),
      );
      await state.load();
      expect(state.all.length, 1);
    });
  });
}
DART_EOF

echo "تم إنشاء ملفات المرحلة 4ب."
