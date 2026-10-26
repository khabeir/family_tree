import 'package:family_tree/data/database/app_database.dart';
import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/marriage_repository.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late PersonRepository persons;
  late MarriageRepository marriages;

  setUp(() async {
    db = await openTestDb();
    persons = PersonRepository(db);
    marriages = MarriageRepository(db);
  });

  tearDown(() => db.close());

  test('المخطط ينشأ بالإصدار الحالي', () async {
    expect(await db.getVersion(), AppDatabase.currentVersion);
    final tables = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final names = tables.map((r) => r['name']).toSet();
    expect(names, containsAll(['persons', 'marriages']));
  });

  test('إضافة وقراءة شخص', () async {
    final id = await persons.insert(const Person(
      name: 'شخص تجريبي',
      gender: Gender.male,
      birthDate: '1980-01-01',
      notes: 'ملاحظة',
    ));
    final loaded = await persons.getById(id);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'شخص تجريبي');
    expect(loaded.gender, Gender.male);
    expect(loaded.birthDate, '1980-01-01');
    expect(loaded.notes, 'ملاحظة');
    expect(loaded.createdAt, isNotNull);
    expect(await persons.count(), 1);
  });

  test('تعديل شخص يغيّر الحقول ويمسح القيم الاختيارية', () async {
    final id = await persons.insert(
        const Person(name: 'قبل', birthDate: '1990-05-05', notes: 'x'));
    final original = (await persons.getById(id))!;
    final ok = await persons.update(
        original.copyWith(name: 'بعد', birthDate: null, notes: null));
    expect(ok, isTrue);
    final updated = (await persons.getById(id))!;
    expect(updated.name, 'بعد');
    expect(updated.birthDate, isNull);
    expect(updated.notes, isNull);
    expect(updated.createdAt, original.createdAt);
  });

  test('تعديل شخص غير موجود يعيد false', () async {
    expect(await persons.update(const Person(id: 999, name: 'لا أحد')), isFalse);
  });

  test('حذف الأب يفرغ father_id عند الابن', () async {
    final fatherId =
        await persons.insert(const Person(name: 'أب', gender: Gender.male));
    final childId =
        await persons.insert(Person(name: 'ابن', fatherId: fatherId));
    expect(await persons.delete(fatherId), isTrue);
    expect((await persons.getById(childId))!.fatherId, isNull);
  });

  test('حذف شخص يحذف علاقات زواجه', () async {
    final a = await persons.insert(const Person(name: 'أ'));
    final b = await persons.insert(const Person(name: 'ب'));
    await marriages.insert(Marriage(person1Id: a, person2Id: b));
    await persons.delete(a);
    expect(await marriages.getAll(), isEmpty);
  });

  test('قيود المفاتيح الأجنبية مفعّلة', () async {
    expect(
      () => persons.insert(const Person(name: 'يتيم', fatherId: 12345)),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('البحث بالاسم مع تهريب % و _', () async {
    await persons.insert(const Person(name: 'محمد علي'));
    await persons.insert(const Person(name: 'علي حسن'));
    await persons.insert(const Person(name: '100% اسم'));
    expect((await persons.search('علي')).length, 2);
    expect((await persons.search('%')).length, 1);
    expect((await persons.search('_')).length, 0);
    expect((await persons.search('')).length, 3);
  });

  test('getChildren يعيد أبناء الأب والأم', () async {
    final f = await persons.insert(const Person(name: 'أب', gender: Gender.male));
    final m =
        await persons.insert(const Person(name: 'أم', gender: Gender.female));
    await persons.insert(Person(name: 'ابن 1', fatherId: f, motherId: m));
    await persons.insert(Person(name: 'ابن 2', motherId: m));
    expect((await persons.getChildren(f)).length, 1);
    expect((await persons.getChildren(m)).length, 2);
  });

  test('CRUD الزواج وfindBetween بالترتيبين', () async {
    final a = await persons.insert(const Person(name: 'أ'));
    final b = await persons.insert(const Person(name: 'ب'));
    final id = await marriages.insert(
        Marriage(person1Id: a, person2Id: b, startDate: '2010-01-01'));
    expect((await marriages.findBetween(a, b)).length, 1);
    expect((await marriages.findBetween(b, a)).length, 1);
    final m = (await marriages.getById(id))!;
    await marriages.update(m.copyWith(status: MarriageStatus.divorced));
    expect((await marriages.getById(id))!.status, MarriageStatus.divorced);
    expect((await marriages.getForPerson(a)).length, 1);
    expect(await marriages.delete(id), isTrue);
    expect(await marriages.getById(id), isNull);
  });
}
