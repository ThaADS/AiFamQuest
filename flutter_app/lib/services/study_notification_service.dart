import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/study_models.dart';

/// Service for scheduling study session reminders
class StudyNotificationService {
  static final StudyNotificationService _instance = StudyNotificationService._internal();
  factory StudyNotificationService() => _instance;
  StudyNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Navigate to study session detail
    // This would need to be connected to your navigation system
    final payload = response.payload;
    if (payload != null) {
      // Parse payload and navigate
      // Example: {"type": "study_session", "sessionId": "uuid"}
    }
  }

  /// Schedule notification for a study session
  Future<void> scheduleSessionReminder({
    required StudySession session,
    required StudyItem studyItem,
    int minutesBefore = 60,
  }) async {
    await initialize();

    final notificationTime = session.scheduledAt.subtract(Duration(minutes: minutesBefore));

    // Don't schedule if time is in the past
    if (notificationTime.isBefore(DateTime.now())) return;

    final notificationId = session.id.hashCode;

    const androidDetails = AndroidNotificationDetails(
      'study_reminders',
      'Study Reminders',
      channelDescription: 'Reminders for upcoming study sessions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      '${studyItem.subject} Study Session',
      '${session.focus} - ${session.duration} minutes',
      tz.TZDateTime.from(notificationTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '{"type":"study_session","sessionId":"${session.id}"}',
    );
  }

  /// Schedule daily study reminder
  Future<void> scheduleDailyReminder({
    required String userId,
    required int hour,
    required int minute,
  }) async {
    await initialize();

    final notificationId = 'daily_study_$userId'.hashCode;

    const androidDetails = AndroidNotificationDetails(
      'daily_study_reminder',
      'Daily Study Reminder',
      channelDescription: 'Daily reminder to check your study sessions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      notificationId,
      'Study Time',
      'Don\'t forget to check your study sessions for today!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Notify about missed sessions
  Future<void> notifyMissedSession({
    required StudySession session,
    required StudyItem studyItem,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'missed_sessions',
      'Missed Study Sessions',
      channelDescription: 'Notifications for missed study sessions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      session.id.hashCode,
      'Missed Study Session',
      '${studyItem.subject}: ${session.focus}',
      details,
      payload: '{"type":"study_session","sessionId":"${session.id}"}',
    );
  }

  /// Schedule notifications for all upcoming sessions
  Future<void> scheduleAllSessionReminders({
    required List<StudyItem> studyItems,
    required Map<String, List<StudySession>> sessionsByItemId,
  }) async {
    await cancelAllNotifications();

    for (final item in studyItems) {
      final sessions = sessionsByItemId[item.id] ?? [];

      for (final session in sessions) {
        if (!session.completed && session.scheduledAt.isAfter(DateTime.now())) {
          await scheduleSessionReminder(
            session: session,
            studyItem: item,
            minutesBefore: 60,
          );
        }
      }
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notifications.pendingNotificationRequests();
  }

  /// Celebrate streak achievement
  Future<void> notifyStreakAchievement({
    required int days,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'achievements',
      'Study Achievements',
      channelDescription: 'Notifications for study achievements',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String message;
    if (days == 7) {
      message = 'You completed 7 days in a row! Keep it up!';
    } else if (days == 30) {
      message = 'Amazing! 30 days of consistent studying!';
    } else if (days % 10 == 0) {
      message = '$days days streak! You\'re on fire!';
    } else {
      message = '$days days in a row! Keep going!';
    }

    await _notifications.show(
      'streak_$days'.hashCode,
      'Study Streak Achievement!',
      message,
      details,
    );
  }

  /// Notify about upcoming exam
  Future<void> notifyUpcomingExam({
    required StudyItem studyItem,
    required int daysUntil,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'exam_reminders',
      'Exam Reminders',
      channelDescription: 'Reminders for upcoming exams',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String message;
    if (daysUntil == 1) {
      message = '${studyItem.subject} exam is tomorrow! Final review time.';
    } else if (daysUntil == 3) {
      message = '${studyItem.subject} exam in 3 days. Time for intensive review!';
    } else if (daysUntil == 7) {
      message = '${studyItem.subject} exam in 1 week. Stay on track!';
    } else {
      message = '${studyItem.subject} exam in $daysUntil days.';
    }

    await _notifications.show(
      'exam_${studyItem.id}_$daysUntil'.hashCode,
      'Upcoming Exam',
      message,
      details,
      payload: '{"type":"study_item","studyItemId":"${studyItem.id}"}',
    );
  }
}
