import 'dart:async';
import 'dart:math' as math;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Sync queue service for tracking pending API operations
/// Implements exponential backoff retry logic and queue persistence
class SyncQueue {
  static final SyncQueue instance = SyncQueue._();
  SyncQueue._();

  late Box<dynamic> _queueBox;
  late Box<dynamic> _failedBox;

  final _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool _initialized = false;
  bool _syncing = false;
  Timer? _intervalTimer;

  // Callbacks for sync events
  Function(SyncResult)? onSyncComplete;
  Function(String)? onSyncError;
  Function(int)? onQueueSizeChanged;

  /// Initialize sync queue
  Future<void> init() async {
    if (_initialized) return;

    _queueBox = await Hive.openBox('sync_queue');
    _failedBox = await Hive.openBox('failed_queue');

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // Network is back online, trigger sync
        scheduleSyncIfNeeded();
      }
    });

    // Setup interval timer (every 5 minutes)
    _intervalTimer = Timer.periodic(Duration(minutes: 5), (_) {
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

  /// Enqueue a sync operation
  Future<void> enqueue(SyncOperation operation) async {
    final id = operation.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    operation.id = id;
    operation.queuedAt ??= DateTime.now().toUtc();
    operation.retryCount ??= 0;

    await _queueBox.put(id, operation.toJson());

    // Notify queue size changed
    onQueueSizeChanged?.call(_queueBox.length);

    // Trigger sync if not already syncing
    scheduleSyncIfNeeded();
  }

  /// Get all pending operations
  Future<List<SyncOperation>> getPendingOperations() async {
    return _queueBox.values
        .map((e) => SyncOperation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Get queue size
  int getQueueSize() {
    return _queueBox.length;
  }

  /// Clear operation from queue
  Future<void> clearOperation(String id) async {
    await _queueBox.delete(id);
    onQueueSizeChanged?.call(_queueBox.length);
  }

  /// Clear multiple operations
  Future<void> clearOperationsBatch(List<String> ids) async {
    await _queueBox.deleteAll(ids);
    onQueueSizeChanged?.call(_queueBox.length);
  }

  /// Clear all operations
  Future<void> clearAll() async {
    await _queueBox.clear();
    onQueueSizeChanged?.call(0);
  }

  // ========== Failed Queue Operations ==========

  /// Move operation to failed queue
  Future<void> moveToFailed(SyncOperation operation) async {
    final id = operation.id!;
    await _failedBox.put(id, operation.toJson());
    await _queueBox.delete(id);
    onQueueSizeChanged?.call(_queueBox.length);
  }

  /// Get all failed operations
  Future<List<SyncOperation>> getFailedOperations() async {
    return _failedBox.values
        .map((e) => SyncOperation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Retry all failed operations
  Future<void> retryAllFailed() async {
    final failed = await getFailedOperations();

    for (final operation in failed) {
      // Reset retry count
      operation.retryCount = 0;
      operation.errorMessage = null;
      operation.lastAttemptAt = null;

      // Move back to pending queue
      await _queueBox.put(operation.id!, operation.toJson());
      await _failedBox.delete(operation.id!);
    }

    onQueueSizeChanged?.call(_queueBox.length);
    scheduleSyncIfNeeded();
  }

  /// Clear all failed operations
  Future<void> clearFailed() async {
    await _failedBox.clear();
  }

  // ========== Sync Scheduling ==========

  /// Schedule sync if needed (debounced)
  void scheduleSyncIfNeeded() {
    if (_syncing) return; // Already syncing
    if (_queueBox.isEmpty) return; // Nothing to sync

    // Check connectivity
    _connectivity.checkConnectivity().then((result) {
      if (result == ConnectivityResult.none) {
        return; // No network
      }

      // Trigger sync
      performSync();
    });
  }

  /// Perform sync (process queue)
  Future<SyncResult> performSync() async {
    if (_syncing) {
      return SyncResult(
        synced: 0,
        failed: 0,
        conflicts: 0,
        skipped: 0,
      );
    }

    _syncing = true;

    int synced = 0;
    int failed = 0;
    int skipped = 0;

    try {
      final operations = await getPendingOperations();

      for (final operation in operations) {
        // Check if should retry (exponential backoff)
        if (!_shouldRetry(operation)) {
          skipped++;
          continue;
        }

        try {
          // Attempt to sync operation
          await _syncOperation(operation);

          // Success - remove from queue
          await clearOperation(operation.id!);
          synced++;
        } catch (e) {
          // Failure - increment retry count
          operation.retryCount = (operation.retryCount ?? 0) + 1;
          operation.lastAttemptAt = DateTime.now().toUtc();
          operation.errorMessage = e.toString();

          // Check if should move to failed queue (max 5 retries)
          if (operation.retryCount! >= 5) {
            await moveToFailed(operation);
            failed++;
          } else {
            // Update operation in queue
            await _queueBox.put(operation.id!, operation.toJson());
          }
        }
      }

      final result = SyncResult(
        synced: synced,
        failed: failed,
        conflicts: 0, // Will be set by conflict resolver
        skipped: skipped,
      );

      onSyncComplete?.call(result);
      return result;
    } catch (e) {
      onSyncError?.call(e.toString());
      rethrow;
    } finally {
      _syncing = false;
    }
  }

  /// Check if operation should be retried (exponential backoff)
  bool _shouldRetry(SyncOperation operation) {
    if (operation.lastAttemptAt == null) {
      return true; // Never attempted
    }

    final retryCount = operation.retryCount ?? 0;
    final backoffSeconds = _getBackoffSeconds(retryCount);
    final nextRetryAt = operation.lastAttemptAt!.add(Duration(seconds: backoffSeconds));

    return DateTime.now().toUtc().isAfter(nextRetryAt);
  }

  /// Calculate exponential backoff delay
  int _getBackoffSeconds(int retryCount) {
    // 1s, 2s, 4s, 8s, 16s (max 16s)
    return math.min(math.pow(2, retryCount).toInt(), 16);
  }

  /// Sync a single operation (stub - will be implemented by ApiClient)
  Future<void> _syncOperation(SyncOperation operation) async {
    // This is a stub - actual implementation will be in ApiClient
    // ApiClient will call this method with actual HTTP requests
    throw UnimplementedError('_syncOperation must be implemented by ApiClient');
  }

  // ========== Statistics ==========

  /// Get queue statistics
  Map<String, dynamic> getStats() {
    return {
      'pending': _queueBox.length,
      'failed': _failedBox.length,
      'syncing': _syncing,
    };
  }

  /// Estimate sync time (100ms per operation)
  Duration estimateSyncTime() {
    return Duration(milliseconds: _queueBox.length * 100);
  }
}

/// Sync operation model
class SyncOperation {
  String? id;
  String entityType; // "task", "event", "point", etc.
  String operation; // "create", "update", "delete"
  String entityId;
  Map<String, dynamic> data;
  int? retryCount;
  DateTime? queuedAt;
  DateTime? lastAttemptAt;
  String? errorMessage;

  SyncOperation({
    this.id,
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.data,
    this.retryCount,
    this.queuedAt,
    this.lastAttemptAt,
    this.errorMessage,
  });

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'],
      entityType: json['entityType'],
      operation: json['operation'],
      entityId: json['entityId'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      retryCount: json['retryCount'],
      queuedAt: json['queuedAt'] != null ? DateTime.parse(json['queuedAt']) : null,
      lastAttemptAt: json['lastAttemptAt'] != null ? DateTime.parse(json['lastAttemptAt']) : null,
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'operation': operation,
      'entityId': entityId,
      'data': data,
      'retryCount': retryCount,
      'queuedAt': queuedAt?.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }
}

/// Sync result model
class SyncResult {
  final int synced;
  final int failed;
  final int conflicts;
  final int skipped;

  SyncResult({
    required this.synced,
    required this.failed,
    required this.conflicts,
    required this.skipped,
  });

  int get total => synced + failed + conflicts + skipped;

  bool get hasErrors => failed > 0 || conflicts > 0;

  bool get isSuccess => failed == 0 && conflicts == 0;

  @override
  String toString() {
    return 'SyncResult(synced: $synced, failed: $failed, conflicts: $conflicts, skipped: $skipped)';
  }
}
