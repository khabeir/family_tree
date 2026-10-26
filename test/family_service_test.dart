import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/marriage_repository.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:family_tree/domain/family_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late PersonRepository persons;
  late MarriageRepository marriages;
  late FamilyService service;

  setUp(() async {
    db = await openTestDb();
    persons = PersonRepository(db);
    marriages = MarriageRepository(db);
    service = FamilyService(persons, marriages);
  });

  tearDown(() => db.close());

  final throwsValidation = throwsA(isA<FamilyValidationException>());

  group('الأشخاص', () {
    test('يرفض الاسم الفارغ ويُنظّف المسافات', () async {
      await expectLater(service.addPerson(const Person(name: '   ')),
          throwsValidation);
      final id = await service.addPerson(const Person(name: '  أحمد   علي '));
      expect((await persons.getById(id))!.name, 'أحمد علي');
    });

    test('يرفض تاريخاً غير صالح وتاريخ وفاة قبل الميلاد', () async {
      await expectLater(
          service.addPerson(const Person(name: 'س', birthDate: '2020-02-31')),
          throwsValidation);
      await expectLater(
          service.addPerson(const Person(name: 'س', birthDate: '1990/01/01')),
          throwsValidation);
      await expectLater(
          service.addPerson(const Person(
              name: 'س', birthDate: '2000-01-01', deathDate: '1999-01-01')),
          throwsValidation);
    });

    test('يرفض أباً أنثى وأماً ذكراً وأباً غير موجود', () async {
      final f = await service
          .addPerson(const Person(name: 'ف', gender: Gender.female));
      final m =
          await service.addPerson(const Person(name: 'م', gender: Gender.male));
      await expectLater(
          service.addPerson(Person(name: 'ابن', fatherId: f)), throwsValidation);
      await expectLater(
          service.addPerson(Person(name: 'ابن', motherId: m)), throwsValidation);
      await expectLater(service.addPerson(const Person(name: 'ابن', fatherId: 999)),
          throwsValidation);
    });

    test('يسمح بأب مجهول الجنس', () async {
      final f = await service.addPerson(const Person(name: 'أب'));
      final c = await service.addPerson(Person(name: 'ابن', fatherId: f));
      expect((await persons.getById(c))!.fatherId, f);
    });

    test('يرفض أن يكون الشخص أباً لنفسه', () async {
      final id = await service
          .addPerson(const Person(name: 'أ', gender: Gender.male));
      final p = (await persons.getById(id))!;
      await expectLater(
          service.updatePerson(p.copyWith(fatherId: id)), throwsValidation);
    });

    test('يرفض حلقة النسب (جد يصبح ابناً لحفيده)', () async {
      final a = await service
          .addPerson(const Person(name: 'جد', gender: Gender.male));
      final b = await service
          .addPerson(Person(name: 'أب', gender: Gender.male, fatherId: a));
      final c = await service.addPerson(Person(name: 'حفيد', fatherId: b));
      final grandpa = (await persons.getById(a))!;
      await expectLater(
          service.updatePerson(grandpa.copyWith(fatherId: c)), throwsValidation);
    });

    test('يرفض تغيير الجنس إذا تعارض مع دوره كأب أو أم', () async {
      final f = await service
          .addPerson(const Person(name: 'أب', gender: Gender.male));
      await service.addPerson(Person(name: 'ابن', fatherId: f));
      final father = (await persons.getById(f))!;
      await expectLater(
          service.updatePerson(father.copyWith(gender: Gender.female)),
          throwsValidation);
    });

    test('تعديل شخص غير موجود يعيد false', () async {
      expect(await service.updatePerson(const Person(id: 404, name: 'س')),
          isFalse);
    });

    test('تعديل صالح ينجح', () async {
      final id = await service.addPerson(const Person(name: 'قديم'));
      final ok = await service.updatePerson(
          (await persons.getById(id))!.copyWith(name: 'جديد'));
      expect(ok, isTrue);
      expect((await persons.getById(id))!.name, 'جديد');
    });
  });

  group('الزواج', () {
    late int a;
    late int b;
    setUp(() async {
      a = await service.addPerson(const Person(name: 'أ'));
      b = await service.addPerson(const Person(name: 'ب'));
    });

    test('يرفض زواج الشخص من نفسه', () async {
      await expectLater(
          service.addMarriage(Marriage(person1Id: a, person2Id: a)),
          throwsValidation);
    });

    test('يرفض شخصاً غير موجود', () async {
      await expectLater(
          service.addMarriage(Marriage(person1Id: a, person2Id: 999)),
          throwsValidation);
    });

    test('يرفض زواجاً قائماً مكرراً بالترتيبين', () async {
      await service.addMarriage(Marriage(person1Id: a, person2Id: b));
      await expectLater(
          service.addMarriage(Marriage(person1Id: a, person2Id: b)),
          throwsValidation);
      await expectLater(
          service.addMarriage(Marriage(person1Id: b, person2Id: a)),
          throwsValidation);
    });

    test('يسمح بزواج جديد بعد طلاق', () async {
      final id = await service.addMarriage(Marriage(
          person1Id: a, person2Id: b, status: MarriageStatus.divorced));
      expect(id, isPositive);
      await service.addMarriage(Marriage(person1Id: a, person2Id: b));
      expect((await marriages.findBetween(a, b)).length, 2);
    });

    test('يرفض انتهاء قبل البداية', () async {
      await expectLater(
          service.addMarriage(Marriage(
              person1Id: a,
              person2Id: b,
              startDate: '2020-01-01',
              endDate: '2019-01-01',
              status: MarriageStatus.divorced)),
          throwsValidation);
    });

    test('تعديل زواج قائم لنفسه لا يُعدّ تكراراً', () async {
      final id =
          await service.addMarriage(Marriage(person1Id: a, person2Id: b));
      final m = (await marriages.getById(id))!;
      expect(await service.updateMarriage(m.copyWith(notes: 'تحديث')), isTrue);
    });
  });
}
