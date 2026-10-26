#!/usr/bin/env bash
# شجرة عائلتي - المرحلة 1
# شغّله من جذر المستودع: bash setup_phase1.sh
set -euo pipefail

mkdir -p lib/data/models lib/data/database lib/data/repositories lib/domain \
         test/support .github/workflows

# ───────────────────────── pubspec.yaml ─────────────────────────
cat > pubspec.yaml <<'PUBSPEC_EOF'
name: family_tree
description: شجرة عائلتي - تطبيق شخصي لإدارة شجرة العائلة دون إنترنت.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  sqflite: ^2.3.3+1
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  sqflite_common_ffi: ^2.3.3

flutter:
  uses-material-design: true
PUBSPEC_EOF

cat > analysis_options.yaml <<'ANALYSIS_EOF'
include: package:flutter_lints/flutter.yaml
ANALYSIS_EOF

cat > .gitignore <<'GITIGNORE_EOF'
.dart_tool/
.packages
.pub-cache/
.pub/
build/
.flutter-plugins
.flutter-plugins-dependencies
pubspec.lock.bak
*.iml
.idea/
.vscode/
local.properties
key.properties
*.jks
*.keystore
.env
GITIGNORE_EOF

# ───────────────────────── GitHub Actions ─────────────────────────
cat > .github/workflows/build.yml <<'WORKFLOW_EOF'
name: Build APK

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.24.5'
          cache: true

      - name: SQLite for tests
        run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev

      - name: Create Android platform if missing
        run: |
          if [ ! -d android ]; then
            flutter create --platforms=android --org com.familytree.personal --project-name family_tree .
            rm -f test/widget_test.dart
          fi

      - run: flutter --version
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release

      - uses: actions/upload-artifact@v4
        with:
          name: family-tree-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          if-no-files-found: error
WORKFLOW_EOF

# ───────────────────────── النماذج ─────────────────────────
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
        createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      );

  @override
  String toString() => 'Person(id: $id, name: $name)';
}
DART_EOF

cat > lib/data/models/marriage.dart <<'DART_EOF'
const Object _unset = Object();

enum MarriageStatus {
  married,
  divorced,
  widowed;

  static MarriageStatus parse(String? value) => MarriageStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => MarriageStatus.married,
      );
}

class Marriage {
  const Marriage({
    this.id,
    required this.person1Id,
    required this.person2Id,
    this.startDate,
    this.endDate,
    this.status = MarriageStatus.married,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int person1Id;
  final int person2Id;
  final String? startDate;
  final String? endDate;
  final MarriageStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Marriage copyWith({
    int? id,
    int? person1Id,
    int? person2Id,
    Object? startDate = _unset,
    Object? endDate = _unset,
    MarriageStatus? status,
    Object? notes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Marriage(
      id: id ?? this.id,
      person1Id: person1Id ?? this.person1Id,
      person2Id: person2Id ?? this.person2Id,
      startDate:
          identical(startDate, _unset) ? this.startDate : startDate as String?,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as String?,
      status: status ?? this.status,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'person1_id': person1Id,
        'person2_id': person2Id,
        'start_date': startDate,
        'end_date': endDate,
        'status': status.name,
        'notes': notes,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  factory Marriage.fromMap(Map<String, Object?> map) => Marriage(
        id: map['id'] as int?,
        person1Id: map['person1_id'] as int,
        person2Id: map['person2_id'] as int,
        startDate: map['start_date'] as String?,
        endDate: map['end_date'] as String?,
        status: MarriageStatus.parse(map['status'] as String?),
        notes: map['notes'] as String?,
        createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      );
}
DART_EOF

# ───────────────────────── قاعدة البيانات ─────────────────────────
cat > lib/data/database/app_database.dart <<'DART_EOF'
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

typedef Migration = Future<void> Function(Database db);

/// فتح قاعدة SQLite مع ترحيلات مرقمة.
/// لإضافة إصدار جديد: أضف دالة جديدة إلى نهاية [migrations] ولا تعدّل القديمة.
class AppDatabase {
  AppDatabase._();

  static const String fileName = 'family_tree.db';

  static final List<Migration> migrations = [_v1];

  static int get currentVersion => migrations.length;

  static Future<Database> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: currentVersion,
        singleInstance: path != inMemoryDatabasePath,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: (db, oldVersion, newVersion) =>
            _migrate(db, oldVersion, newVersion),
      ),
    );
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      await migrations[v](db);
    }
  }

  static Future<void> _v1(Database db) async {
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gender TEXT NOT NULL DEFAULT 'unknown'
          CHECK (gender IN ('male','female','unknown')),
        father_id INTEGER REFERENCES persons(id) ON DELETE SET NULL,
        mother_id INTEGER REFERENCES persons(id) ON DELETE SET NULL,
        birth_date TEXT,
        death_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (father_id IS NULL OR father_id <> id),
        CHECK (mother_id IS NULL OR mother_id <> id)
      )
    ''');
    await db.execute('CREATE INDEX idx_persons_name ON persons(name)');
    await db.execute('CREATE INDEX idx_persons_father ON persons(father_id)');
    await db.execute('CREATE INDEX idx_persons_mother ON persons(mother_id)');

    await db.execute('''
      CREATE TABLE marriages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person1_id INTEGER NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
        person2_id INTEGER NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
        start_date TEXT,
        end_date TEXT,
        status TEXT NOT NULL DEFAULT 'married'
          CHECK (status IN ('married','divorced','widowed')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK (person1_id <> person2_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_marriages_p1 ON marriages(person1_id)');
    await db.execute('CREATE INDEX idx_marriages_p2 ON marriages(person2_id)');
  }
}
DART_EOF

# ───────────────────────── المستودعات ─────────────────────────
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
DART_EOF

cat > lib/data/repositories/marriage_repository.dart <<'DART_EOF'
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
DART_EOF

# ───────────────────────── منطق الأعمال ─────────────────────────
cat > lib/domain/family_service.dart <<'DART_EOF'
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../data/repositories/marriage_repository.dart';
import '../data/repositories/person_repository.dart';

class FamilyValidationException implements Exception {
  FamilyValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// قواعد الأعمال: التحقق من الأسماء والتواريخ والوالدين ومنع الحلقات والتكرار.
class FamilyService {
  FamilyService(this._persons, this._marriages);

  final PersonRepository _persons;
  final MarriageRepository _marriages;

  // ───── الأشخاص ─────

  Future<int> addPerson(Person person) async {
    final cleaned = _clean(person);
    await _validatePerson(cleaned);
    return _persons.insert(cleaned);
  }

  /// يعيد false إذا لم يكن الشخص موجوداً.
  Future<bool> updatePerson(Person person) async {
    final id = person.id;
    if (id == null) {
      throw FamilyValidationException('معرّف الشخص مطلوب للتعديل');
    }
    if (await _persons.getById(id) == null) {
      return false;
    }
    final cleaned = _clean(person);
    await _validatePerson(cleaned);
    return _persons.update(cleaned);
  }

  /// الحذف يفرغ حقول الأب/الأم عند الأبناء ويحذف علاقات الزواج (قيود قاعدة البيانات).
  Future<bool> deletePerson(int id) => _persons.delete(id);

  Person _clean(Person p) => p.copyWith(
        name: p.name.trim().replaceAll(RegExp(r'\s+'), ' '),
        notes: (p.notes == null || p.notes!.trim().isEmpty)
            ? null
            : p.notes!.trim(),
      );

  Future<void> _validatePerson(Person p) async {
    if (p.name.isEmpty) {
      throw FamilyValidationException('الاسم مطلوب');
    }
    if (p.name.length > 200) {
      throw FamilyValidationException('الاسم أطول من 200 حرف');
    }
    _checkDate(p.birthDate, 'تاريخ الميلاد');
    _checkDate(p.deathDate, 'تاريخ الوفاة');
    if (p.birthDate != null &&
        p.deathDate != null &&
        p.deathDate!.compareTo(p.birthDate!) < 0) {
      throw FamilyValidationException('تاريخ الوفاة قبل تاريخ الميلاد');
    }

    final id = p.id;
    if (id != null && (p.fatherId == id || p.motherId == id)) {
      throw FamilyValidationException('لا يمكن أن يكون الشخص أباً أو أماً لنفسه');
    }
    if (p.fatherId != null && p.fatherId == p.motherId) {
      throw FamilyValidationException('الأب والأم لا يمكن أن يكونا الشخص نفسه');
    }

    if (p.fatherId != null) {
      final father = await _persons.getById(p.fatherId!);
      if (father == null) {
        throw FamilyValidationException('الأب غير موجود');
      }
      if (father.gender == Gender.female) {
        throw FamilyValidationException('الأب المختار مسجّل أنثى');
      }
    }
    if (p.motherId != null) {
      final mother = await _persons.getById(p.motherId!);
      if (mother == null) {
        throw FamilyValidationException('الأم غير موجودة');
      }
      if (mother.gender == Gender.male) {
        throw FamilyValidationException('الأم المختارة مسجّلة ذكراً');
      }
    }

    if (id != null) {
      for (final parentId in [p.fatherId, p.motherId]) {
        if (parentId != null && await _isAncestorOrSelf(id, of: parentId)) {
          throw FamilyValidationException(
              'هذا الاختيار ينشئ حلقة في النسب (الشخص من أجداد والديه)');
        }
      }
      final children = await _persons.getChildren(id);
      if (p.gender == Gender.male && children.any((c) => c.motherId == id)) {
        throw FamilyValidationException('لا يمكن جعله ذكراً وهو أم لأحد الأبناء');
      }
      if (p.gender == Gender.female && children.any((c) => c.fatherId == id)) {
        throw FamilyValidationException('لا يمكن جعلها أنثى وهي أب لأحد الأبناء');
      }
    }
  }

  /// هل [candidateId] هو [of] نفسه أو أحد أسلافه؟
  Future<bool> _isAncestorOrSelf(int candidateId, {required int of}) async {
    final visited = <int>{};
    final queue = <int>[of];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (current == candidateId) {
        return true;
      }
      if (!visited.add(current)) {
        continue;
      }
      final person = await _persons.getById(current);
      if (person == null) {
        continue;
      }
      if (person.fatherId != null) queue.add(person.fatherId!);
      if (person.motherId != null) queue.add(person.motherId!);
    }
    return false;
  }

  // ───── الزواج ─────

  Future<int> addMarriage(Marriage marriage) async {
    await _validateMarriage(marriage);
    return _marriages.insert(marriage);
  }

  Future<bool> updateMarriage(Marriage marriage) async {
    final id = marriage.id;
    if (id == null) {
      throw FamilyValidationException('معرّف العلاقة مطلوب للتعديل');
    }
    if (await _marriages.getById(id) == null) {
      return false;
    }
    await _validateMarriage(marriage);
    return _marriages.update(marriage);
  }

  Future<bool> deleteMarriage(int id) => _marriages.delete(id);

  Future<void> _validateMarriage(Marriage m) async {
    if (m.person1Id == m.person2Id) {
      throw FamilyValidationException('لا يمكن تسجيل زواج شخص من نفسه');
    }
    if (await _persons.getById(m.person1Id) == null ||
        await _persons.getById(m.person2Id) == null) {
      throw FamilyValidationException('أحد الزوجين غير موجود');
    }
    _checkDate(m.startDate, 'تاريخ الزواج');
    _checkDate(m.endDate, 'تاريخ انتهاء الزواج');
    if (m.startDate != null &&
        m.endDate != null &&
        m.endDate!.compareTo(m.startDate!) < 0) {
      throw FamilyValidationException('تاريخ الانتهاء قبل تاريخ الزواج');
    }
    if (m.status == MarriageStatus.married) {
      final existing = await _marriages.findBetween(m.person1Id, m.person2Id);
      final duplicate = existing.any(
          (e) => e.id != m.id && e.status == MarriageStatus.married);
      if (duplicate) {
        throw FamilyValidationException('يوجد زواج قائم مسجّل بين هذين الشخصين');
      }
    }
  }

  // ───── أدوات ─────

  void _checkDate(String? value, String label) {
    if (value == null) {
      return;
    }
    final parsed = DateTime.tryParse(value);
    final valid = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        parsed != null &&
        parsed.toIso8601String().startsWith(value);
    if (!valid) {
      throw FamilyValidationException('$label غير صالح (الصيغة yyyy-MM-dd)');
    }
  }
}
DART_EOF

# ───────────────────────── الواجهة (هيكل أدنى للبناء فقط) ─────────────────────────
cat > lib/main.dart <<'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database/app_database.dart';
import 'data/repositories/person_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  runApp(FamilyTreeApp(persons: PersonRepository(db)));
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.persons});

  final PersonRepository persons;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجرة عائلتي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('شجرة عائلتي')),
        body: Center(
          child: FutureBuilder<int>(
            future: persons.count(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('خطأ في قاعدة البيانات: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              return Text('عدد الأفراد المسجلين: ${snapshot.data}');
            },
          ),
        ),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── الاختبارات ─────────────────────────
cat > test/support/test_db.dart <<'DART_EOF'
import 'package:family_tree/data/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _initialized = false;

/// قاعدة SQLite في الذاكرة للاختبارات.
Future<Database> openTestDb() {
  if (!_initialized) {
    sqfliteFfiInit();
    _initialized = true;
  }
  return AppDatabase.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfi,
  );
}
DART_EOF

cat > test/person_repository_test.dart <<'DART_EOF'
import 'package:family_tree/data/database/app_database.dart';
import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/data/repositories/marriage_repository.dart';
import 'package:family_tree/data/repositories/person_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late PersonRepository persons;
  late MarriageRepository marriages;

  setUp(() async {
    db = await openTestDb();
    persons = PersonRepository(db);
    marriages = MarriageRepository(db);
  });

  tearDown(() => db.close());

  test('المخطط ينشأ بالإصدار الحالي', () async {
    expect(await db.getVersion(), AppDatabase.currentVersion);
    final tables = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final names = tables.map((r) => r['name']).toSet();
    expect(names, containsAll(['persons', 'marriages']));
  });

  test('إضافة وقراءة شخص', () async {
    final id = await persons.insert(const Person(
      name: 'شخص تجريبي',
      gender: Gender.male,
      birthDate: '1980-01-01',
      notes: 'ملاحظة',
    ));
    final loaded = await persons.getById(id);
    expect(loaded, isNotNull);
    expect(loaded!.name, 'شخص تجريبي');
    expect(loaded.gender, Gender.male);
    expect(loaded.birthDate, '1980-01-01');
    expect(loaded.notes, 'ملاحظة');
    expect(loaded.createdAt, isNotNull);
    expect(await persons.count(), 1);
  });

  test('تعديل شخص يغيّر الحقول ويمسح القيم الاختيارية', () async {
    final id = await persons.insert(
        const Person(name: 'قبل', birthDate: '1990-05-05', notes: 'x'));
    final original = (await persons.getById(id))!;
    final ok = await persons.update(
        original.copyWith(name: 'بعد', birthDate: null, notes: null));
    expect(ok, isTrue);
    final updated = (await persons.getById(id))!;
    expect(updated.name, 'بعد');
    expect(updated.birthDate, isNull);
    expect(updated.notes, isNull);
    expect(updated.createdAt, original.createdAt);
  });

  test('تعديل شخص غير موجود يعيد false', () async {
    expect(await persons.update(const Person(id: 999, name: 'لا أحد')), isFalse);
  });

  test('حذف الأب يفرغ father_id عند الابن', () async {
    final fatherId =
        await persons.insert(const Person(name: 'أب', gender: Gender.male));
    final childId =
        await persons.insert(Person(name: 'ابن', fatherId: fatherId));
    expect(await persons.delete(fatherId), isTrue);
    expect((await persons.getById(childId))!.fatherId, isNull);
  });

  test('حذف شخص يحذف علاقات زواجه', () async {
    final a = await persons.insert(const Person(name: 'أ'));
    final b = await persons.insert(const Person(name: 'ب'));
    await marriages.insert(Marriage(person1Id: a, person2Id: b));
    await persons.delete(a);
    expect(await marriages.getAll(), isEmpty);
  });

  test('قيود المفاتيح الأجنبية مفعّلة', () async {
    expect(
      () => persons.insert(const Person(name: 'يتيم', fatherId: 12345)),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('البحث بالاسم مع تهريب % و _', () async {
    await persons.insert(const Person(name: 'محمد علي'));
    await persons.insert(const Person(name: 'علي حسن'));
    await persons.insert(const Person(name: '100% اسم'));
    expect((await persons.search('علي')).length, 2);
    expect((await persons.search('%')).length, 1);
    expect((await persons.search('_')).length, 0);
    expect((await persons.search('')).length, 3);
  });

  test('getChildren يعيد أبناء الأب والأم', () async {
    final f = await persons.insert(const Person(name: 'أب', gender: Gender.male));
    final m =
        await persons.insert(const Person(name: 'أم', gender: Gender.female));
    await persons.insert(Person(name: 'ابن 1', fatherId: f, motherId: m));
    await persons.insert(Person(name: 'ابن 2', motherId: m));
    expect((await persons.getChildren(f)).length, 1);
    expect((await persons.getChildren(m)).length, 2);
  });

  test('CRUD الزواج وfindBetween بالترتيبين', () async {
    final a = await persons.insert(const Person(name: 'أ'));
    final b = await persons.insert(const Person(name: 'ب'));
    final id = await marriages.insert(
        Marriage(person1Id: a, person2Id: b, startDate: '2010-01-01'));
    expect((await marriages.findBetween(a, b)).length, 1);
    expect((await marriages.findBetween(b, a)).length, 1);
    final m = (await marriages.getById(id))!;
    await marriages.update(m.copyWith(status: MarriageStatus.divorced));
    expect((await marriages.getById(id))!.status, MarriageStatus.divorced);
    expect((await marriages.getForPerson(a)).length, 1);
    expect(await marriages.delete(id), isTrue);
    expect(await marriages.getById(id), isNull);
  });
}
DART_EOF

cat > test/family_service_test.dart <<'DART_EOF'
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
DART_EOF

echo "تم إنشاء ملفات المرحلة 1."
