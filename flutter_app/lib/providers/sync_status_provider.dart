import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_queue_service.dart';
import '../services/conflict_resolver.dart';
import 'dart:async';

/// Sync status state model
class SyncStatusState {
  final bool isOnline;
  final SyncStatus syncStatus;
  final int pendingOperations;
  final int pendingConflicts;
  final int failedOperations;
  final String? lastError;
  final DateTime? lastSyncAt;

  SyncStatusState({
    required this.isOnline,
    required this.syncStatus,
    required this.pendingOperations,
    required this.pendingConflicts,
    required this.failedOperations,
    this.lastError,
    this.lastSyncAt,
  });

  SyncStatusState copyWith({
    bool? isOnline,
    SyncStatus? syncStatus,
    int? pendingOperations,
    int? pendingConflicts,
    int? failedOperations,
    String? lastError,
    DateTime? lastSyncAt,
  }) {
    return SyncStatusState(
      isOnline: isOnline ?? this.isOnline,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      pendingConflicts: pendingConflicts ?? this.pendingConflicts,
      failedOperations: failedOperations ?? this.failedOperations,
      lastError: lastError ?? this.lastError,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  bool get needsAttention =>
      pendingConflicts > 0 || failedOperations > 0 || !isOnline;

  bool get hasPending => pendingOperations > 0;

  String get statusText {
    if (!isOnline) return 'Offline';
    if (syncStatus == SyncStatus.syncing) return 'Syncing...';
    if (pendingConflicts > 0) return '$pendingConflicts conflicts';
    if (failedOperations > 0) return '$failedOperations failed';
    if (pendingOperations > 0) return '$pendingOperations pending';
    return 'Synced';
  }
}

/// Sync status provider
class SyncStatusNotifier extends StateNotifier<SyncStatusState> {
  SyncStatusNotifier()
      : super(SyncStatusState(
          isOnline: true,
          syncStatus: SyncStatus.idle,
          pendingOperations: 0,
          pendingConflicts: 0,
          failedOperations: 0,
        )) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _statsTimer;

  Future<void> _init() async {
    // Initialize sync queue service
    await SyncQueueService.instance.init();

    // Setup callbacks
    SyncQueueService.instance.onSyncStatusChanged = _handleSyncStatusChanged;
    SyncQueueService.instance.onConflictsDetected = _handleConflictsDetected;
    SyncQueueService.instance.onSyncComplete = _handleSyncComplete;

    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    // Update stats periodically
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateStats();
    });

    // Initial stats update (fire and forget)
    // ignore: unawaited_futures
    _updateStats();
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final isOnline = result != ConnectivityResult.none;
    state = state.copyWith(isOnline: isOnline);

    if (isOnline) {
      // Trigger sync when back online (fire and forget)
      Future(() => SyncQueueService.instance.scheduleSyncIfNeeded());
    }
  }

  void _handleSyncStatusChanged(SyncStatus status) {
    state = state.copyWith(syncStatus: status);
  }

  void _handleConflictsDetected(List<ConflictData> conflicts) {
    state = state.copyWith(pendingConflicts: conflicts.length);
  }

  void _handleSyncComplete(SyncSummary summary) {
    state = state.copyWith(
      lastSyncAt: DateTime.now(),
      syncStatus: summary.hasErrors ? SyncStatus.error : SyncStatus.idle,
    );
    _updateStats();
  }

  Future<void> _updateStats() async {
    try {
      final stats = await SyncQueueService.instance.getStats();
      state = state.copyWith(
        pendingOperations: stats.pendingOperations,
        pendingConflicts: stats.pendingConflicts,
        failedOperations: stats.failedOperations,
      );
    } catch (e) {
      // Ignore stats update errors
    }
  }

  /// Manual sync trigger
  Future<void> syncNow() async {
    try {
      final summary = await SyncQueueService.instance.forceSyncNow();
      if (summary.hasErrors) {
        state = state.copyWith(
          lastError: 'Sync completed with ${summary.failed} failures',
        );
      }
    } catch (e) {
      state = state.copyWith(
        lastError: e.toString(),
        syncStatus: SyncStatus.error,
      );
    }
  }

  /// Retry all failed operations
  Future<void> retryFailed() async {
    await SyncQueueService.instance.retryAllFailed();
    // ignore: unawaited_futures
    _updateStats();
  }

  /// Clear all pending operations (use with caution)
  Future<void> clearPending() async {
    await SyncQueueService.instance.clearAllPending();
    // ignore: unawaited_futures
    _updateStats();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _statsTimer?.cancel();
    super.dispose();
  }
}

/// Provider for sync status
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncStatusState>(
  (ref) => SyncStatusNotifier(),
);

/// Provider for pending operations count
final pendingOperationsCountProvider = Provider<int>((ref) {
  return ref.watch(syncStatusProvider).pendingOperations;
});

/// Provider for pending conflicts count
final pendingConflictsCountProvider = Provider<int>((ref) {
  return ref.watch(syncStatusProvider).pendingConflicts;
});

/// Provider for online/offline status
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(syncStatusProvider).isOnline;
});

/// Provider for needs attention indicator
final needsAttentionProvider = Provider<bool>((ref) {
  return ref.watch(syncStatusProvider).needsAttention;
});
