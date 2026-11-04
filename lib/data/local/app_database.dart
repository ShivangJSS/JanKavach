import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseName = 'jan_kavach.db';
  static const int _databaseVersion = 4;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbDirectory = await getDatabasesPath();
    final dbPath = p.join(dbDirectory, _databaseName);

    _database = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    try {
      await _database!.execute(
        'ALTER TABLE beneficiary_records ADD COLUMN user_id TEXT',
      );
    } catch (_) {}

    try {
      await _database!.execute(
        'ALTER TABLE beneficiary_cache ADD COLUMN user_id TEXT',
      );
    } catch (_) {}

    // Self-healing: repair any legacy records where local drafts were fake-stamped with server_id
    try {
      await _database!.execute('''
        UPDATE beneficiary_records
        SET server_id = NULL,
            record_state = CASE WHEN record_state = 'synced' THEN 'pending_sync' ELSE record_state END
        WHERE beneficiary_code LIKE 'LOCAL-%'
           OR beneficiary_code IS NULL
           OR (record_state != 'synced' AND server_id IS NOT NULL)
      ''');
    } catch (_) {}

    // Discard any poisoned legacy eligibility caches so fresh dynamic evaluations run
    try {
      await _database!.execute('DELETE FROM eligibility_cache');
    } catch (_) {}

    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE beneficiary_records (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        user_id TEXT,
        beneficiary_code TEXT,
        form_data TEXT NOT NULL,
        current_step INTEGER NOT NULL DEFAULT 0,
        record_state TEXT NOT NULL DEFAULT 'draft',
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE geography_cache (
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_local_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS beneficiary_cache (
        server_id INTEGER PRIMARY KEY,
        beneficiary_code TEXT,
        name TEXT,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scheme_cache (
        scheme_id INTEGER PRIMARY KEY,
        scheme_code TEXT,
        scheme_name TEXT,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS eligibility_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        beneficiary_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        UNIQUE(beneficiary_id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_beneficiary_state
      ON beneficiary_records(record_state)
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_queue_status
      ON sync_queue(status, id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_eligibility_beneficiary
      ON eligibility_cache(beneficiary_id)
    ''');
  }

  Future<void> _onUpgrade(
      Database db,
      int oldVersion,
      int newVersion,
      ) async {
    if (oldVersion < 2) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS geography_cache (
        cache_key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS beneficiary_cache (
        server_id INTEGER PRIMARY KEY,
        beneficiary_code TEXT,
        name TEXT,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS scheme_cache (
        scheme_id INTEGER PRIMARY KEY,
        scheme_code TEXT,
        scheme_name TEXT,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS eligibility_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        beneficiary_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        UNIQUE(beneficiary_id)
      )
    ''');

      await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_eligibility_beneficiary
      ON eligibility_cache(beneficiary_id)
    ''');
    }
  }

  Future<void> clearUserScopedData({String? keepUserId}) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        if (keepUserId != null && keepUserId.isNotEmpty) {
          // Preserve current user's cached beneficiaries and records!
          // Only purge data belonging to OTHER users.
          await txn.delete(
            'beneficiary_cache',
            where: 'user_id IS NOT NULL AND user_id != ?',
            whereArgs: [keepUserId],
          );
          await txn.delete(
            'beneficiary_records',
            where: 'user_id IS NOT NULL AND user_id != ?',
            whereArgs: [keepUserId],
          );
        } else {
          await txn.delete('beneficiary_cache');
          await txn.delete('eligibility_cache');
          await txn.delete(
            'geography_cache',
            where: "cache_key LIKE 'beneficiary_%'",
          );
          await txn.delete('beneficiary_records');
          await txn.delete('sync_queue');
        }
      });
    } catch (_) {}
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
