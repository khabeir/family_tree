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
    if (person.sortOrder <= 0) {
      // الشخص الجديد يأتي آخر إخوته
      final r = await _db
          .rawQuery('SELECT COALESCE(MAX(sort_order), 0) AS m FROM $table');
      map['sort_order'] = ((r.first['m'] as int?) ?? 0) + 1;
    }
    return _db.insert(table, map);
  }

  Future<bool> update(Person person) async {
    final id = person.id;
    if (id == null) {
      throw ArgumentError('لا يمكن تعديل شخص بلا معرّف');
    }
    // التعديل لا يغيّر الترتيب بين الإخوة
    final map = person.copyWith(updatedAt: DateTime.now().toUtc()).toMap()
      ..remove('id')
      ..remove('created_at')
      ..remove('sort_order');
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
      orderBy: 'sort_order, id',
    );
    return rows.map(Person.fromMap).toList();
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (result.first['c'] as int?) ?? 0;
  }

  /// يبدّل قيمتي الترتيب لشخصين (لتحريك ابن خطوة للأعلى أو للأسفل).
  Future<void> swapSortOrder(int a, int b) async {
    await _db.transaction((txn) async {
      final ra = await txn.query(table,
          columns: ['sort_order'], where: 'id = ?', whereArgs: [a]);
      final rb = await txn.query(table,
          columns: ['sort_order'], where: 'id = ?', whereArgs: [b]);
      if (ra.isEmpty || rb.isEmpty) return;
      final oa = ra.first['sort_order'] as int;
      final ob = rb.first['sort_order'] as int;
      await txn.update(table, {'sort_order': ob},
          where: 'id = ?', whereArgs: [a]);
      await txn.update(table, {'sort_order': oa},
          where: 'id = ?', whereArgs: [b]);
    });
  }
}
