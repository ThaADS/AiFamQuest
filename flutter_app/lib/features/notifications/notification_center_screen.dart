/// Notification Center Screen
///
/// Features:
/// - List all notifications (read/unread)
/// - Filter tabs: All, Unread, Tasks, Approvals, Points, Events
/// - Mark as read functionality
/// - Clear all notifications
/// - Pull-to-refresh
/// - Deep linking to related screens
/// - Real-time updates via Supabase

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/notification_models.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/notification_item.dart' show NotificationItem, EmptyNotificationState;
import '../../core/app_logger.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationFilter _currentFilter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: NotificationFilter.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentFilter = NotificationFilter.values[_tabController.index];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notificationState = ref.watch(notificationProvider);
    final filteredNotifications =
        ref.watch(filteredNotificationsProvider(_currentFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Mark all as read
          if (notificationState.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: () => _markAllAsRead(context),
            ),

          // Clear all
          if (notificationState.notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'clear_all') {
                  _clearAllNotifications(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, size: 20),
                      SizedBox(width: 12),
                      Text('Clear all notifications'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: NotificationFilter.values.map((filter) {
            final count = _getFilterCount(notificationState.notifications, filter);
            return Tab(
              child: Row(
                children: [
                  Text(filter.icon),
                  const SizedBox(width: 8),
                  Text(filter.displayName),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        count.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(notificationProvider.notifier).refresh();
        },
        child: _buildBody(context, notificationState, filteredNotifications),
      ),
    );
  }

  /// Build body based on state
  Widget _buildBody(
    BuildContext context,
    NotificationState state,
    List<AppNotification> filteredNotifications,
  ) {
    // Loading state
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error state
    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load notifications',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(notificationProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (filteredNotifications.isEmpty) {
      return EmptyNotificationState(
        message: _getEmptyMessage(_currentFilter),
        icon: _getEmptyIcon(_currentFilter),
      );
    }

    // Notification list
    return ListView.builder(
      itemCount: filteredNotifications.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final notification = filteredNotifications[index];
        return NotificationItem(
          notification: notification,
          onTap: () => _handleNotificationTap(context, notification),
          onDelete: () {
            // Already handled by NotificationItem's Dismissible
          },
        );
      },
    );
  }

  /// Get count for filter
  int _getFilterCount(List<AppNotification> notifications, NotificationFilter filter) {
    return notifications.where((n) => filter.matches(n)).length;
  }

  /// Get empty message for filter
  String _getEmptyMessage(NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return 'No notifications yet';
      case NotificationFilter.unread:
        return 'No unread notifications';
      case NotificationFilter.tasks:
        return 'No task notifications';
      case NotificationFilter.approvals:
        return 'No approval notifications';
      case NotificationFilter.points:
        return 'No points notifications';
      case NotificationFilter.events:
        return 'No event notifications';
    }
  }

  /// Get empty icon for filter
  IconData _getEmptyIcon(NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return Icons.notifications_none;
      case NotificationFilter.unread:
        return Icons.mark_email_read;
      case NotificationFilter.tasks:
        return Icons.task_alt;
      case NotificationFilter.approvals:
        return Icons.check_circle_outline;
      case NotificationFilter.points:
        return Icons.stars;
      case NotificationFilter.events:
        return Icons.event_note;
    }
  }

  /// Handle notification tap (deep linking)
  void _handleNotificationTap(
    BuildContext context,
    AppNotification notification,
  ) {
    // Extract navigation data
    final data = notification.data;
    final targetScreen = data.targetScreen;

    AppLogger.debug('[NOTIF_SCREEN] Tapped notification: ${notification.title}');
    AppLogger.debug('[NOTIF_SCREEN] Data: ${data.toJson()}');
    AppLogger.debug('[NOTIF_SCREEN] Target screen: $targetScreen');

    // Navigate based on notification type
    switch (notification.notificationType) {
      case NotificationType.taskReminder:
      case NotificationType.taskDue:
      case NotificationType.taskOverdue:
      case NotificationType.taskCompleted:
        if (data.taskId != null) {
          context.go('/tasks/${data.taskId}');
        } else {
          context.go('/tasks');
        }
        break;

      case NotificationType.approvalRequested:
      case NotificationType.taskApproved:
      case NotificationType.taskRejected:
        if (data.taskId != null) {
          context.go('/tasks/${data.taskId}');
        } else {
          context.go('/approvals');
        }
        break;

      case NotificationType.pointsEarned:
      case NotificationType.badgeAwarded:
      case NotificationType.rewardUnlocked:
      case NotificationType.streakGuard:
      case NotificationType.streakLost:
        context.go('/gamification');
        break;

      case NotificationType.eventReminder:
        if (data.eventId != null) {
          context.go('/calendar/event/${data.eventId}');
        } else {
          context.go('/calendar');
        }
        break;

      case NotificationType.studySession:
        context.go('/study');
        break;

      case NotificationType.familyInvite:
        context.go('/family');
        break;

      case NotificationType.other:
        // Use target screen if specified
        if (targetScreen != null && targetScreen.isNotEmpty) {
          context.go(targetScreen);
        }
        break;
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text(
          'Mark all notifications as read?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(notificationProvider.notifier).markAllAsRead();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
          ),
        );
      }
    }
  }

  /// Clear all notifications
  Future<void> _clearAllNotifications(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'This will permanently delete all notifications. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(notificationProvider.notifier).clearAllNotifications();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
          ),
        );
      }
    }
  }
}
