import 'package:sqflite/sqflite.dart';

import '../models/marriage.dart';

class MarriageRepository {
  MarriageRepository(this._db);

  final Database _db;
  static const String table = 'marriages';

  Future<int> insert(Marriage marriage) async {
    final now = DateTime.now().toUtc();
    final map = marriage.copyWith(createdAt: now, updatedAt: now).toMap()
      ..remove('id');
    return _db.insert(table, map);
  }

  Future<bool> update(Marriage marriage) async {
    final id = marriage.id;
    if (id == null) {
      throw ArgumentError('لا يمكن تعديل علاقة بلا معرّف');
    }
    final map = marriage.copyWith(updatedAt: DateTime.now().toUtc()).toMap()
      ..remove('id')
      ..remove('created_at');
    final count =
        await _db.update(table, map, where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<bool> delete(int id) async {
    final count = await _db.delete(table, where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<Marriage?> getById(int id) async {
    final rows =
        await _db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Marriage.fromMap(rows.first);
  }

  Future<List<Marriage>> getAll() async {
    final rows = await _db.query(table, orderBy: 'id');
    return rows.map(Marriage.fromMap).toList();
  }

  Future<List<Marriage>> getForPerson(int personId) async {
    final rows = await _db.query(
      table,
      where: 'person1_id = ? OR person2_id = ?',
      whereArgs: [personId, personId],
      orderBy: 'start_date, id',
    );
    return rows.map(Marriage.fromMap).toList();
  }

  /// كل العلاقات بين شخصين بغض النظر عن ترتيبهما.
  Future<List<Marriage>> findBetween(int a, int b) async {
    final rows = await _db.query(
      table,
      where: '(person1_id = ? AND person2_id = ?) OR '
          '(person1_id = ? AND person2_id = ?)',
      whereArgs: [a, b, b, a],
    );
    return rows.map(Marriage.fromMap).toList();
  }
}
