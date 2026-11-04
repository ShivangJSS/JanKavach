import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../services/storage_service.dart';
import 'app_database.dart';

class BeneficiaryLocalDao {
  final AppDatabase _appDatabase = AppDatabase.instance;

  Future<int> saveDraft({
    int? localId,
    required Map<String, dynamic> formData,
    required int currentStep,
    String? userId,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final effectiveUserId = userId ?? await StorageService.getCurrentUserId();

    final values = <String, Object?>{
      if (effectiveUserId != null) 'user_id': effectiveUserId,
      'form_data': jsonEncode(formData),
      'current_step': currentStep,
      'record_state': 'draft',
      'sync_error': null,
      'updated_at': now,
    };

    if (localId == null) {
      values['created_at'] = now;

      return db.insert(
        'beneficiary_records',
        values,
      );
    }

    final existing = await db.query(
      'beneficiary_records',
      columns: ['local_id', 'record_state'],
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (existing.isEmpty) {
      throw Exception('The saved beneficiary draft was not found.');
    }

    final existingState = existing.first['record_state'];

    if (existingState != 'draft') {
      throw Exception(
        'Only an incomplete draft can be edited. '
        'Current state: $existingState',
      );
    }

    await db.update(
      'beneficiary_records',
      values,
      where: 'local_id = ?',
      whereArgs: [localId],
    );

    return localId;
  }

  Future<Map<String, dynamic>?> getRecord(int localId) async {
    final db = await _appDatabase.database;

    final rows = await db.query(
      'beneficiary_records',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = Map<String, dynamic>.from(rows.first);
    row['form_data'] = Map<String, dynamic>.from(
      jsonDecode(row['form_data'] as String) as Map,
    );

    return row;
  }

  Future<List<Map<String, dynamic>>> getDrafts([String? userId]) async {
    final db = await _appDatabase.database;
    final effectiveUserId = userId ?? await StorageService.getCurrentUserId();

    final rows = await db.query(
      'beneficiary_records',
      where: effectiveUserId != null && effectiveUserId.isNotEmpty
          ? "record_state = ? AND user_id = ?"
          : 'record_state = ?',
      whereArgs: effectiveUserId != null && effectiveUserId.isNotEmpty
          ? ['draft', effectiveUserId]
          : ['draft'],
      orderBy: 'updated_at DESC',
    );

    return rows.map((row) {
      final result = Map<String, dynamic>.from(row);
      result['form_data'] = Map<String, dynamic>.from(
        jsonDecode(row['form_data'] as String) as Map,
      );
      return result;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingRegistrations([String? userId]) async {
    final db = await _appDatabase.database;
    final effectiveUserId = userId ?? await StorageService.getCurrentUserId();

    final rows = await db.query(
      'beneficiary_records',
      where: effectiveUserId != null && effectiveUserId.isNotEmpty
          ? "record_state IN (?, ?) AND user_id = ?"
          : 'record_state IN (?, ?)',
      whereArgs: effectiveUserId != null && effectiveUserId.isNotEmpty
          ? ['pending_sync', 'sync_failed', effectiveUserId]
          : ['pending_sync', 'sync_failed'],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) {
      final result = Map<String, dynamic>.from(row);
      result['form_data'] = Map<String, dynamic>.from(
        jsonDecode(row['form_data'] as String) as Map,
      );
      return result;
    }).toList();
  }

  Future<int> getPendingRegistrationsCount([String? userId]) async {
    final db = await _appDatabase.database;
    final effectiveUserId = userId ?? await StorageService.getCurrentUserId();

    final rows = await db.rawQuery(
      effectiveUserId != null && effectiveUserId.isNotEmpty
          ? "SELECT COUNT(*) as count FROM beneficiary_records WHERE record_state IN ('pending_sync', 'sync_failed') AND user_id = ?"
          : "SELECT COUNT(*) as count FROM beneficiary_records WHERE record_state IN ('pending_sync', 'sync_failed')",
      effectiveUserId != null && effectiveUserId.isNotEmpty ? [effectiveUserId] : null,
    );

    if (rows.isEmpty) return 0;
    final val = rows.first['count'];
    return val is int ? val : (int.tryParse('$val') ?? 0);
  }

  Future<void> submitLocally(int localId) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final rows = await txn.query(
        'beneficiary_records',
        columns: ['record_state'],
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw Exception('Beneficiary draft not found.');
      }

      final state = rows.first['record_state'];

      if (state == 'synced') {
        throw Exception('This beneficiary is already synced.');
      }

      await txn.update(
        'beneficiary_records',
        {
          'record_state': 'pending_sync',
          'sync_error': null,
          'updated_at': now,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );

      final existingQueueItems = await txn.query(
        'sync_queue',
        columns: ['id'],
        where: '''
          entity_type = ?
          AND entity_local_id = ?
          AND operation = ?
          AND status = ?
        ''',
        whereArgs: [
          'beneficiary',
          localId,
          'create',
          'pending',
        ],
        limit: 1,
      );

      if (existingQueueItems.isEmpty) {
        await txn.insert('sync_queue', {
          'entity_type': 'beneficiary',
          'entity_local_id': localId,
          'operation': 'create',
          'status': 'pending',
          'retry_count': 0,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> markSynced({
    required int localId,
    required int serverId,
    String? beneficiaryCode,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'beneficiary_records',
        {
          'server_id': serverId,
          'beneficiary_code': beneficiaryCode,
          'record_state': 'synced',
          'sync_error': null,
          'last_synced_at': now,
          'updated_at': now,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );

      await txn.update(
        'sync_queue',
        {
          'status': 'synced',
          'last_error': null,
          'updated_at': now,
        },
        where: '''
        entity_type = ?
        AND entity_local_id = ?
        AND operation = ?
      ''',
        whereArgs: ['beneficiary', localId, 'create'],
      );
    });
  }

  Future<void> markSyncFailed({
    required int localId,
    required String error,
  }) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'beneficiary_records',
        {
          'record_state': 'sync_failed',
          'sync_error': error,
          'updated_at': now,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );

      await txn.rawUpdate(
        '''
      UPDATE sync_queue
      SET retry_count = retry_count + 1,
          last_error = ?,
          updated_at = ?,
          status = ?
      WHERE entity_type = ?
        AND entity_local_id = ?
        AND operation = ?
      ''',
        [
          error,
          now,
          'pending',
          'beneficiary',
          localId,
          'create',
        ],
      );
    });
  }

  Future<void> deleteDraft(int localId) async {
    final db = await _appDatabase.database;

    await db.delete(
      'beneficiary_records',
      where: "local_id = ? AND record_state = 'draft'",
      whereArgs: [localId],
    );
  }

  Future<void> debugPrintSyncStatus() async {
    final db = await _appDatabase.database;

    final records = await db.query(
      'beneficiary_records',
      columns: [
        'local_id',
        'server_id',
        'beneficiary_code',
        'record_state',
        'sync_error',
        'created_at',
        'last_synced_at',
      ],
      orderBy: 'local_id DESC',
    );

    final queue = await db.query(
      'sync_queue',
      columns: [
        'id',
        'entity_local_id',
        'status',
        'retry_count',
        'last_error',
      ],
      orderBy: 'id DESC',
    );

    debugPrint('--- BENEFICIARY SYNC STATUS ---');
    for (final record in records) {
      debugPrint(record.toString());
    }

    debugPrint('--- SYNC QUEUE STATUS ---');
    for (final item in queue) {
      debugPrint(item.toString());
    }
  }
}
