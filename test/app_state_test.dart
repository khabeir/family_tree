import 'package:family_tree/app_state.dart';
import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/family_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openTestDb();
    state = AppState(db);
    await state.load();
  });

  tearDown(() => db.close());

  test('الإضافة تحدّث القائمة المخزنة وتُشعر المستمعين', () async {
    var notified = 0;
    state.addListener(() => notified++);
    final id = await state.addPerson(const Person(name: 'أحمد'));
    expect(state.all.length, 1);
    expect(state.byId(id)!.name, 'أحمد');
    expect(notified, greaterThan(0));
  });

  test('البحث يتجاهل فروق الهمزة والتشكيل', () async {
    await state.addPerson(const Person(name: 'أحمد علي'));
    await state.addPerson(const Person(name: 'خالد'));
    expect(state.search('احمد').length, 1);
    expect(state.search('').length, 2);
    expect(state.search('زيد'), isEmpty);
  });

  test('الأبناء وتسمية الوالدين', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final m = await state
        .addPerson(const Person(name: 'الأم', gender: Gender.female));
    final c1 = await state.addPerson(
        Person(name: 'ب', fatherId: f, motherId: m, birthDate: '2010-01-01'));
    await state.addPerson(
        Person(name: 'أ', fatherId: f, birthDate: '2005-01-01'));
    final kids = state.childrenOf(f);
    expect(kids.map((e) => e.name).toList(), ['أ', 'ب']);
    expect(state.parentsLabel(state.byId(c1)!), 'الأب: الأب • الأم: الأم');
  });

  test('الحذف يفرّغ الوالد عند الابن ويحدّث الحالة', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final c = await state.addPerson(Person(name: 'ابن', fatherId: f));
    expect(await state.deletePerson(f), isTrue);
    expect(state.byId(f), isNull);
    expect(state.byId(c)!.fatherId, isNull);
  });

  test('أخطاء التحقق تنتقل للواجهة ولا تغيّر الحالة', () async {
    await expectLater(state.addPerson(const Person(name: '')),
        throwsA(isA<FamilyValidationException>()));
    expect(state.all, isEmpty);
  });

  test('الزواج عبر الحالة', () async {
    final a = await state.addPerson(const Person(name: 'أ'));
    final b = await state.addPerson(const Person(name: 'ب'));
    final id = await state.addMarriage(Marriage(person1Id: a, person2Id: b));
    expect((await state.marriagesOf(a)).length, 1);
    expect(await state.deleteMarriage(id), isTrue);
    expect(await state.marriagesOf(a), isEmpty);
  });
}
