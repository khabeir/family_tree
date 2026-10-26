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

  test('الاسم المعروض ثلاثي/رباعي بسلسلة الآباء ويتوقف عند 4 أجزاء', () async {
    final g3 = await state
        .addPerson(const Person(name: 'حسن', gender: Gender.male));
    final g2 = await state.addPerson(
        Person(name: 'علي', gender: Gender.male, fatherId: g3));
    final g1 = await state.addPerson(
        Person(name: 'محمد', gender: Gender.male, fatherId: g2));
    final me = await state.addPerson(Person(name: 'أحمد', fatherId: g1));
    final kid = await state.addPerson(Person(name: 'سارة', fatherId: me));

    expect(state.displayName(state.byId(g3)!), 'حسن');
    expect(state.displayName(state.byId(g1)!), 'محمد علي حسن');
    expect(state.displayName(state.byId(me)!), 'أحمد محمد علي حسن');
    // الابن الخامس في السلسلة: 4 أجزاء فقط
    expect(state.displayName(state.byId(kid)!), 'سارة أحمد محمد علي');
  });

  test('تمييز الأسماء المكررة بالآباء المختلفين', () async {
    final f1 = await state
        .addPerson(const Person(name: 'علي', gender: Gender.male));
    final f2 = await state
        .addPerson(const Person(name: 'حسن', gender: Gender.male));
    final a = await state.addPerson(Person(name: 'محمد', fatherId: f1));
    final b = await state.addPerson(Person(name: 'محمد', fatherId: f2));
    expect(state.displayName(state.byId(a)!), 'محمد علي');
    expect(state.displayName(state.byId(b)!), 'محمد حسن');
  });

  test('معاينة الاسم أثناء الإدخال', () async {
    final f = await state
        .addPerson(const Person(name: 'علي', gender: Gender.male));
    expect(state.composeName('  خالد ', f), 'خالد علي');
    expect(state.composeName('خالد', null), 'خالد');
  });

  test('البحث يعمل على الاسم الكامل ويتجاهل الهمزة والتشكيل', () async {
    final f = await state
        .addPerson(const Person(name: 'علي', gender: Gender.male));
    await state.addPerson(Person(name: 'أحمد', fatherId: f));
    await state.addPerson(const Person(name: 'خالد'));
    expect(state.search('احمد').length, 1);
    expect(state.search('احمد علي').length, 1);
    expect(state.search('').length, 3);
    expect(state.search('زيد'), isEmpty);
  });

  test('الأبناء وتسمية الوالدين', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final m = await state
        .addPerson(const Person(name: 'الأم', gender: Gender.female));
    final c1 = await state.addPerson(Person(name: 'ب', fatherId: f, motherId: m));
    await state.addPerson(Person(name: 'أ', fatherId: f));
    expect(state.childrenOf(f).length, 2);
    expect(state.parentsLabel(state.byId(c1)!), 'الأب: الأب • الأم: الأم');
  });

  test('الحذف يفرّغ الوالد عند الابن ويحدّث الحالة', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final c = await state.addPerson(Person(name: 'ابن', fatherId: f));
    expect(await state.deletePerson(f), isTrue);
    expect(state.byId(f), isNull);
    expect(state.byId(c)!.fatherId, isNull);
    expect(state.displayName(state.byId(c)!), 'ابن');
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
