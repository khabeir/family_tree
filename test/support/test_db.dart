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
