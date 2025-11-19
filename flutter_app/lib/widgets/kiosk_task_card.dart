/// Kiosk task card widget
///
/// Large card displaying individual tasks in kiosk mode with:
/// - Task title
/// - Completion status
/// - Point value
/// - Countdown timer for due tasks
/// - Category icon
/// - Celebratory animation on completion

import 'package:flutter/material.dart';
import '../models/kiosk_models.dart';
import 'package:intl/intl.dart';

class KioskTaskCard extends StatelessWidget {
  final KioskTask task;
  final bool showCategory;
  final VoidCallback? onTap;

  const KioskTaskCard({
    super.key,
    required this.task,
    this.showCategory = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        !task.completed;

    return Card(
      elevation: task.completed ? 1 : 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Completion checkbox
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.completed
                      ? Colors.green
                      : theme.colorScheme.surfaceContainerHighest,
                  border: task.completed
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outline,
                          width: 2,
                        ),
                ),
                child: task.completed
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(width: 20),

              // Task details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task title
                    Text(
                      task.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration:
                            task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                        fontSize: 20,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Due time/countdown
                    if (task.dueDate != null && !task.completed) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isOverdue ? Icons.warning_amber : Icons.access_time,
                            size: 18,
                            color: isOverdue
                                ? Colors.red
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getTimeDisplay(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isOverdue
                                  ? Colors.red
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Points badge
              if (task.pointValue != null && task.pointValue! > 0) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: task.completed
                        ? Colors.green.withValues(alpha: 0.1)
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: task.completed
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars,
                        size: 20,
                        color: task.completed
                            ? Colors.green
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${task.pointValue}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: task.completed
                              ? Colors.green
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get time display for due date
  String _getTimeDisplay() {
    if (task.dueDate == null) return '';

    final now = DateTime.now();
    final due = task.dueDate!;
    final difference = due.difference(now);

    // Overdue
    if (difference.isNegative) {
      final overdue = now.difference(due);
      if (overdue.inHours < 1) {
        return 'Overdue by ${overdue.inMinutes}m';
      } else if (overdue.inDays < 1) {
        return 'Overdue by ${overdue.inHours}h';
      } else {
        return 'Overdue by ${overdue.inDays}d';
      }
    }

    // Due soon
    if (difference.inMinutes < 60) {
      return 'Due in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Due in ${difference.inHours}h';
    } else {
      return 'Due ${DateFormat('MMM d, h:mm a').format(due)}';
    }
  }
}

/// Celebration animation widget for completed tasks
class TaskCompletionCelebration extends StatefulWidget {
  final Widget child;

  const TaskCompletionCelebration({
    super.key,
    required this.child,
  });

  @override
  State<TaskCompletionCelebration> createState() =>
      _TaskCompletionCelebrationState();
}

class _TaskCompletionCelebrationState extends State<TaskCompletionCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
