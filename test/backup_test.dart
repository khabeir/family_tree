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
