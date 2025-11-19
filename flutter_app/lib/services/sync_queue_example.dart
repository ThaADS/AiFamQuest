/// Example usage of SyncQueueService for FamQuest
///
/// This file demonstrates common sync queue patterns and workflows

import 'dart:async';
import 'package:flutter/material.dart';
import 'sync_queue_service.dart';
import 'conflict_resolver.dart';
import 'local_storage.dart';
import '../widgets/conflict_dialog.dart';
import '../core/app_logger.dart';

/// Example 1: Initialize sync queue on app startup
Future<void> initializeSyncQueue() async {
  // Initialize storage first
  await FamQuestStorage.instance.init();

  // Initialize sync queue service
  await SyncQueueService.instance.init();

  // Setup callbacks
  SyncQueueService.instance.onSyncStatusChanged = (status) {
    AppLogger.debug('Sync status changed: $status');
  };

  SyncQueueService.instance.onConflictsDetected = (conflicts) {
    AppLogger.debug('Conflicts detected: ${conflicts.length}');
    // Show notification or dialog
  };

  SyncQueueService.instance.onSyncComplete = (summary) {
    AppLogger.debug('Sync complete: ${summary.toString()}');
  };

  AppLogger.debug('Sync queue initialized successfully');
}

/// Example 2: Create task offline
Future<void> createTaskOffline(Map<String, dynamic> taskData) async {
  // Add task to local storage
  final taskId = taskData['id'];

  // Store locally
  await FamQuestStorage.instance.put('tasks', taskId, taskData);

  // Add to sync queue
  await SyncQueueService.instance.addToQueue(
    entityType: 'tasks',
    entityId: taskId,
    data: taskData,
    operation: 'create',
  );

  AppLogger.debug('Task created offline and queued for sync');
}

/// Example 3: Update task offline
Future<void> updateTaskOffline(
  String taskId,
  Map<String, dynamic> updates,
) async {
  // Get current task
  final task = await FamQuestStorage.instance.get('tasks', taskId);

  if (task == null) {
    throw Exception('Task not found');
  }

  // Apply updates
  task.addAll(updates);

  // Update version
  task['version'] = (task['version'] ?? 1) + 1;
  task['updatedAt'] = DateTime.now().toUtc().toIso8601String();

  // Store locally
  await FamQuestStorage.instance.put('tasks', taskId, task);

  // Add to sync queue
  await SyncQueueService.instance.addToQueue(
    entityType: 'tasks',
    entityId: taskId,
    data: task,
    operation: 'update',
  );

  AppLogger.debug('Task updated offline and queued for sync');
}

/// Example 4: Delete task offline
Future<void> deleteTaskOffline(String taskId) async {
  // Get current task for version
  final task = await FamQuestStorage.instance.get('tasks', taskId);

  if (task == null) {
    throw Exception('Task not found');
  }

  // Mark as deleted (soft delete)
  await FamQuestStorage.instance.delete('tasks', taskId);

  // Add to sync queue
  await SyncQueueService.instance.addToQueue(
    entityType: 'tasks',
    entityId: taskId,
    data: task,
    operation: 'delete',
  );

  AppLogger.debug('Task deleted offline and queued for sync');
}

/// Example 5: Sync on network reconnection
class SyncQueueMonitor extends StatefulWidget {
  final Widget child;

  const SyncQueueMonitor({Key? key, required this.child}) : super(key: key);

  @override
  State<SyncQueueMonitor> createState() => _SyncQueueMonitorState();
}

class _SyncQueueMonitorState extends State<SyncQueueMonitor> {
  StreamSubscription<SyncStatus>? _statusSubscription;
  SyncStatus _status = SyncStatus.idle;
  SyncQueueStats? _stats;

  @override
  void initState() {
    super.initState();
    _initMonitoring();
  }

  Future<void> _initMonitoring() async {
    // Load initial stats
    _stats = await SyncQueueService.instance.getStats();
    setState(() {});

    // Listen to sync status changes
    SyncQueueService.instance.onSyncStatusChanged = (status) {
      setState(() {
        _status = status;
      });
    };

    // Listen to conflicts
    SyncQueueService.instance.onConflictsDetected = (conflicts) async {
      // Show conflicts screen or notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${conflicts.length} sync conflicts detected'),
            action: SnackBarAction(
              label: 'Review',
              onPressed: () {
                // Navigate to conflict resolution screen
              },
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    };

    // Listen to sync completion
    SyncQueueService.instance.onSyncComplete = (summary) async {
      _stats = await SyncQueueService.instance.getStats();
      setState(() {});

      if (summary.hasErrors && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync completed with errors: ${summary.failed} failed, ${summary.conflicts} conflicts',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    // Periodic stats refresh
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        _stats = await SyncQueueService.instance.getStats();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Sync status indicator (top-right)
        Positioned(
          top: 48,
          right: 16,
          child: _buildSyncIndicator(),
        ),
      ],
    );
  }

  Widget _buildSyncIndicator() {
    if (_stats == null) return const SizedBox.shrink();

    // Syncing
    if (_status == SyncStatus.syncing) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Syncing...',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Conflicts
    if (_stats!.hasConflicts) {
      return GestureDetector(
        onTap: () {
          // Navigate to conflict resolution
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync_problem, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_stats!.pendingConflicts}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Pending sync
    if (_stats!.totalPending > 0) {
      return GestureDetector(
        onTap: () async {
          await SyncQueueService.instance.forceSyncNow();
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_upload, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_stats!.totalPending}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // All synced
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.cloud_done, color: Colors.white, size: 16),
    );
  }
}

/// Example 6: Handle conflicts in UI
Future<void> handleConflictInUI(
  BuildContext context,
  ConflictData conflict,
) async {
  // Show conflict dialog
  await showConflictDialog(
    context,
    conflict,
    (resolution) async {
      // User chose resolution
      await SyncQueueService.instance.resolveConflictManual(
        conflict,
        resolution,
      );

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Trigger sync
      SyncQueueService.instance.scheduleSyncIfNeeded();
    },
  );
}

/// Example 7: Batch auto-resolve conflicts
Future<void> autoResolveAllConflicts(BuildContext context) async {
  final result = await SyncQueueService.instance.resolveConflictsBatch();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Auto-resolved ${result.resolved} conflicts. '
          '${result.needsManual} need manual review.',
        ),
        backgroundColor: result.allResolved ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

/// Example 8: Retry failed operations
Future<void> retryFailedOperations(BuildContext context) async {
  await SyncQueueService.instance.retryAllFailed();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrying all failed operations...'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

/// Example 9: Emergency reset (data loss!)
Future<void> emergencyResetSyncState(BuildContext context) async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset Sync State?'),
      content: const Text(
        'This will clear all pending operations and conflicts. '
        'Unsynced changes will be lost. Continue?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Reset'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await SyncQueueService.instance.resetSyncState();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync state reset successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

/// Example 10: Monitor sync statistics
class SyncStatsDebugWidget extends StatefulWidget {
  const SyncStatsDebugWidget({Key? key}) : super(key: key);

  @override
  State<SyncStatsDebugWidget> createState() => _SyncStatsDebugWidgetState();
}

class _SyncStatsDebugWidgetState extends State<SyncStatsDebugWidget> {
  SyncQueueStats? _stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final stats = await SyncQueueService.instance.getStats();
    setState(() {
      _stats = stats;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stats == null) return const CircularProgressIndicator();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Queue Stats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Pending Operations', _stats!.pendingOperations),
            _buildStatRow('Failed Operations', _stats!.failedOperations),
            _buildStatRow('Pending Conflicts', _stats!.pendingConflicts),
            _buildStatRow('Pending Photos', _stats!.pendingPhotos),
            _buildStatRow('Dirty Tasks', _stats!.dirtyTasks),
            _buildStatRow('Dirty Events', _stats!.dirtyEvents),
            const Divider(),
            _buildStatRow('Total Pending', _stats!.totalPending),
            const SizedBox(height: 8),
            Text(
              'Status: ${_stats!.isSyncing ? 'Syncing' : 'Idle'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _stats!.isSyncing ? Colors.blue : Colors.green,
              ),
            ),
            if (_stats!.needsAttention) ...[
              const SizedBox(height: 8),
              Text(
                'Needs Attention: ${_stats!.hasConflicts ? 'Conflicts' : 'Failures'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
