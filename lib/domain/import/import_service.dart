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
