import 'dart:io';

import 'package:family_tree/app_state.dart';
import 'package:family_tree/data/database/app_database.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late AppState state;
  late int parent;
  late int c1;
  late int c2;
  late int c3;

  setUp(() async {
    db = await openTestDb();
    state = AppState(db);
    await state.load();
    parent =
        await state.addPerson(const Person(name: 'الأب', gender: Gender.male));
    c1 = await state.addPerson(Person(name: 'أول', fatherId: parent));
    c2 = await state.addPerson(Person(name: 'ثاني', fatherId: parent));
    c3 = await state.addPerson(Person(name: 'ثالث', fatherId: parent));
  });

  tearDown(() => db.close());

  List<int> order() => state.childrenOf(parent).map((p) => p.id!).toList();

  test('الابن الجديد يأتي آخراً (ترتيب الإدخال)', () {
    expect(order(), [c1, c2, c3]);
  });

  test('تحريك للأعلى والأسفل ويُحفظ بعد إعادة التحميل', () async {
    await state.moveChild(parent, c3, -1);
    expect(order(), [c1, c3, c2]);
    await state.moveChild(parent, c3, -1);
    expect(order(), [c3, c1, c2]);
    await state.moveChild(parent, c3, 1);
    expect(order(), [c1, c3, c2]);

    await state.load(); // من قاعدة البيانات
    expect(order(), [c1, c3, c2]);
  });

  test('تحريك الأول للأعلى أو الأخير للأسفل لا يغيّر شيئاً', () async {
    await state.moveChild(parent, c1, -1);
    await state.moveChild(parent, c3, 1);
    expect(order(), [c1, c2, c3]);
  });

  test('تعديل شخص لا يغيّر ترتيبه بين إخوته', () async {
    await state.moveChild(parent, c3, -1);
    final p = state.byId(c2)!;
    await state.updatePerson(p.copyWith(name: 'ثاني معدّل'));
    expect(order(), [c1, c3, c2]);
    expect(state.byId(c2)!.name, 'ثاني معدّل');
  });

  test('الأبناء يظهرون بالترتيب الجديد في كل مكان يُقرأ منه', () async {
    await state.moveChild(parent, c3, -1);
    await state.moveChild(parent, c3, -1);
    expect(order(), [c3, c1, c2]);
    expect(state.childrenOf(parent).first.id, c3);
    // ابن آخر يضاف لاحقاً يأتي في النهاية
    final c4 = await state.addPerson(Person(name: 'رابع', fatherId: parent));
    expect(order().last, c4);
  });

  test('الترحيل من الإصدار 1: sort_order = id', () async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('ft_migration');
    final path = '${dir.path}/t.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) => AppDatabase.migrations[0](d),
      ),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await v1.insert('persons', {
      'name': 'أ',
      'gender': 'male',
      'created_at': now,
      'updated_at': now,
    });
    await v1.insert('persons', {
      'name': 'ب',
      'gender': 'male',
      'created_at': now,
      'updated_at': now,
    });
    await v1.close();

    final v2 = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    final rows = await v2.query('persons', orderBy: 'id');
    expect(rows.map((r) => r['sort_order']).toList(),
        rows.map((r) => r['id']).toList());
    expect(await v2.getVersion(), AppDatabase.currentVersion);
    await v2.close();
    dir.deleteSync(recursive: true);
  });
}
