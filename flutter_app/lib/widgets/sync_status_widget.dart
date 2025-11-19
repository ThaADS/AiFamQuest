import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_status_provider.dart';
import '../services/sync_queue_service.dart';

/// Sync status indicator for AppBar
/// Shows sync status, pending operations, and conflicts
class SyncStatusWidget extends ConsumerWidget {
  final bool showLabel;
  final Color? iconColor;

  const SyncStatusWidget({
    super.key,
    this.showLabel = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () => _showSyncStatusSheet(context, ref),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBackgroundColor(syncState).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBackgroundColor(syncState).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(syncState, effectiveIconColor),
            if (showLabel || syncState.needsAttention) ...[
              const SizedBox(width: 4),
              Text(
                _getStatusLabel(syncState),
                style: TextStyle(
                  color: _getBackgroundColor(syncState),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (syncState.hasPending) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(syncState),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${syncState.pendingOperations}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SyncStatusState state, Color color) {
    if (!state.isOnline) {
      return const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange);
    }

    switch (state.syncStatus) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case SyncStatus.conflicts:
        return const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red);
      case SyncStatus.error:
        return const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
      case SyncStatus.idle:
        if (state.hasPending) {
          return const Icon(Icons.sync, size: 16, color: Colors.blue);
        }
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
    }
  }

  Color _getBackgroundColor(SyncStatusState state) {
    if (!state.isOnline) return Colors.orange;
    if (state.pendingConflicts > 0) return Colors.red;
    if (state.failedOperations > 0) return Colors.red;
    if (state.syncStatus == SyncStatus.syncing) return Colors.blue;
    if (state.hasPending) return Colors.blue;
    return Colors.green;
  }

  String _getStatusLabel(SyncStatusState state) {
    if (!state.isOnline) return 'Offline';
    if (state.syncStatus == SyncStatus.syncing) return 'Syncing';
    if (state.pendingConflicts > 0) return '${state.pendingConflicts} conflicts';
    if (state.failedOperations > 0) return '${state.failedOperations} failed';
    if (state.hasPending) return '${state.pendingOperations} pending';
    return 'Synced';
  }

  void _showSyncStatusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const SyncStatusSheet(),
    );
  }
}

/// Detailed sync status bottom sheet
class SyncStatusSheet extends ConsumerWidget {
  const SyncStatusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.sync_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Status',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      syncState.statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status items
          _buildStatusItem(
            icon: Icons.devices,
            label: 'Connection',
            value: syncState.isOnline ? 'Online' : 'Offline',
            color: syncState.isOnline ? Colors.green : Colors.orange,
          ),
          _buildStatusItem(
            icon: Icons.pending_actions,
            label: 'Pending Operations',
            value: '${syncState.pendingOperations}',
            color: syncState.hasPending ? Colors.blue : Colors.grey,
          ),
          _buildStatusItem(
            icon: Icons.warning_amber_rounded,
            label: 'Conflicts',
            value: '${syncState.pendingConflicts}',
            color: syncState.pendingConflicts > 0 ? Colors.red : Colors.grey,
          ),
          _buildStatusItem(
            icon: Icons.error_outline_rounded,
            label: 'Failed Operations',
            value: '${syncState.failedOperations}',
            color: syncState.failedOperations > 0 ? Colors.red : Colors.grey,
          ),
          if (syncState.lastSyncAt != null)
            _buildStatusItem(
              icon: Icons.schedule,
              label: 'Last Sync',
              value: _formatLastSync(syncState.lastSyncAt!),
              color: Colors.grey,
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              if (syncState.hasPending || syncState.failedOperations > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(syncStatusProvider.notifier).syncNow();
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Sync Now'),
                  ),
                ),
              if (syncState.failedOperations > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(syncStatusProvider.notifier).retryFailed();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry Failed'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (syncState.pendingConflicts > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToConflictsScreen(context);
                },
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('Resolve Conflicts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _navigateToConflictsScreen(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conflicts screen not yet implemented'),
      ),
    );
  }
}
