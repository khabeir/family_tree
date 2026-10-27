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
