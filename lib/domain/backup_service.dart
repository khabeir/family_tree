import 'package:sqflite/sqflite.dart';

import '../data/repositories/marriage_repository.dart';
import '../data/repositories/person_repository.dart';
import 'backup.dart';

class BackupService {
  BackupService(Database db)
      : _db = db,
        _persons = PersonRepository(db),
        _marriages = MarriageRepository(db);

  final Database _db;
  final PersonRepository _persons;
  final MarriageRepository _marriages;

  Future<String> exportJson() async {
    final persons = await _persons.getAll();
    final marriages = await _marriages.getAll();
    return BackupCodec.encode(persons, marriages);
  }

  /// يستبدل كل البيانات بمحتوى [data] داخل معاملة واحدة:
  /// عند أي فشل يُتراجع عن كل شيء وتبقى البيانات الحالية كما هي.
  Future<void> restore(BackupData data) async {
    final now = DateTime.now().toUtc();
    await _db.transaction((txn) async {
      await txn.delete(MarriageRepository.table);
      await txn.delete(PersonRepository.table);

      final batch = txn.batch();
      // الأشخاص بلا والدين أولاً، ثم الربط، لتجنب ترتيب المفاتيح الأجنبية
      for (final p in data.persons) {
        final map = p
            .copyWith(
              createdAt: p.createdAt ?? now,
              updatedAt: p.updatedAt ?? now,
            )
            .toMap();
        map['father_id'] = null;
        map['mother_id'] = null;
        batch.insert(PersonRepository.table, map);
      }
      for (final p in data.persons) {
        if (p.fatherId == null && p.motherId == null) continue;
        batch.update(
          PersonRepository.table,
          {'father_id': p.fatherId, 'mother_id': p.motherId},
          where: 'id = ?',
          whereArgs: [p.id],
        );
      }
      for (final m in data.marriages) {
        batch.insert(
          MarriageRepository.table,
          m
              .copyWith(
                createdAt: m.createdAt ?? now,
                updatedAt: m.updatedAt ?? now,
              )
              .toMap(),
        );
      }
      await batch.commit(noResult: true);
      await txn.rawUpdate('UPDATE persons SET sort_order = id + (SELECT COALESCE(MAX(sort_order), 0) FROM persons) WHERE sort_order = 0');
    });
  }
}
