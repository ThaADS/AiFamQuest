/// Comprehensive sync queue service for FamQuest
///
/// Integrates with:
/// - FamQuestStorage for local persistence
/// - SyncQueue for queue management
/// - ConflictResolver for conflict resolution
/// - ApiClient for server communication

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../api/client.dart';
import 'local_storage.dart';
import 'sync_queue.dart';
import 'conflict_resolver.dart';
import 'photo_cache_service.dart';

/// Main sync queue service coordinating all offline sync operations
class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._();
  SyncQueueService._();

  final _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _intervalTimer;
  bool _syncing = false;
  bool _initialized = false;

  // Callbacks for sync events
  Function(SyncStatus)? onSyncStatusChanged;
  Function(List<ConflictData>)? onConflictsDetected;
  Function(SyncSummary)? onSyncComplete;

  /// Initialize sync queue service
  Future<void> init() async {
    if (_initialized) return;

    // Initialize dependencies
    await FamQuestStorage.instance.init();
    await SyncQueue.instance.init();
    await PhotoCacheService.instance.initialize();

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      // Trigger sync when we regain connectivity
      if (result != ConnectivityResult.none) {
        scheduleSyncIfNeeded();
      }
    });

    // Setup interval timer (every 5 minutes)
    _intervalTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      scheduleSyncIfNeeded();
    });

    _initialized = true;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _intervalTimer?.cancel();
  }

  // ========== Queue Operations ==========

  /// Add entity change to sync queue
  Future<void> addToQueue({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
    required String operation, // 'create', 'update', 'delete'
  }) async {
    final syncOp = SyncOperation(
      id: const Uuid().v4(),
      entityType: entityType,
      operation: operation,
      entityId: entityId,
      data: data,
      queuedAt: DateTime.now().toUtc(),
      retryCount: 0,
    );

    await SyncQueue.instance.enqueue(syncOp);

    // Update local storage
    if (operation == 'delete') {
      await FamQuestStorage.instance.delete(entityType, entityId);
    } else {
      await FamQuestStorage.instance.put(entityType, entityId, data);
    }
  }

  /// Get pending sync operations count
  int getPendingCount() {
    return SyncQueue.instance.getQueueSize();
  }

  /// Schedule sync if not already syncing
  void scheduleSyncIfNeeded() {
    if (_syncing) return;
    if (SyncQueue.instance.getQueueSize() == 0) return;

    // Check connectivity
    _connectivity.checkConnectivity().then((result) {
      if (result == ConnectivityResult.none) return; // No network

      // Trigger sync
      performSync();
    });
  }

  // ========== Sync Execution ==========

  /// Perform full sync of all pending operations
  Future<SyncSummary> performSync() async {
    if (_syncing) {
      return SyncSummary(
        synced: 0,
        failed: 0,
        conflicts: 0,
        skipped: 0,
        photosUploaded: 0,
      );
    }

    _syncing = true;
    onSyncStatusChanged?.call(SyncStatus.syncing);

    int synced = 0;
    int failed = 0;
    int conflicts = 0;
    const int skipped = 0;
    int photosUploaded = 0;

    final detectedConflicts = <ConflictData>[];

    try {
      // Step 1: Sync photos first
      final photoResults = await PhotoCacheService.instance.syncPhotos();
      photosUploaded = photoResults.length;

      // Step 2: Process sync queue (batch of 10 operations)
      final operations = await SyncQueue.instance.getPendingOperations();
      final batch = operations.take(10).toList();

      for (final operation in batch) {
        try {
          // Attempt to sync operation
          final result = await _syncOperation(operation);

          if (result.hasConflict) {
            // Conflict detected - store for resolution
            detectedConflicts.add(result.conflict!);
            await FamQuestStorage.instance
                .storeConflict(result.conflict!.toJson());
            conflicts++;
          } else {
            // Success - remove from queue
            await SyncQueue.instance.clearOperation(operation.id!);

            // Update local storage
            if (result.syncedData != null) {
              await FamQuestStorage.instance.put(
                operation.entityType,
                operation.entityId,
                result.syncedData!,
              );
              await FamQuestStorage.instance.markClean(
                operation.entityType,
                operation.entityId,
              );
            }

            synced++;
          }
        } catch (e) {
          // Network error or server error
          operation.retryCount = (operation.retryCount ?? 0) + 1;
          operation.lastAttemptAt = DateTime.now().toUtc();
          operation.errorMessage = e.toString();

          // Move to failed queue after 5 retries
          if (operation.retryCount! >= 5) {
            await SyncQueue.instance.moveToFailed(operation);
            failed++;
          }
        }
      }

      // Notify conflicts detected
      if (detectedConflicts.isNotEmpty) {
        onConflictsDetected?.call(detectedConflicts);
      }

      final summary = SyncSummary(
        synced: synced,
        failed: failed,
        conflicts: conflicts,
        skipped: skipped,
        photosUploaded: photosUploaded,
      );

      onSyncStatusChanged?.call(
        conflicts > 0 ? SyncStatus.conflicts : SyncStatus.idle,
      );
      onSyncComplete?.call(summary);

      return summary;
    } catch (e) {
      onSyncStatusChanged?.call(SyncStatus.error);
      rethrow;
    } finally {
      _syncing = false;
    }
  }

  /// Sync a single operation with conflict detection
  Future<SyncOperationResult> _syncOperation(SyncOperation operation) async {
    final entityType = operation.entityType;
    final entityId = operation.entityId;
    final data = operation.data;
    final op = operation.operation;

    try {
      // Get current local version
      final localEntity =
          await FamQuestStorage.instance.get(entityType, entityId);
      final localVersion = localEntity?['version'] ?? 1;

      // Perform API call based on operation type
      Map<String, dynamic>? serverResponse;

      if (op == 'create') {
        serverResponse = await _createEntity(entityType, data);
      } else if (op == 'update') {
        serverResponse =
            await _updateEntity(entityType, entityId, data, localVersion);
      } else if (op == 'delete') {
        await _deleteEntity(entityType, entityId, localVersion);
        return SyncOperationResult(hasConflict: false);
      }

      // Check for version conflict (409 Conflict status)
      // This will be thrown as exception with conflict data

      return SyncOperationResult(
        hasConflict: false,
        syncedData: serverResponse,
      );
    } on ConflictException catch (e) {
      // Version conflict detected
      final conflict = ConflictData(
        id: const Uuid().v4(),
        entityType: entityType,
        entityId: entityId,
        clientVersion: data['version'] ?? 1,
        serverVersion: e.serverVersion,
        clientData: data,
        serverData: e.serverData,
        conflictType: 'version_mismatch',
      );

      return SyncOperationResult(
        hasConflict: true,
        conflict: conflict,
      );
    }
  }

  /// Create entity via API
  Future<Map<String, dynamic>> _createEntity(
    String entityType,
    Map<String, dynamic> data,
  ) async {
    switch (entityType) {
      case 'tasks':
        return ApiClient.instance.createTask(data);
      case 'events':
        throw UnimplementedError('Event creation not yet implemented');
      case 'points':
        throw UnimplementedError('Points ledger not yet implemented');
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  /// Update entity via API with version check
  Future<Map<String, dynamic>> _updateEntity(
    String entityType,
    String entityId,
    Map<String, dynamic> data,
    int version,
  ) async {
    // Add version to data for optimistic locking
    data['version'] = version;

    switch (entityType) {
      case 'tasks':
        throw UnimplementedError('Task update not yet implemented');
      case 'events':
        throw UnimplementedError('Event update not yet implemented');
      case 'points':
        throw UnimplementedError('Points update not yet implemented');
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  /// Delete entity via API with version check
  Future<void> _deleteEntity(
    String entityType,
    String entityId,
    int version,
  ) async {
    switch (entityType) {
      case 'tasks':
        throw UnimplementedError('Task delete not yet implemented');
      case 'events':
        throw UnimplementedError('Event delete not yet implemented');
      case 'points':
        throw UnimplementedError('Points delete not yet implemented');
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  // ========== Conflict Resolution ==========

  /// Get all pending conflicts
  Future<List<ConflictData>> getPendingConflicts() async {
    final conflicts = await FamQuestStorage.instance.getPendingConflicts();
    return conflicts.map((json) => ConflictData.fromJson(json)).toList();
  }

  /// Resolve conflict automatically
  Future<void> resolveConflictAuto(ConflictData conflict) async {
    final resolution = await ConflictResolver.instance.resolve(conflict);

    if (resolution.needsManualReview) {
      // Cannot auto-resolve, needs user intervention
      throw Exception('Conflict requires manual review');
    }

    await _applyResolution(conflict, resolution);
  }

  /// Resolve conflict manually with user choice
  Future<void> resolveConflictManual(
    ConflictData conflict,
    ConflictResolution resolution,
  ) async {
    await _applyResolution(conflict, resolution);
  }

  /// Apply conflict resolution
  Future<void> _applyResolution(
    ConflictData conflict,
    ConflictResolution resolution,
  ) async {
    if (resolution.resolvedData == null) {
      throw Exception('Resolution data is null');
    }

    // Update local storage with resolved data
    await FamQuestStorage.instance.put(
      conflict.entityType,
      conflict.entityId,
      resolution.resolvedData!,
    );

    // Mark local as clean
    await FamQuestStorage.instance.markClean(
      conflict.entityType,
      conflict.entityId,
    );

    // Mark conflict as resolved
    await FamQuestStorage.instance.markConflictResolved(conflict.id);

    // If client data was chosen, push to server
    if (resolution.strategy == ResolutionStrategy.lastWriterWins &&
        resolution.resolvedData == conflict.clientData) {
      // Force push client version to server
      await addToQueue(
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        data: resolution.resolvedData!,
        operation: 'update',
      );
    }
  }

  /// Batch resolve conflicts using auto-resolution
  Future<BatchResolutionResult> resolveConflictsBatch() async {
    final conflicts = await getPendingConflicts();
    int resolved = 0;
    int needsManual = 0;

    for (final conflict in conflicts) {
      try {
        final resolution = await ConflictResolver.instance.resolve(conflict);

        if (resolution.needsManualReview) {
          needsManual++;
        } else {
          await _applyResolution(conflict, resolution);
          resolved++;
        }
      } catch (e) {
        needsManual++;
      }
    }

    return BatchResolutionResult(
      resolved: resolved,
      needsManual: needsManual,
      total: conflicts.length,
    );
  }

  // ========== Statistics & Monitoring ==========

  /// Get sync queue statistics
  Future<SyncQueueStats> getStats() async {
    final pending = SyncQueue.instance.getQueueSize();
    final failed = (await SyncQueue.instance.getFailedOperations()).length;
    final conflicts = (await getPendingConflicts()).length;
    final photoQueue = await PhotoCacheService.instance.getQueueSize();

    final storageStats = await FamQuestStorage.instance.getStats();
    final dirtyTasks = storageStats['dirtyTasks'] as int;
    final dirtyEvents = storageStats['dirtyEvents'] as int;

    return SyncQueueStats(
      pendingOperations: pending,
      failedOperations: failed,
      pendingConflicts: conflicts,
      pendingPhotos: photoQueue,
      dirtyTasks: dirtyTasks,
      dirtyEvents: dirtyEvents,
      isSyncing: _syncing,
    );
  }

  /// Check if sync is needed
  Future<bool> needsSync() async {
    final stats = await getStats();
    return stats.pendingOperations > 0 ||
        stats.pendingPhotos > 0 ||
        stats.dirtyTasks > 0 ||
        stats.dirtyEvents > 0;
  }

  /// Estimate sync time
  Duration estimateSyncTime() {
    final pending = SyncQueue.instance.getQueueSize();
    return Duration(milliseconds: pending * 100); // 100ms per operation
  }

  // ========== Manual Controls ==========

  /// Force immediate sync
  Future<SyncSummary> forceSyncNow() async {
    return performSync();
  }

  /// Clear all pending operations (data loss!)
  Future<void> clearAllPending() async {
    await SyncQueue.instance.clearAll();
    await PhotoCacheService.instance.clearQueue();
  }

  /// Retry all failed operations
  Future<void> retryAllFailed() async {
    await SyncQueue.instance.retryAllFailed();
    scheduleSyncIfNeeded();
  }

  /// Reset sync state (emergency reset)
  Future<void> resetSyncState() async {
    await SyncQueue.instance.clearAll();
    await SyncQueue.instance.clearFailed();
    await PhotoCacheService.instance.clearQueue();

    // Mark all local entities as clean
    final tasks = await FamQuestStorage.instance.getAll('tasks');
    final taskIds = tasks.map((t) => t['id'] as String).toList();
    await FamQuestStorage.instance.markCleanBatch('tasks', taskIds);

    final events = await FamQuestStorage.instance.getAll('events');
    final eventIds = events.map((e) => e['id'] as String).toList();
    await FamQuestStorage.instance.markCleanBatch('events', eventIds);
  }
}

// ========== Models ==========

/// Sync operation result with conflict detection
class SyncOperationResult {
  final bool hasConflict;
  final ConflictData? conflict;
  final Map<String, dynamic>? syncedData;

  SyncOperationResult({
    required this.hasConflict,
    this.conflict,
    this.syncedData,
  });
}

/// Conflict exception thrown by API client
class ConflictException implements Exception {
  final int serverVersion;
  final Map<String, dynamic> serverData;
  final String message;

  ConflictException({
    required this.serverVersion,
    required this.serverData,
    this.message = 'Version conflict detected',
  });

  @override
  String toString() => message;
}

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  conflicts,
  error,
}

/// Sync summary after sync operation
class SyncSummary {
  final int synced;
  final int failed;
  final int conflicts;
  final int skipped;
  final int photosUploaded;

  SyncSummary({
    required this.synced,
    required this.failed,
    required this.conflicts,
    required this.skipped,
    required this.photosUploaded,
  });

  int get total => synced + failed + conflicts + skipped;
  bool get hasErrors => failed > 0 || conflicts > 0;
  bool get isSuccess => failed == 0 && conflicts == 0;

  @override
  String toString() {
    return 'SyncSummary(synced: $synced, failed: $failed, conflicts: $conflicts, skipped: $skipped, photos: $photosUploaded)';
  }
}

/// Batch resolution result
class BatchResolutionResult {
  final int resolved;
  final int needsManual;
  final int total;

  BatchResolutionResult({
    required this.resolved,
    required this.needsManual,
    required this.total,
  });

  bool get hasManual => needsManual > 0;
  bool get allResolved => needsManual == 0;
}

/// Sync queue statistics
class SyncQueueStats {
  final int pendingOperations;
  final int failedOperations;
  final int pendingConflicts;
  final int pendingPhotos;
  final int dirtyTasks;
  final int dirtyEvents;
  final bool isSyncing;

  SyncQueueStats({
    required this.pendingOperations,
    required this.failedOperations,
    required this.pendingConflicts,
    required this.pendingPhotos,
    required this.dirtyTasks,
    required this.dirtyEvents,
    required this.isSyncing,
  });

  int get totalPending =>
      pendingOperations + pendingPhotos + dirtyTasks + dirtyEvents;
  bool get hasConflicts => pendingConflicts > 0;
  bool get hasFailures => failedOperations > 0;
  bool get needsAttention => hasConflicts || hasFailures;

  Map<String, dynamic> toJson() {
    return {
      'pendingOperations': pendingOperations,
      'failedOperations': failedOperations,
      'pendingConflicts': pendingConflicts,
      'pendingPhotos': pendingPhotos,
      'dirtyTasks': dirtyTasks,
      'dirtyEvents': dirtyEvents,
      'isSyncing': isSyncing,
      'totalPending': totalPending,
      'hasConflicts': hasConflicts,
      'hasFailures': hasFailures,
      'needsAttention': needsAttention,
    };
  }
}
