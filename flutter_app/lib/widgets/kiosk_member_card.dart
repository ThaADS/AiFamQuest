/// Kiosk member card widget
///
/// Large card displaying family member with:
/// - Avatar (80dp)
/// - Name
/// - Task completion progress
/// - Compact task list
/// - Points display

import 'package:flutter/material.dart';
import '../models/kiosk_models.dart';

class KioskMemberCard extends StatelessWidget {
  final KioskMember member;

  const KioskMemberCard({
    super.key,
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = member.completedCount;
    final totalCount = member.totalTaskCount;
    final completionRate = member.completionRate;

    // Determine color based on completion
    final progressColor = completionRate == 1.0
      ? Colors.green
      : completionRate >= 0.5
        ? Colors.blue
        : Colors.orange;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar with completion ring
            Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: completionRate,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(progressColor),
                  ),
                ),
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: member.avatar.isNotEmpty
                    ? NetworkImage(member.avatar)
                    : null,
                  child: member.avatar.isEmpty
                    ? Text(
                        member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              member.displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Task completion count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: progressColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$completedCount / $totalCount tasks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: progressColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Points display (if available)
            if (member.weeklyPoints > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${member.weeklyPoints} pts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Divider
            if (member.tasks.isNotEmpty)
              Divider(color: theme.colorScheme.outlineVariant),

            // Task list (compact)
            if (member.tasks.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: member.tasks.length,
                  itemBuilder: (context, index) {
                    final task = member.tasks[index];
                    return _TaskItem(task: task);
                  },
                ),
              ),

            // Empty state
            if (member.tasks.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No tasks today',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Individual task item in member card
class _TaskItem extends StatelessWidget {
  final KioskTask task;

  const _TaskItem({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Completion icon
          Icon(
            task.completed ? Icons.check_circle : Icons.circle_outlined,
            color: task.completed ? Colors.green : theme.colorScheme.outline,
            size: 22,
          ),
          const SizedBox(width: 12),

          // Task title
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 15,
                decoration: task.completed
                  ? TextDecoration.lineThrough
                  : null,
                color: task.completed
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Points badge
          if (task.pointValue != null && task.pointValue! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${task.pointValue}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
