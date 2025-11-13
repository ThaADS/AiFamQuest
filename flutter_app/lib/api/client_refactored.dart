import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../services/local_storage.dart';
import '../services/sync_queue.dart';
import '../services/conflict_resolver.dart';

/// Refactored API client with offline-first architecture
/// Reads from local Hive storage first, syncs in background
class ApiClientOfflineFirst {
  static final ApiClientOfflineFirst instance = ApiClientOfflineFirst._();
  ApiClientOfflineFirst._();

  // ignore: unused_field
  final _storage = const FlutterSecureStorage();
  final _localStorage = LocalStorage.instance;
  final _syncQueue = SyncQueue.instance;
  final _conflictResolver = ConflictResolver.instance;
  final _uuid = Uuid();

  String baseUrl = const String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

  bool _initialized = false;

  /// Initialize offline-first client
  Future<void> init() async {
    if (_initialized) return;

    await _localStorage.init();
    await _syncQueue.init();

    // Setup sync queue callbacks
    _syncQueue.onSyncComplete = _handleSyncComplete;
    _syncQueue.onSyncError = _handleSyncError;

    _initialized = true;

    // Trigger initial sync if online
    _syncQueue.scheduleSyncIfNeeded();
  }

  // ========== Auth Operations ==========

  Future<bool> hasToken() async {
    final token = await _localStorage.getAccessToken();
    return token?.isNotEmpty == true;
  }

  Future<void> setToken(String token) async {
    await _localStorage.setAccessToken(token);
  }

  Future<String?> getToken() async {
    return _localStorage.getAccessToken();
  }

  Future<Map<String, dynamic>> login(String email, String password, {String? otp}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'otp': otp}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await setToken(data['accessToken']);

      // Store refresh token if present
      if (data['refreshToken'] != null) {
        await _localStorage.setRefreshToken(data['refreshToken']);
      }

      // Store user data
      if (data['user'] != null) {
        final userId = data['user']['id'];
        await _localStorage.setUser(userId, data['user']);
        await _localStorage.setCurrentUserId(userId);
      }

      // Trigger full sync after login
      _syncQueue.scheduleSyncIfNeeded();

      return data;
    }

    throw Exception('Login failed: ${res.statusCode} ${res.body}');
  }

  Future<void> logout() async {
    // Clear local storage
    await _localStorage.clearAll();

    // Clear sync queue
    await _syncQueue.clearAll();
  }

  // ========== Task Operations (Offline-First) ==========

  /// List tasks (offline-first: read from local storage)
  Future<List<Map<String, dynamic>>> listTasks({
    String? status,
    String? assigneeId,
  }) async {
    if (status != null) {
      return _localStorage.getByStatus('tasks', status);
    } else if (assigneeId != null) {
      return _localStorage.getByAssignee('tasks', assigneeId);
    } else {
      return _localStorage.getAll('tasks');
    }
  }

  /// Get single task (offline-first)
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    return _localStorage.get('tasks', taskId);
  }

  /// Create task (optimistic UI)
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async {
    // 1. Generate UUID and add metadata
    final taskId = _uuid.v4();
    body['id'] = taskId;
    body['version'] = 1;
    body['isDirty'] = true;
    body['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    // 2. Write to local storage immediately
    await _localStorage.put('tasks', taskId, body);

    // 3. Queue for sync
    await _syncQueue.enqueue(SyncOperation(
      entityType: 'task',
      operation: 'create',
      entityId: taskId,
      data: body,
    ));

    // 4. Trigger background sync (non-blocking)
    _syncQueue.scheduleSyncIfNeeded();

    // 5. Return immediately (optimistic)
    return body;
  }

  /// Update task (optimistic UI)
  Future<Map<String, dynamic>> updateTask(String taskId, Map<String, dynamic> updates) async {
    // 1. Get existing task
    final existing = await _localStorage.get('tasks', taskId);
    if (existing == null) {
      throw Exception('Task not found: $taskId');
    }

    // 2. Merge updates
    final updated = <String, dynamic>{...existing, ...updates};

    // 3. Write to local storage
    await _localStorage.put('tasks', taskId, updated);

    // 4. Queue for sync
    await _syncQueue.enqueue(SyncOperation(
      entityType: 'task',
      operation: 'update',
      entityId: taskId,
      data: updated,
    ));

    // 5. Trigger background sync
    _syncQueue.scheduleSyncIfNeeded();

    return updated;
  }

  /// Complete task (optimistic UI)
  Future<Map<String, dynamic>> completeTask(String taskId, {List<String>? proofPhotos}) async {
    final updates = <String, dynamic>{
      'status': 'done',
      'completedAt': DateTime.now().toUtc().toIso8601String(),
    };

    if (proofPhotos != null) {
      updates['proofPhotos'] = proofPhotos;
    }

    return updateTask(taskId, updates);
  }

  /// Delete task (soft delete, optimistic UI)
  Future<void> deleteTask(String taskId) async {
    // Soft delete (mark as deleted)
    await _localStorage.delete('tasks', taskId);

    // Queue for sync
    await _syncQueue.enqueue(SyncOperation(
      entityType: 'task',
      operation: 'delete',
      entityId: taskId,
      data: {'id': taskId, 'isDeleted': true},
    ));

    _syncQueue.scheduleSyncIfNeeded();
  }

  // ========== Event Operations (Offline-First) ==========

  Future<List<Map<String, dynamic>>> listEvents() async {
    return _localStorage.getAll('events');
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    final eventId = _uuid.v4();
    body['id'] = eventId;
    body['version'] = 1;
    body['isDirty'] = true;
    body['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    await _localStorage.put('events', eventId, body);

    await _syncQueue.enqueue(SyncOperation(
      entityType: 'event',
      operation: 'create',
      entityId: eventId,
      data: body,
    ));

    _syncQueue.scheduleSyncIfNeeded();
    return body;
  }

  Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> updates) async {
    final existing = await _localStorage.get('events', eventId);
    if (existing == null) {
      throw Exception('Event not found: $eventId');
    }

    final updated = <String, dynamic>{...existing, ...updates};
    await _localStorage.put('events', eventId, updated);

    await _syncQueue.enqueue(SyncOperation(
      entityType: 'event',
      operation: 'update',
      entityId: eventId,
      data: updated,
    ));

    _syncQueue.scheduleSyncIfNeeded();
    return updated;
  }

  Future<void> deleteEvent(String eventId) async {
    await _localStorage.delete('events', eventId);

    await _syncQueue.enqueue(SyncOperation(
      entityType: 'event',
      operation: 'delete',
      entityId: eventId,
      data: {'id': eventId, 'isDeleted': true},
    ));

    _syncQueue.scheduleSyncIfNeeded();
  }

  // ========== Points Operations ==========

  Future<List<Map<String, dynamic>>> listPoints() async {
    return _localStorage.getAll('points');
  }

  Future<Map<String, dynamic>> addPoints(String userId, int amount, String reason) async {
    final pointId = _uuid.v4();
    final point = {
      'id': pointId,
      'userId': userId,
      'amount': amount,
      'reason': reason,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'version': 1,
      'isDirty': true,
    };

    await _localStorage.put('points', pointId, point);

    await _syncQueue.enqueue(SyncOperation(
      entityType: 'point',
      operation: 'create',
      entityId: pointId,
      data: point,
    ));

    _syncQueue.scheduleSyncIfNeeded();
    return point;
  }

  // ========== Sync Operations ==========

  /// Perform delta sync with server
  Future<SyncResult> performSync() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // 1. Get last sync timestamps
      final lastSyncTimestamps = await _localStorage.getLastSyncTimestamps();

      // 2. Get pending changes (dirty entities)
      final dirtyTasks = await _localStorage.getDirtyEntities('tasks');
      final dirtyEvents = await _localStorage.getDirtyEntities('events');
      final dirtyPoints = await _localStorage.getDirtyEntities('points');

      final pendingChanges = [
        ...dirtyTasks.map((t) => {
              'entityType': 'task',
              'operation': t['isDeleted'] == true ? 'delete' : 'update',
              'entityId': t['id'],
              'version': t['version'],
              'data': t,
              'updatedAt': t['updatedAt'],
            }),
        ...dirtyEvents.map((e) => {
              'entityType': 'event',
              'operation': e['isDeleted'] == true ? 'delete' : 'update',
              'entityId': e['id'],
              'version': e['version'],
              'data': e,
              'updatedAt': e['updatedAt'],
            }),
        ...dirtyPoints.map((p) => {
              'entityType': 'point',
              'operation': 'create',
              'entityId': p['id'],
              'version': p['version'],
              'data': p,
              'updatedAt': p['updatedAt'],
            }),
      ];

      // 3. Send delta sync request
      final response = await http.post(
        Uri.parse('$baseUrl/api/sync/delta'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'lastSyncTimestamps': lastSyncTimestamps.map(
            (key, value) => MapEntry(key, value.toIso8601String()),
          ),
          'pendingChanges': pendingChanges,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Sync failed: ${response.statusCode} ${response.body}');
      }

      final syncResponse = jsonDecode(response.body);

      // 4. Apply server changes
      final serverChanges = syncResponse['serverChanges'] as List? ?? [];
      for (final change in serverChanges) {
        await _applyServerChange(change);
      }

      // 5. Resolve conflicts
      final conflicts = syncResponse['conflicts'] as List? ?? [];
      int conflictsResolved = 0;
      int conflictsNeedingReview = 0;

      for (final conflictJson in conflicts) {
        final conflict = ConflictData.fromJson(conflictJson);
        final resolution = await _conflictResolver.resolve(conflict);

        if (resolution.needsManualReview) {
          // Store for manual review
          await _localStorage.storeConflict(conflict.toJson());
          conflictsNeedingReview++;
        } else {
          // Apply automatic resolution
          await _applyResolution(conflict, resolution);
          conflictsResolved++;
        }
      }

      // 6. Update sync metadata
      final syncTimestamp = DateTime.parse(syncResponse['syncTimestamp']);
      await _localStorage.updateLastSyncTimestamp('tasks', syncTimestamp);
      await _localStorage.updateLastSyncTimestamp('events', syncTimestamp);
      await _localStorage.updateLastSyncTimestamp('points', syncTimestamp);

      // 7. Mark synced entities as clean
      final taskIds = dirtyTasks.map((t) => t['id'] as String).toList();
      final eventIds = dirtyEvents.map((e) => e['id'] as String).toList();
      final pointIds = dirtyPoints.map((p) => p['id'] as String).toList();

      await _localStorage.markCleanBatch('tasks', taskIds);
      await _localStorage.markCleanBatch('events', eventIds);
      await _localStorage.markCleanBatch('points', pointIds);

      return SyncResult(
        synced: pendingChanges.length,
        failed: 0,
        conflicts: conflictsResolved + conflictsNeedingReview,
        skipped: 0,
      );
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  /// Apply server change to local storage
  Future<void> _applyServerChange(Map<String, dynamic> change) async {
    final entityType = change['entityType'];
    final operation = change['operation'];
    final entityId = change['entityId'];
    final data = change['data'];

    final boxName = _getBoxName(entityType);

    if (operation == 'create' || operation == 'update') {
      // Overwrite local with server data
      data['isDirty'] = false;
      await _localStorage.put(boxName, entityId, data);
    } else if (operation == 'delete') {
      await _localStorage.hardDelete(boxName, entityId);
    }
  }

  /// Apply conflict resolution
  Future<void> _applyResolution(ConflictData conflict, ConflictResolution resolution) async {
    if (resolution.resolvedData == null) return;

    final boxName = _getBoxName(conflict.entityType);
    resolution.resolvedData!['isDirty'] = false;

    await _localStorage.put(boxName, conflict.entityId, resolution.resolvedData!);
  }

  /// Get box name from entity type
  String _getBoxName(String entityType) {
    switch (entityType) {
      case 'task':
        return 'tasks';
      case 'event':
        return 'events';
      case 'point':
        return 'points';
      case 'badge':
        return 'badges';
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  /// Handle sync complete callback
  void _handleSyncComplete(SyncResult result) {
    print('Sync complete: $result');

    if (result.conflicts > 0) {
      // Notify user about conflicts
      print('Warning: ${result.conflicts} conflicts need review');
    }
  }

  /// Handle sync error callback
  void _handleSyncError(String error) {
    print('Sync error: $error');
  }

  // ========== Legacy Compatibility (for gradual migration) ==========

  /// Flush offline queue (legacy method)
  Future<void> flushQueue() async {
    await performSync();
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final storageStats = await _localStorage.getStats();
    final queueStats = _syncQueue.getStats();

    return {
      'storage': storageStats,
      'queue': queueStats,
      'estimatedSyncTime': _syncQueue.estimateSyncTime().inSeconds,
    };
  }

  // ========== Vision & AI Operations (Requires Network) ==========

  Future<Map<String, dynamic>> uploadVision(
    String filename,
    List<int> bytes, {
    String description = "",
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/ai/vision_upload'));
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['description'] = description;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) return jsonDecode(body);
    throw Exception('Vision upload failed: ${res.statusCode} $body');
  }

  Future<Map<String, dynamic>> aiPlan(Map<String, dynamic> weekCtx) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final res = await http.post(
      Uri.parse('$baseUrl/ai/planner'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'weekContext': weekCtx}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('AI plan failed');
  }
}
