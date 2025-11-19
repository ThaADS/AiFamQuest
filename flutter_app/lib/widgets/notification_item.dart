/// Notification Item Widget
///
/// Displays a single notification with:
/// - Icon based on notification type
/// - Title and body text
/// - Time ago timestamp
/// - Visual distinction for unread (bold + colored background)
/// - Swipe-to-delete gesture
/// - Tap to navigate to related screen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_models.dart';
import '../providers/notification_provider.dart';

class NotificationItem extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine background color based on read status
    final backgroundColor = notification.isRead
        ? Colors.transparent
        : colorScheme.primaryContainer.withValues(alpha: 0.1);

    // Text styles
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
      color: notification.isRead ? null : colorScheme.primary,
    );

    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.textTheme.bodySmall?.color,
    );

    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
      fontSize: 12,
    );

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text('Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        return confirmed ?? false;
      },
      onDismissed: (direction) {
        // Delete notification
        ref
            .read(notificationProvider.notifier)
            .deleteNotification(notification.id);

        // Show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
              },
            ),
          ),
        );

        onDelete?.call();
      },
      child: InkWell(
        onTap: () {
          // Mark as read if unread
          if (!notification.isRead) {
            ref
                .read(notificationProvider.notifier)
                .markAsRead(notification.id);
          }

          onTap?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              _buildNotificationIcon(context),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      notification.title,
                      style: titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Body
                    Text(
                      notification.body,
                      style: bodyStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Time ago
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: timeStyle?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notification.timeAgo,
                          style: timeStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build notification icon based on type
  Widget _buildNotificationIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Icon background color based on category
    Color iconBackgroundColor;

    switch (notification.category) {
      case 'tasks':
        iconBackgroundColor = Colors.blue.withValues(alpha: 0.2);
        break;
      case 'approvals':
        iconBackgroundColor = Colors.orange.withValues(alpha: 0.2);
        break;
      case 'points':
        iconBackgroundColor = Colors.green.withValues(alpha: 0.2);
        break;
      case 'events':
        iconBackgroundColor = Colors.purple.withValues(alpha: 0.2);
        break;
      default:
        iconBackgroundColor = colorScheme.surfaceContainerHighest;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconBackgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        notification.icon,
        style: const TextStyle(fontSize: 24),
      ),
    );
  }
}

/// Empty state widget for notification center
class EmptyNotificationState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyNotificationState({
    super.key,
    this.message = 'No notifications yet',
    this.icon = Icons.notifications_none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
