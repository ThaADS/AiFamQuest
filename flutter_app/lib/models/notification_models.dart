/// In-App Notification Models for FamQuest
///
/// Data structures for notification center:
/// - AppNotification: Main notification model
/// - NotificationType: Enum for notification categories
/// - NotificationData: Structured payload data

import 'package:json_annotation/json_annotation.dart';

part 'notification_models.g.dart';

/// Notification type enum for categorization
enum NotificationType {
  @JsonValue('task_reminder')
  taskReminder,

  @JsonValue('task_due')
  taskDue,

  @JsonValue('task_overdue')
  taskOverdue,

  @JsonValue('approval_requested')
  approvalRequested,

  @JsonValue('task_approved')
  taskApproved,

  @JsonValue('task_rejected')
  taskRejected,

  @JsonValue('task_completed')
  taskCompleted,

  @JsonValue('points_earned')
  pointsEarned,

  @JsonValue('badge_awarded')
  badgeAwarded,

  @JsonValue('streak_guard')
  streakGuard,

  @JsonValue('streak_lost')
  streakLost,

  @JsonValue('reward_unlocked')
  rewardUnlocked,

  @JsonValue('family_invite')
  familyInvite,

  @JsonValue('event_reminder')
  eventReminder,

  @JsonValue('study_session')
  studySession,

  @JsonValue('other')
  other;

  /// Get user-friendly display name
  String get displayName {
    switch (this) {
      case NotificationType.taskReminder:
        return 'Task Reminder';
      case NotificationType.taskDue:
        return 'Task Due';
      case NotificationType.taskOverdue:
        return 'Task Overdue';
      case NotificationType.approvalRequested:
        return 'Approval Requested';
      case NotificationType.taskApproved:
        return 'Task Approved';
      case NotificationType.taskRejected:
        return 'Task Rejected';
      case NotificationType.taskCompleted:
        return 'Task Completed';
      case NotificationType.pointsEarned:
        return 'Points Earned';
      case NotificationType.badgeAwarded:
        return 'Badge Awarded';
      case NotificationType.streakGuard:
        return 'Streak Alert';
      case NotificationType.streakLost:
        return 'Streak Lost';
      case NotificationType.rewardUnlocked:
        return 'Reward Unlocked';
      case NotificationType.familyInvite:
        return 'Family Invite';
      case NotificationType.eventReminder:
        return 'Event Reminder';
      case NotificationType.studySession:
        return 'Study Session';
      case NotificationType.other:
        return 'Notification';
    }
  }

  /// Get icon for notification type
  String get icon {
    switch (this) {
      case NotificationType.taskReminder:
      case NotificationType.taskDue:
        return '⏰';
      case NotificationType.taskOverdue:
        return '🚨';
      case NotificationType.approvalRequested:
        return '✋';
      case NotificationType.taskApproved:
        return '✅';
      case NotificationType.taskRejected:
        return '❌';
      case NotificationType.taskCompleted:
        return '🎉';
      case NotificationType.pointsEarned:
        return '⭐';
      case NotificationType.badgeAwarded:
        return '🏆';
      case NotificationType.streakGuard:
        return '🔥';
      case NotificationType.streakLost:
        return '💔';
      case NotificationType.rewardUnlocked:
        return '🎁';
      case NotificationType.familyInvite:
        return '👨‍👩‍👧‍👦';
      case NotificationType.eventReminder:
        return '📅';
      case NotificationType.studySession:
        return '📚';
      case NotificationType.other:
        return '🔔';
    }
  }

  /// Category for filtering (tasks, approvals, points, events)
  String get category {
    switch (this) {
      case NotificationType.taskReminder:
      case NotificationType.taskDue:
      case NotificationType.taskOverdue:
      case NotificationType.taskCompleted:
        return 'tasks';
      case NotificationType.approvalRequested:
      case NotificationType.taskApproved:
      case NotificationType.taskRejected:
        return 'approvals';
      case NotificationType.pointsEarned:
      case NotificationType.badgeAwarded:
      case NotificationType.rewardUnlocked:
      case NotificationType.streakGuard:
      case NotificationType.streakLost:
        return 'points';
      case NotificationType.eventReminder:
      case NotificationType.studySession:
        return 'events';
      case NotificationType.familyInvite:
      case NotificationType.other:
        return 'other';
    }
  }
}

/// Additional data payload for notifications
@JsonSerializable()
class NotificationData {
  final String? taskId;
  final String? userId;
  final String? eventId;
  final String? badgeCode;
  final int? points;
  final String? targetScreen;
  final Map<String, dynamic>? extra;

  const NotificationData({
    this.taskId,
    this.userId,
    this.eventId,
    this.badgeCode,
    this.points,
    this.targetScreen,
    this.extra,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) =>
      _$NotificationDataFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationDataToJson(this);

  NotificationData copyWith({
    String? taskId,
    String? userId,
    String? eventId,
    String? badgeCode,
    int? points,
    String? targetScreen,
    Map<String, dynamic>? extra,
  }) {
    return NotificationData(
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      badgeCode: badgeCode ?? this.badgeCode,
      points: points ?? this.points,
      targetScreen: targetScreen ?? this.targetScreen,
      extra: extra ?? this.extra,
    );
  }
}

/// Main in-app notification model
@JsonSerializable()
class AppNotification {
  final String id;
  final String userId;
  final String familyId;

  @JsonKey(name: 'type')
  final NotificationType notificationType;

  final String title;
  final String body;
  final NotificationData data;

  @JsonKey(name: 'is_read')
  final bool isRead;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.familyId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$AppNotificationToJson(this);

  AppNotification copyWith({
    String? id,
    String? userId,
    String? familyId,
    NotificationType? notificationType,
    String? title,
    String? body,
    NotificationData? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Time ago string (e.g., "5 minutes ago", "2 hours ago")
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (diff.inDays < 7) {
      final days = diff.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? "month" : "months"} ago';
    }
  }

  /// Get display icon from notification type
  String get icon => notificationType.icon;

  /// Get category for filtering
  String get category => notificationType.category;
}

/// Filter options for notification list
enum NotificationFilter {
  all,
  unread,
  tasks,
  approvals,
  points,
  events;

  String get displayName {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.unread:
        return 'Unread';
      case NotificationFilter.tasks:
        return 'Tasks';
      case NotificationFilter.approvals:
        return 'Approvals';
      case NotificationFilter.points:
        return 'Points';
      case NotificationFilter.events:
        return 'Events';
    }
  }

  String get icon {
    switch (this) {
      case NotificationFilter.all:
        return '📋';
      case NotificationFilter.unread:
        return '🔴';
      case NotificationFilter.tasks:
        return '✅';
      case NotificationFilter.approvals:
        return '✋';
      case NotificationFilter.points:
        return '⭐';
      case NotificationFilter.events:
        return '📅';
    }
  }

  /// Apply filter to notification list
  bool matches(AppNotification notification) {
    switch (this) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.unread:
        return !notification.isRead;
      case NotificationFilter.tasks:
        return notification.category == 'tasks';
      case NotificationFilter.approvals:
        return notification.category == 'approvals';
      case NotificationFilter.points:
        return notification.category == 'points';
      case NotificationFilter.events:
        return notification.category == 'events';
    }
  }
}
