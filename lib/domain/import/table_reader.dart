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
