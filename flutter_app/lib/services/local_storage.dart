import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local storage service using Hive for offline-first architecture
/// Provides encrypted storage for sensitive data and plain storage for performance-critical data
class FamQuestStorage {
  static final FamQuestStorage instance = FamQuestStorage._();
  FamQuestStorage._();

  final _secureStorage = const FlutterSecureStorage();
  late List<int> _encryptionKey;

  // Hive boxes
  late Box<dynamic> _tasksBox;
  late Box<dynamic> _eventsBox;
  late Box<dynamic> _pointsBox;
  late Box<dynamic> _badgesBox;
  late Box<dynamic> _syncMetadataBox;
  late Box<dynamic> _conflictsBox;
  late Box<dynamic> _syncQueueBox;

  // Encrypted boxes for sensitive data
  late Box<dynamic> _usersBox;
  late Box<dynamic> _authBox;

  bool _initialized = false;

  /// Initialize Hive and open all boxes
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Get or generate encryption key
    await _initEncryptionKey();

    // Register type adapters
    _registerAdapters();

    // Open plain boxes (performance-critical)
    _tasksBox = await Hive.openBox('tasks');
    _eventsBox = await Hive.openBox('events');
    _pointsBox = await Hive.openBox('points_ledger');
    _badgesBox = await Hive.openBox('badges');
    _syncMetadataBox = await Hive.openBox('sync_metadata');
    _conflictsBox = await Hive.openBox('conflicts');
    _syncQueueBox = await Hive.openBox('sync_queue');

    // Open encrypted boxes (sensitive data)
    final cipher = HiveAesCipher(_encryptionKey);
    _usersBox = await Hive.openBox('users', encryptionCipher: cipher);
    _authBox = await Hive.openBox('auth_tokens', encryptionCipher: cipher);

    _initialized = true;
  }

  /// Initialize encryption key (generate if not exists)
  Future<void> _initEncryptionKey() async {
    final keyString = await _secureStorage.read(key: 'hive_encryption_key');

    if (keyString == null) {
      // Generate new key
      _encryptionKey = Hive.generateSecureKey();
      await _secureStorage.write(
        key: 'hive_encryption_key',
        value: base64Encode(_encryptionKey),
      );
    } else {
      // Load existing key
      _encryptionKey = base64Decode(keyString);
    }
  }

  /// Register Hive type adapters
  void _registerAdapters() {
    // Type adapters will be registered here
    // Hive.registerAdapter(TaskEntityAdapter());
    // Hive.registerAdapter(EventEntityAdapter());
  }

  /// Close all boxes
  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }

  // ========== CRUD Operations ==========

  /// Get entity by ID from specified box
  Future<Map<String, dynamic>?> get(String boxName, String id) async {
    final box = _getBox(boxName);
    final data = box.get(id);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Get all entities from specified box
  Future<List<Map<String, dynamic>>> getAll(String boxName) async {
    final box = _getBox(boxName);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Put entity into specified box with sync metadata
  Future<void> put(
      String boxName, String id, Map<String, dynamic> entity) async {
    final box = _getBox(boxName);

    // Add sync metadata
    entity['isDirty'] = true;
    entity['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    // Increment version for optimistic locking
    final existing = box.get(id);
    if (existing != null) {
      entity['version'] = (existing['version'] ?? 0) + 1;
    } else {
      entity['version'] = 1;
    }

    await box.put(id, entity);
  }

  /// Delete entity (soft delete with isDeleted flag)
  Future<void> delete(String boxName, String id) async {
    final box = _getBox(boxName);
    final entity = box.get(id);

    if (entity != null) {
      entity['isDeleted'] = true;
      entity['isDirty'] = true;
      entity['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      entity['version'] = (entity['version'] ?? 0) + 1;
      await box.put(id, entity);
    }
  }

  /// Hard delete (remove from box completely)
  Future<void> hardDelete(String boxName, String id) async {
    final box = _getBox(boxName);
    await box.delete(id);
  }

  // ========== Query Operations ==========

  /// Query entities with filters
  Future<List<Map<String, dynamic>>> query(
    String boxName, {
    bool Function(Map<String, dynamic>)? where,
    int? limit,
    int? offset,
  }) async {
    final box = _getBox(boxName);
    var results =
        box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Apply filter
    if (where != null) {
      results = results.where(where).toList();
    }

    // Apply offset
    if (offset != null && offset > 0) {
      results = results.skip(offset).toList();
    }

    // Apply limit
    if (limit != null && limit > 0) {
      results = results.take(limit).toList();
    }

    return results;
  }

  /// Get entities by status (common query for tasks)
  Future<List<Map<String, dynamic>>> getByStatus(
    String boxName,
    String status,
  ) async {
    return query(
      boxName,
      where: (entity) => entity['status'] == status,
    );
  }

  /// Get entities by assignee
  Future<List<Map<String, dynamic>>> getByAssignee(
    String boxName,
    String userId,
  ) async {
    return query(
      boxName,
      where: (entity) {
        final assignees = entity['assignees'] as List?;
        return assignees?.contains(userId) ?? false;
      },
    );
  }

  /// Get entities due before date
  Future<List<Map<String, dynamic>>> getDueBefore(
    String boxName,
    DateTime date,
  ) async {
    return query(
      boxName,
      where: (entity) {
        final dueStr = entity['due'] as String?;
        if (dueStr == null) return false;
        final due = DateTime.parse(dueStr);
        return due.isBefore(date);
      },
    );
  }

  // ========== Sync Operations ==========

  /// Get all dirty entities (have local changes not synced)
  Future<List<Map<String, dynamic>>> getDirtyEntities(String boxName) async {
    return query(
      boxName,
      where: (entity) =>
          entity['isDirty'] == true && entity['isDeleted'] != true,
    );
  }

  /// Get all deleted entities (pending sync)
  Future<List<Map<String, dynamic>>> getDeletedEntities(String boxName) async {
    return query(
      boxName,
      where: (entity) =>
          entity['isDeleted'] == true && entity['isDirty'] == true,
    );
  }

  /// Mark entity as clean (synced successfully)
  Future<void> markClean(String boxName, String id) async {
    final box = _getBox(boxName);
    final entity = box.get(id);

    if (entity != null) {
      entity['isDirty'] = false;
      await box.put(id, entity);
    }
  }

  /// Mark entity as dirty (needs sync)
  Future<void> markDirty(String boxName, String id) async {
    final box = _getBox(boxName);
    final entity = box.get(id);

    if (entity != null) {
      entity['isDirty'] = true;
      entity['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await box.put(id, entity);
    }
  }

  /// Batch mark entities as clean
  Future<void> markCleanBatch(String boxName, List<String> ids) async {
    final box = _getBox(boxName);
    final updates = <String, dynamic>{};

    for (final id in ids) {
      final entity = box.get(id);
      if (entity != null) {
        entity['isDirty'] = false;
        updates[id] = entity;
      }
    }

    await box.putAll(updates);
  }

  // ========== Sync Metadata ==========

  /// Get last sync timestamp for entity type
  Future<DateTime?> getLastSyncTimestamp(String entityType) async {
    final metadata = _syncMetadataBox.get(entityType);
    if (metadata == null) return null;

    final timestampStr = metadata['lastSyncAt'] as String?;
    return timestampStr != null ? DateTime.parse(timestampStr) : null;
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncTimestamp(
      String entityType, DateTime timestamp) async {
    final metadata = _syncMetadataBox.get(entityType) ?? <String, dynamic>{};
    metadata['lastSyncAt'] = timestamp.toUtc().toIso8601String();
    metadata['successfulSyncs'] = (metadata['successfulSyncs'] ?? 0) + 1;
    await _syncMetadataBox.put(entityType, metadata);
  }

  /// Get all last sync timestamps
  Future<Map<String, DateTime>> getLastSyncTimestamps() async {
    final result = <String, DateTime>{};

    for (final key in _syncMetadataBox.keys) {
      final metadata = _syncMetadataBox.get(key);
      final timestampStr = metadata['lastSyncAt'] as String?;
      if (timestampStr != null) {
        result[key as String] = DateTime.parse(timestampStr);
      }
    }

    return result;
  }

  // ========== Conflict Management ==========

  /// Store conflict for manual resolution
  Future<void> storeConflict(Map<String, dynamic> conflict) async {
    final conflictId =
        conflict['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    conflict['storedAt'] = DateTime.now().toUtc().toIso8601String();
    conflict['resolved'] = false;
    await _conflictsBox.put(conflictId, conflict);
  }

  /// Get all unresolved conflicts
  Future<List<Map<String, dynamic>>> getPendingConflicts() async {
    return _conflictsBox.values
        .where((c) => c['resolved'] != true)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Mark conflict as resolved
  Future<void> markConflictResolved(String conflictId) async {
    final conflict = _conflictsBox.get(conflictId);
    if (conflict != null) {
      conflict['resolved'] = true;
      conflict['resolvedAt'] = DateTime.now().toUtc().toIso8601String();
      await _conflictsBox.put(conflictId, conflict);
    }
  }

  /// Delete resolved conflicts older than 7 days
  Future<void> cleanupOldConflicts() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final toDelete = <String>[];

    for (final key in _conflictsBox.keys) {
      final conflict = _conflictsBox.get(key);
      if (conflict['resolved'] == true) {
        final resolvedAtStr = conflict['resolvedAt'] as String?;
        if (resolvedAtStr != null) {
          final resolvedAt = DateTime.parse(resolvedAtStr);
          if (resolvedAt.isBefore(cutoff)) {
            toDelete.add(key as String);
          }
        }
      }
    }

    for (final key in toDelete) {
      await _conflictsBox.delete(key);
    }
  }

  // ========== Auth Operations (Encrypted Box) ==========

  /// Store access token securely
  Future<void> setAccessToken(String token) async {
    await _authBox.put('accessToken', token);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return _authBox.get('accessToken');
  }

  /// Store refresh token securely
  Future<void> setRefreshToken(String token) async {
    await _authBox.put('refreshToken', token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return _authBox.get('refreshToken');
  }

  /// Clear all auth tokens
  Future<void> clearAuth() async {
    await _authBox.clear();
  }

  // ========== User Operations (Encrypted Box) ==========

  /// Store user profile
  Future<void> setUser(String userId, Map<String, dynamic> user) async {
    await _usersBox.put(userId, user);
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUser(String userId) async {
    final data = _usersBox.get(userId);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Get current user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final userId = _authBox.get('currentUserId');
    if (userId == null) return null;
    return getUser(userId);
  }

  /// Set current user ID
  Future<void> setCurrentUserId(String userId) async {
    await _authBox.put('currentUserId', userId);
  }

  // ========== Statistics ==========

  /// Get storage statistics
  Future<Map<String, dynamic>> getStats() async {
    return {
      'tasks': _tasksBox.length,
      'events': _eventsBox.length,
      'points': _pointsBox.length,
      'badges': _badgesBox.length,
      'users': _usersBox.length,
      'conflicts': _conflictsBox.length,
      'dirtyTasks': (await getDirtyEntities('tasks')).length,
      'dirtyEvents': (await getDirtyEntities('events')).length,
    };
  }

  /// Clear all data (logout)
  Future<void> clearAll() async {
    await _tasksBox.clear();
    await _eventsBox.clear();
    await _pointsBox.clear();
    await _badgesBox.clear();
    await _syncMetadataBox.clear();
    await _conflictsBox.clear();
    await _usersBox.clear();
    await _authBox.clear();
  }

  // ========== Helper Methods ==========

  /// Get box by name
  Box<dynamic> _getBox(String boxName) {
    switch (boxName) {
      case 'tasks':
        return _tasksBox;
      case 'events':
        return _eventsBox;
      case 'points':
        return _pointsBox;
      case 'badges':
        return _badgesBox;
      case 'users':
        return _usersBox;
      case 'sync_queue':
        return _syncQueueBox;
      default:
        throw Exception('Unknown box: $boxName');
    }
  }
}
