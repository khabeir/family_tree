import 'package:sqflite/sqflite.dart';

import '../models/person.dart';

/// وصول مباشر إلى جدول الأشخاص. لا يحتوي قواعد أعمال (انظر FamilyService).
class PersonRepository {
  PersonRepository(this._db);

  final Database _db;
  static const String table = 'persons';

  Future<int> insert(Person person) async {
    final now = DateTime.now().toUtc();
    final map = person.copyWith(createdAt: now, updatedAt: now).toMap()
      ..remove('id');
    return _db.insert(table, map);
  }

  Future<bool> update(Person person) async {
    final id = person.id;
    if (id == null) {
      throw ArgumentError('لا يمكن تعديل شخص بلا معرّف');
    }
    final map = person.copyWith(updatedAt: DateTime.now().toUtc()).toMap()
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

  Future<Person?> getById(int id) async {
    final rows =
        await _db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Person.fromMap(rows.first);
  }

  Future<List<Person>> getAll() async {
    final rows = await _db.query(table, orderBy: 'name COLLATE NOCASE, id');
    return rows.map(Person.fromMap).toList();
  }

  Future<List<Person>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return getAll();
    }
    final escaped = q
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final rows = await _db.query(
      table,
      where: "name LIKE ? ESCAPE '\\'",
      whereArgs: ['%$escaped%'],
      orderBy: 'name COLLATE NOCASE, id',
    );
    return rows.map(Person.fromMap).toList();
  }

  Future<List<Person>> getChildren(int parentId) async {
    final rows = await _db.query(
      table,
      where: 'father_id = ? OR mother_id = ?',
      whereArgs: [parentId, parentId],
      orderBy: 'birth_date, id',
    );
    return rows.map(Person.fromMap).toList();
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (result.first['c'] as int?) ?? 0;
  }
}
