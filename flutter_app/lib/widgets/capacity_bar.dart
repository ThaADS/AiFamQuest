import 'package:flutter/material.dart';
import '../models/fairness_models.dart';

/// Reusable capacity bar widget showing user workload
///
/// Displays:
/// - User avatar and name
/// - Horizontal progress bar (0-150% capacity)
/// - Hours used / total capacity
/// - Percentage with color coding
class CapacityBar extends StatelessWidget {
  final UserWorkload workload;
  final VoidCallback? onTap;

  const CapacityBar({
    super.key,
    required this.workload,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getStatusColor(theme);
    final percentage = workload.percentage.clamp(0, 150);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: workload.userAvatar != null
                    ? NetworkImage(workload.userAvatar!)
                    : null,
                child: workload.userAvatar == null
                    ? Text(
                        _getInitials(workload.userName ?? 'U'),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Progress and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workload.userName ?? 'Unknown',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(context, workload.status, color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Hours and percentage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${workload.usedHours.toStringAsFixed(1)}h / ${workload.totalCapacity.toStringAsFixed(0)}h',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${workload.tasksCompleted} tasks',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${workload.percentage.toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get color based on capacity status
  Color _getStatusColor(ThemeData theme) {
    switch (workload.status) {
      case CapacityStatus.light:
        return Colors.green;
      case CapacityStatus.moderate:
        return Colors.blue;
      case CapacityStatus.high:
        return Colors.orange;
      case CapacityStatus.overloaded:
        return Colors.red;
    }
  }

  /// Get user initials from name
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Build status chip based on capacity
  Widget _buildStatusChip(BuildContext context, CapacityStatus status, Color color) {
    final theme = Theme.of(context);
    String label;
    IconData icon;

    switch (status) {
      case CapacityStatus.light:
        label = 'Light';
        icon = Icons.trending_down;
        break;
      case CapacityStatus.moderate:
        label = 'Moderate';
        icon = Icons.trending_flat;
        break;
      case CapacityStatus.high:
        label = 'High';
        icon = Icons.trending_up;
        break;
      case CapacityStatus.overloaded:
        label = 'Overloaded';
        icon = Icons.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
