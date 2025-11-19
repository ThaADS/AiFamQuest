// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationData _$NotificationDataFromJson(Map<String, dynamic> json) =>
    NotificationData(
      taskId: json['taskId'] as String?,
      userId: json['userId'] as String?,
      eventId: json['eventId'] as String?,
      badgeCode: json['badgeCode'] as String?,
      points: (json['points'] as num?)?.toInt(),
      targetScreen: json['targetScreen'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$NotificationDataToJson(NotificationData instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'userId': instance.userId,
      'eventId': instance.eventId,
      'badgeCode': instance.badgeCode,
      'points': instance.points,
      'targetScreen': instance.targetScreen,
      'extra': instance.extra,
    };

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      familyId: json['familyId'] as String,
      notificationType: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      title: json['title'] as String,
      body: json['body'] as String,
      data: NotificationData.fromJson(json['data'] as Map<String, dynamic>),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$AppNotificationToJson(AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'familyId': instance.familyId,
      'type': _$NotificationTypeEnumMap[instance.notificationType]!,
      'title': instance.title,
      'body': instance.body,
      'data': instance.data,
      'is_read': instance.isRead,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$NotificationTypeEnumMap = {
  NotificationType.taskReminder: 'task_reminder',
  NotificationType.taskDue: 'task_due',
  NotificationType.taskOverdue: 'task_overdue',
  NotificationType.approvalRequested: 'approval_requested',
  NotificationType.taskApproved: 'task_approved',
  NotificationType.taskRejected: 'task_rejected',
  NotificationType.taskCompleted: 'task_completed',
  NotificationType.pointsEarned: 'points_earned',
  NotificationType.badgeAwarded: 'badge_awarded',
  NotificationType.streakGuard: 'streak_guard',
  NotificationType.streakLost: 'streak_lost',
  NotificationType.rewardUnlocked: 'reward_unlocked',
  NotificationType.familyInvite: 'family_invite',
  NotificationType.eventReminder: 'event_reminder',
  NotificationType.studySession: 'study_session',
  NotificationType.other: 'other',
};
