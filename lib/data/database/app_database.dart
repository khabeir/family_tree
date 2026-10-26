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
