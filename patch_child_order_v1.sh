#!/usr/bin/env bash
# شجرة عائلتي - ترتيب الأبناء حسب العمر بأزرار تحريك للأعلى/الأسفل
#  - عمود sort_order (ترحيل قاعدة البيانات إلى الإصدار 2؛ القيمة الأولية = ترتيب الإدخال الحالي)
#  - أسهم في صفحة الأب/الأم لتحريك كل ابن، ويُحفظ الترتيب
#  - يلتزم به: التفاصيل، الشجرة، الخريطة الذهنية، الإخوة، النسخ الاحتياطي، الاستيراد
# شغّله من جذر المستودع: bash patch_child_order_v1.sh
set -euo pipefail

req() { test -f "$1" || { echo "ملف ناقص: $1 (طبّق المراحل السابقة أولاً)"; exit 1; }; }
req lib/data/models/person.dart
req lib/data/repositories/person_repository.dart
req lib/data/database/app_database.dart
req lib/domain/backup_service.dart
req lib/app_state.dart
req lib/domain/family_tree_index.dart
req lib/domain/mind_map.dart
req lib/domain/relations.dart
req lib/ui/person_detail_screen.dart

if grep -q "sortOrder" lib/data/models/person.dart; then echo "مطبّق سابقاً"; exit 0; fi

# ───────────────────────── 1) نموذج الشخص: حقل sortOrder ─────────────────────────
cat > lib/data/models/person.dart <<'DART_EOF'
const Object _unset = Object();

enum Gender {
  male,
  female,
  unknown;

  static Gender parse(String? value) => Gender.values.firstWhere(
        (g) => g.name == value,
        orElse: () => Gender.unknown,
      );
}

class Person {
  const Person({
    this.id,
    required this.name,
    this.gender = Gender.unknown,
    this.fatherId,
    this.motherId,
    this.birthDate,
    this.deathDate,
    this.notes,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final Gender gender;
  final int? fatherId;
  final int? motherId;

  /// تاريخ بصيغة yyyy-MM-dd
  final String? birthDate;
  final String? deathDate;
  final String? notes;

  /// ترتيب الظهور بين الإخوة (الأصغر أولاً). 0 = لم يُعيَّن بعد (يُعيَّن عند الحفظ).
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Person copyWith({
    int? id,
    String? name,
    Gender? gender,
    Object? fatherId = _unset,
    Object? motherId = _unset,
    Object? birthDate = _unset,
    Object? deathDate = _unset,
    Object? notes = _unset,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      fatherId: identical(fatherId, _unset) ? this.fatherId : fatherId as int?,
      motherId: identical(motherId, _unset) ? this.motherId : motherId as int?,
      birthDate:
          identical(birthDate, _unset) ? this.birthDate : birthDate as String?,
      deathDate:
          identical(deathDate, _unset) ? this.deathDate : deathDate as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'gender': gender.name,
        'father_id': fatherId,
        'mother_id': motherId,
        'birth_date': birthDate,
        'death_date': deathDate,
        'notes': notes,
        'sort_order': sortOrder,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  factory Person.fromMap(Map<String, Object?> map) => Person(
        id: map['id'] as int?,
        name: map['name'] as String,
        gender: Gender.parse(map['gender'] as String?),
        fatherId: map['father_id'] as int?,
        motherId: map['mother_id'] as int?,
        birthDate: map['birth_date'] as String?,
        deathDate: map['death_date'] as String?,
        notes: map['notes'] as String?,
        sortOrder: map['sort_order'] is int ? map['sort_order'] as int : 0,
        createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      );

  @override
  String toString() => 'Person(id: $id, name: $name)';
}
DART_EOF

# ───────────────────────── 2) مستودع الأشخاص ─────────────────────────
cat > lib/data/repositories/person_repository.dart <<'DART_EOF'
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
DART_EOF

# ───────────────────────── 3) ترحيل قاعدة البيانات إلى الإصدار 2 ─────────────────────────
v2_block="$(mktemp)"
cat > "$v2_block" <<'DART_EOF'
  static Future<void> _v2(Database db) async {
    // ترتيب الأبناء: القيمة الأولية = المعرّف أي ترتيب الإدخال الحالي
    await db.execute(
      'ALTER TABLE persons ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('UPDATE persons SET sort_order = id');
    await db.execute('CREATE INDEX idx_persons_sort ON persons(sort_order)');
  }

DART_EOF
db=lib/data/database/app_database.dart
awk -v blockfile="$v2_block" '
  /^  static Future<void> _v1\(Database db\) async \{$/ { while ((getline l < blockfile) > 0) print l }
  { print }
' "$db" > "$db.new"
mv "$db.new" "$db"
rm -f "$v2_block"
sed -i 's/static final List<Migration> migrations = \[_v1\];/static final List<Migration> migrations = [_v1, _v2];/' "$db"
grep -q "migrations = \[_v1, _v2\];" "$db"
grep -q "static Future<void> _v2(Database db) async {" "$db"

# ───────────────────────── 4) الاستعادة والاستيراد: تطبيع الترتيب ─────────────────────────
norm="      await txn.rawUpdate('UPDATE persons SET sort_order = id + (SELECT COALESCE(MAX(sort_order), 0) FROM persons) WHERE sort_order = 0');"

bs=lib/domain/backup_service.dart
awk -v ins="$norm" '
  { print }
  $0 == "      await batch.commit(noResult: true);" { print ins }
' "$bs" > "$bs.new"
mv "$bs.new" "$bs"
grep -q "SET sort_order = id +" "$bs"

is=lib/domain/import/import_service.dart
if [ -f "$is" ]; then
  awk -v ins="$norm" '
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (lines[i] == "    });" && lines[i + 1] == "    return ImportResult(indices.length, pairs.length);") print ins
        print lines[i]
      }
    }
  ' "$is" > "$is.new"
  mv "$is.new" "$is"
  grep -q "SET sort_order = id +" "$is"
fi

# ───────────────────────── 5) AppState: ترتيب الأبناء وتحريكهم ─────────────────────────
as=lib/app_state.dart
as_block="$(mktemp)"
cat > "$as_block" <<'DART_EOF'
  List<Person> childrenOf(int id) {
    final list =
        _all.where((p) => p.fatherId == id || p.motherId == id).toList();
    list.sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.id!.compareTo(b.id!);
    });
    return list;
  }

  /// يحرّك الابن [childId] خطوة ضمن أبناء [parentId]: [delta] = -1 للأعلى، +1 للأسفل.
  Future<void> moveChild(int parentId, int childId, int delta) async {
    final list = childrenOf(parentId);
    final i = list.indexWhere((c) => c.id == childId);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    await persons.swapSortOrder(list[i].id!, list[j].id!);
    await load();
  }
DART_EOF
awk -v blockfile="$as_block" '
  /^  List<Person> childrenOf\(int id\) \{$/ {
    while ((getline l < blockfile) > 0) print l
    skip = 1; next
  }
  skip && /^  }$/ { skip = 0; next }
  !skip { print }
' "$as" > "$as.new"
mv "$as.new" "$as"
rm -f "$as_block"
grep -q "Future<void> moveChild(int parentId, int childId, int delta)" "$as"
test "$(grep -c 'List<Person> childrenOf(int id)' "$as")" = "1"

# ───────────────────────── 6) الشجرة والخريطة والإخوة تلتزم بالترتيب ─────────────────────────
sed -i 's/list\.sort((a, b) => a\.id!\.compareTo(b\.id!));/list.sort((a, b) { final c = a.sortOrder.compareTo(b.sortOrder); return c != 0 ? c : a.id!.compareTo(b.id!); });/' lib/domain/family_tree_index.dart
grep -q "a.sortOrder.compareTo(b.sortOrder)" lib/domain/family_tree_index.dart

sed -i -e '/for (final l in _kids.values) {/{' -e 'n' -e 's|l\.sort((a, b) => a\.id!\.compareTo(b\.id!));|l.sort((a, b) { final c = a.sortOrder.compareTo(b.sortOrder); return c != 0 ? c : a.id!.compareTo(b.id!); });|' -e '}' lib/domain/mind_map.dart
grep -q "a.sortOrder.compareTo(b.sortOrder)" lib/domain/mind_map.dart

sed -i 's|    return k != 0 ? k : a.person.id!.compareTo(b.person.id!);|    if (k != 0) return k;\n    final s = a.person.sortOrder.compareTo(b.person.sortOrder);\n    return s != 0 ? s : a.person.id!.compareTo(b.person.id!);|' lib/domain/relations.dart
grep -q "a.person.sortOrder.compareTo" lib/domain/relations.dart

# ───────────────────────── 7) صفحة التفاصيل: أسهم تحريك الأبناء ─────────────────────────
d=lib/ui/person_detail_screen.dart
child_tile="$(mktemp)"
cat > "$child_tile" <<'DART_EOF'
  /// ابن مع أسهم تحريك للأعلى/الأسفل (الأكبر سناً في الأعلى).
  Widget _childTile(
    BuildContext context,
    Person parent,
    List<Person> kids,
    int i,
  ) {
    final c = kids[i];
    final canReorder = kids.length > 1;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PersonAvatar(gender: c.gender),
      title: Text(state.displayName(c)),
      subtitle: canReorder
          ? Text('الترتيب: ' + (i + 1).toString() + ' من ' + kids.length.toString())
          : null,
      onTap: () => _open(context, c.id!),
      trailing: canReorder
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تحريك للأعلى',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0
                      ? null
                      : () => state.moveChild(parent.id!, c.id!, -1),
                ),
                IconButton(
                  tooltip: 'تحريك للأسفل',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == kids.length - 1
                      ? null
                      : () => state.moveChild(parent.id!, c.id!, 1),
                ),
              ],
            )
          : const Icon(Icons.chevron_left),
    );
  }

DART_EOF
awk -v blockfile="$child_tile" '
  /^  Widget _marriageTile\(BuildContext context, Person p, Marriage m\) \{$/ {
    while ((getline l < blockfile) > 0) print l
  }
  { print }
' "$d" > "$d.new"
mv "$d.new" "$d"
rm -f "$child_tile"
sed -i 's|for (final c in children) _personTile(context, c),|for (var i = 0; i < children.length; i++)\n                    _childTile(context, p, children, i),|' "$d"
grep -q "Widget _childTile(" "$d"
grep -q "_childTile(context, p, children, i)" "$d"

# ───────────────────────── 8) اختبارات ─────────────────────────
cat > test/child_order_test.dart <<'DART_EOF'
import 'dart:io';

import 'package:family_tree/app_state.dart';
import 'package:family_tree/data/database/app_database.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late AppState state;
  late int parent;
  late int c1;
  late int c2;
  late int c3;

  setUp(() async {
    db = await openTestDb();
    state = AppState(db);
    await state.load();
    parent =
        await state.addPerson(const Person(name: 'الأب', gender: Gender.male));
    c1 = await state.addPerson(Person(name: 'أول', fatherId: parent));
    c2 = await state.addPerson(Person(name: 'ثاني', fatherId: parent));
    c3 = await state.addPerson(Person(name: 'ثالث', fatherId: parent));
  });

  tearDown(() => db.close());

  List<int> order() => state.childrenOf(parent).map((p) => p.id!).toList();

  test('الابن الجديد يأتي آخراً (ترتيب الإدخال)', () {
    expect(order(), [c1, c2, c3]);
  });

  test('تحريك للأعلى والأسفل ويُحفظ بعد إعادة التحميل', () async {
    await state.moveChild(parent, c3, -1);
    expect(order(), [c1, c3, c2]);
    await state.moveChild(parent, c3, -1);
    expect(order(), [c3, c1, c2]);
    await state.moveChild(parent, c3, 1);
    expect(order(), [c1, c3, c2]);

    await state.load(); // من قاعدة البيانات
    expect(order(), [c1, c3, c2]);
  });

  test('تحريك الأول للأعلى أو الأخير للأسفل لا يغيّر شيئاً', () async {
    await state.moveChild(parent, c1, -1);
    await state.moveChild(parent, c3, 1);
    expect(order(), [c1, c2, c3]);
  });

  test('تعديل شخص لا يغيّر ترتيبه بين إخوته', () async {
    await state.moveChild(parent, c3, -1);
    final p = state.byId(c2)!;
    await state.updatePerson(p.copyWith(name: 'ثاني معدّل'));
    expect(order(), [c1, c3, c2]);
    expect(state.byId(c2)!.name, 'ثاني معدّل');
  });

  test('الأبناء يظهرون بالترتيب الجديد في كل مكان يُقرأ منه', () async {
    await state.moveChild(parent, c3, -1);
    await state.moveChild(parent, c3, -1);
    expect(order(), [c3, c1, c2]);
    expect(state.childrenOf(parent).first.id, c3);
    // ابن آخر يضاف لاحقاً يأتي في النهاية
    final c4 = await state.addPerson(Person(name: 'رابع', fatherId: parent));
    expect(order().last, c4);
  });

  test('الترحيل من الإصدار 1: sort_order = id', () async {
    sqfliteFfiInit();
    final dir = Directory.systemTemp.createTempSync('ft_migration');
    final path = '${dir.path}/t.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) => AppDatabase.migrations[0](d),
      ),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await v1.insert('persons', {
      'name': 'أ',
      'gender': 'male',
      'created_at': now,
      'updated_at': now,
    });
    await v1.insert('persons', {
      'name': 'ب',
      'gender': 'male',
      'created_at': now,
      'updated_at': now,
    });
    await v1.close();

    final v2 = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    final rows = await v2.query('persons', orderBy: 'id');
    expect(rows.map((r) => r['sort_order']).toList(),
        rows.map((r) => r['id']).toList());
    expect(await v2.getVersion(), AppDatabase.currentVersion);
    await v2.close();
    dir.deleteSync(recursive: true);
  });
}
DART_EOF

echo "تم: ترتيب الأبناء بأسهم التحريك (قاعدة البيانات الإصدار 2)."
