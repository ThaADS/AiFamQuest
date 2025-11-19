/// Notification Provider for FamQuest
///
/// State management for in-app notifications:
/// - Load notifications from backend/Supabase
/// - Listen to realtime updates
/// - Mark as read/unread
/// - Delete notifications
/// - Track unread count
/// - Filter by category

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';
import '../api/client.dart';
import '../core/app_logger.dart';

/// Notification state model
class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Notification StateNotifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this._apiClient, this._supabase)
      : super(const NotificationState()) {
    _initialize();
  }

  final ApiClient _apiClient;
  final SupabaseClient _supabase;
  RealtimeChannel? _realtimeChannel;

  /// Initialize: Load notifications and setup realtime listener
  Future<void> _initialize() async {
    await loadNotifications();
    _setupRealtimeListener();
  }

  /// Load all notifications from backend
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      AppLogger.debug('[NOTIF_PROVIDER] Loading notifications...');

      final data = await _apiClient.listNotifications();
      final notifications = data.map((json) {
        try {
          return AppNotification.fromJson(json);
        } catch (e) {
          AppLogger.debug('[NOTIF_PROVIDER] Failed to parse notification: $e');
          return null;
        }
      }).whereType<AppNotification>().toList();

      // Sort by created date (newest first)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final unreadCount = notifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        unreadCount: unreadCount,
      );

      AppLogger.debug('[NOTIF_PROVIDER] Loaded ${notifications.length} notifications '
          '($unreadCount unread)');
    } catch (e, stack) {
      AppLogger.debug('[NOTIF_PROVIDER] Error loading notifications: $e');
      AppLogger.debug('[NOTIF_PROVIDER] Stack: $stack');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications: $e',
      );
    }
  }

  /// Setup realtime listener for new notifications
  void _setupRealtimeListener() {
    try {
      AppLogger.debug('[NOTIF_PROVIDER] Setting up realtime listener...');

      // Get current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        AppLogger.debug('[NOTIF_PROVIDER] No user ID, skipping realtime setup');
        return;
      }

      // Listen to notifications table
      _realtimeChannel = _supabase
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              AppLogger.debug('[NOTIF_PROVIDER] New notification received: ${payload.newRecord}');
              _handleNewNotification(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              AppLogger.debug('[NOTIF_PROVIDER] Notification updated: ${payload.newRecord}');
              _handleUpdatedNotification(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              AppLogger.debug('[NOTIF_PROVIDER] Notification deleted: ${payload.oldRecord}');
              _handleDeletedNotification(payload.oldRecord);
            },
          )
          .subscribe();

      AppLogger.debug('[NOTIF_PROVIDER] Realtime listener setup complete');
    } catch (e, stack) {
      AppLogger.debug('[NOTIF_PROVIDER] Error setting up realtime: $e');
      AppLogger.debug('[NOTIF_PROVIDER] Stack: $stack');
    }
  }

  /// Handle new notification from realtime
  void _handleNewNotification(Map<String, dynamic> record) {
    try {
      final notification = AppNotification.fromJson(record);
      final updatedList = [notification, ...state.notifications];
      final unreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: unreadCount,
      );

      AppLogger.debug('[NOTIF_PROVIDER] Added new notification: ${notification.title}');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error handling new notification: $e');
    }
  }

  /// Handle updated notification from realtime
  void _handleUpdatedNotification(Map<String, dynamic> record) {
    try {
      final updatedNotification = AppNotification.fromJson(record);
      final updatedList = state.notifications.map((n) {
        return n.id == updatedNotification.id ? updatedNotification : n;
      }).toList();

      final unreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: unreadCount,
      );

      AppLogger.debug('[NOTIF_PROVIDER] Updated notification: ${updatedNotification.id}');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error handling updated notification: $e');
    }
  }

  /// Handle deleted notification from realtime
  void _handleDeletedNotification(Map<String, dynamic> record) {
    try {
      final deletedId = record['id'] as String;
      final updatedList = state.notifications
          .where((n) => n.id != deletedId)
          .toList();

      final unreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: unreadCount,
      );

      AppLogger.debug('[NOTIF_PROVIDER] Deleted notification: $deletedId');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error handling deleted notification: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      AppLogger.debug('[NOTIF_PROVIDER] Marking notification as read: $notificationId');

      // Optimistically update state
      final updatedList = state.notifications.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList();

      final unreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: unreadCount,
      );

      // Update backend
      await _apiClient.markNotificationAsRead(notificationId);
      AppLogger.debug('[NOTIF_PROVIDER] Notification marked as read');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error marking as read: $e');
      // Revert on error
      await loadNotifications();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      AppLogger.debug('[NOTIF_PROVIDER] Marking all notifications as read...');

      // Optimistically update state
      final updatedList = state.notifications.map((n) {
        return n.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: 0,
      );

      // Update backend
      await _apiClient.markAllNotificationsAsRead();
      AppLogger.debug('[NOTIF_PROVIDER] All notifications marked as read');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error marking all as read: $e');
      // Revert on error
      await loadNotifications();
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      AppLogger.debug('[NOTIF_PROVIDER] Deleting notification: $notificationId');

      // Optimistically update state
      final updatedList = state.notifications
          .where((n) => n.id != notificationId)
          .toList();

      final unreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: unreadCount,
      );

      // Delete from backend
      await _apiClient.deleteNotification(notificationId);
      AppLogger.debug('[NOTIF_PROVIDER] Notification deleted');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error deleting notification: $e');
      // Revert on error
      await loadNotifications();
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      AppLogger.debug('[NOTIF_PROVIDER] Clearing all notifications...');

      // Optimistically update state
      state = state.copyWith(
        notifications: [],
        unreadCount: 0,
      );

      // Clear from backend
      await _apiClient.clearAllNotifications();
      AppLogger.debug('[NOTIF_PROVIDER] All notifications cleared');
    } catch (e) {
      AppLogger.debug('[NOTIF_PROVIDER] Error clearing notifications: $e');
      // Revert on error
      await loadNotifications();
    }
  }

  /// Refresh notifications (pull-to-refresh)
  Future<void> refresh() async {
    await loadNotifications();
  }

  /// Get filtered notifications
  List<AppNotification> getFiltered(NotificationFilter filter) {
    return state.notifications.where((n) => filter.matches(n)).toList();
  }

  /// Cleanup: Dispose realtime channel
  @override
  void dispose() {
    AppLogger.debug('[NOTIF_PROVIDER] Disposing notification provider...');
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}

/// Provider for notification state
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final apiClient = ApiClient.instance;
  final supabase = Supabase.instance.client;
  return NotificationNotifier(apiClient, supabase);
});

/// Provider for unread notification count
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});

/// Provider for filtered notifications
final filteredNotificationsProvider =
    Provider.family<List<AppNotification>, NotificationFilter>((ref, filter) {
  final notifier = ref.watch(notificationProvider.notifier);
  return notifier.getFiltered(filter);
});
