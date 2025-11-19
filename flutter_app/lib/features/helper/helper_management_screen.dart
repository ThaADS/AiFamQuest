import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/helper_models.dart';
import '../../providers/helper_provider.dart';

/// Helper Management Screen - For parents to manage active helpers
///
/// Features:
/// - List all active helpers
/// - View helper details and permissions
/// - Edit helper permissions
/// - Remove helpers
/// - View helper activity
class HelperManagementScreen extends ConsumerWidget {
  const HelperManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpersAsync = ref.watch(activeHelpersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Helpers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(activeHelpersProvider.notifier).refresh();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: helpersAsync.when(
        data: (helpers) => helpers.isEmpty
            ? _buildEmptyState(theme)
            : _buildHelpersList(context, ref, helpers),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Helpers',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite helpers to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load helpers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build helpers list
  Widget _buildHelpersList(
    BuildContext context,
    WidgetRef ref,
    List<HelperUser> helpers,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: helpers.length,
      itemBuilder: (context, index) {
        final helper = helpers[index];
        return _buildHelperCard(context, ref, helper);
      },
    );
  }

  /// Build helper card
  Widget _buildHelperCard(
    BuildContext context,
    WidgetRef ref,
    HelperUser helper,
  ) {
    final theme = Theme.of(context);
    final isActive = helper.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: InkWell(
        onTap: () => _showHelperDetails(context, ref, helper),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: helper.avatar != null
                        ? null
                        : Text(
                            helper.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          helper.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          helper.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.access_time,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? 'Active' : 'Expired',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              // Helper stats
              Row(
                children: [
                  _buildStatItem(
                    theme,
                    icon: Icons.assignment,
                    label: 'Tasks',
                    value: '${helper.tasksAssigned}',
                  ),
                  const SizedBox(width: 24),
                  _buildStatItem(
                    theme,
                    icon: Icons.calendar_today,
                    label: 'Days Left',
                    value: isActive ? '${helper.daysRemaining}' : '0',
                  ),
                  const SizedBox(width: 24),
                  _buildStatItem(
                    theme,
                    icon: Icons.access_time,
                    label: 'Last Seen',
                    value: helper.lastSeen != null
                        ? _formatLastSeen(helper.lastSeen!)
                        : 'Never',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showEditPermissions(context, ref, helper),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Permissions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _confirmRemoveHelper(context, ref, helper),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build stat item
  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Format last seen time
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Show helper details dialog
  void _showHelperDetails(
    BuildContext context,
    WidgetRef ref,
    HelperUser helper,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Text(
                  'Helper Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow(context, 'Name', helper.name),
                _buildDetailRow(context, 'Email', helper.email),
                _buildDetailRow(
                  context,
                  'Access Until',
                  DateFormat('MMM d, yyyy').format(helper.activeUntil),
                ),
                _buildDetailRow(
                  context,
                  'Tasks Assigned',
                  '${helper.tasksAssigned}',
                ),
                const SizedBox(height: 24),
                Text(
                  'Permissions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildPermissionRow(
                  context,
                  'View assigned tasks',
                  helper.permissions.canViewAssignedTasks,
                ),
                _buildPermissionRow(
                  context,
                  'Complete tasks',
                  helper.permissions.canCompleteTasks,
                ),
                _buildPermissionRow(
                  context,
                  'Upload photos',
                  helper.permissions.canUploadPhotos,
                ),
                _buildPermissionRow(
                  context,
                  'View points',
                  helper.permissions.canViewPoints,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Build detail row
  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build permission row
  Widget _buildPermissionRow(
    BuildContext context,
    String label,
    bool granted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: granted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              decoration: granted ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  /// Show edit permissions dialog
  void _showEditPermissions(
    BuildContext context,
    WidgetRef ref,
    HelperUser helper,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditPermissionsDialog(
        helper: helper,
        onSave: (permissions) async {
          try {
            await ref
                .read(activeHelpersProvider.notifier)
                .updatePermissions(helper.id, permissions);

            if (!context.mounted) return;
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissions updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update permissions: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
      ),
    );
  }

  /// Confirm remove helper
  void _confirmRemoveHelper(
    BuildContext context,
    WidgetRef ref,
    HelperUser helper,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Helper'),
        content: Text(
          'Are you sure you want to remove ${helper.name}?\n\nThey will lose access to your family tasks immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await ref
                    .read(activeHelpersProvider.notifier)
                    .removeHelper(helper.id);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${helper.name} removed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to remove helper: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// Edit Permissions Dialog
class _EditPermissionsDialog extends StatefulWidget {
  final HelperUser helper;
  final Function(HelperPermissions) onSave;

  const _EditPermissionsDialog({
    required this.helper,
    required this.onSave,
  });

  @override
  State<_EditPermissionsDialog> createState() => _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends State<_EditPermissionsDialog> {
  late HelperPermissions _permissions;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _permissions = widget.helper.permissions;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Permissions: ${widget.helper.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPermissionCheckbox(
              'View assigned tasks',
              _permissions.canViewAssignedTasks,
              (value) => setState(() {
                _permissions = _permissions.copyWith(canViewAssignedTasks: value);
              }),
            ),
            _buildPermissionCheckbox(
              'Complete tasks',
              _permissions.canCompleteTasks,
              (value) => setState(() {
                _permissions = _permissions.copyWith(canCompleteTasks: value);
              }),
            ),
            _buildPermissionCheckbox(
              'Upload photos',
              _permissions.canUploadPhotos,
              (value) => setState(() {
                _permissions = _permissions.copyWith(canUploadPhotos: value);
              }),
            ),
            _buildPermissionCheckbox(
              'View points',
              _permissions.canViewPoints,
              (value) => setState(() {
                _permissions = _permissions.copyWith(canViewPoints: value);
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  await widget.onSave(_permissions);
                  setState(() => _isSaving = false);
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildPermissionCheckbox(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
      contentPadding: EdgeInsets.zero,
    );
  }
}
