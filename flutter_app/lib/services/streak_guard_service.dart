/// Streak Guard Service
///
/// Monitors streaks and sends alerts to prevent breaks
/// Features:
/// - Daily check at 20:00 (20 hours before midnight)
/// - Local notification if no tasks completed today
/// - In-app banner reminder
/// - Streak save tracking
/// - Silent mode (no alerts if disabled)
///
/// USAGE:
/// ```dart
/// // In home_screen.dart or after login:
/// final streakGuard = StreakGuardService();
/// await streakGuard.initialize(userId);
///
/// // Optionally disable:
/// streakGuard.setEnabled(false);
///
/// // Manual check:
/// final isAtRisk = await streakGuard.checkStreakStatus();
/// ```

import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/gamification_models.dart';
import '../api/gamification_client.dart';
import 'notification_service.dart';
import '../core/app_logger.dart';

class StreakGuardService {
  static final StreakGuardService _instance = StreakGuardService._internal();

  factory StreakGuardService() {
    return _instance;
  }

  StreakGuardService._internal();

  final _gamificationClient = GamificationClient.instance;
  final _notificationService = NotificationService();

  Timer? _dailyCheckTimer;
  bool _enabled = true;
  String? _currentUserId;

  // Notification IDs
  static const int _streakGuardNotificationId = 1001;
  static const int _streakCelebrationNotificationId = 1002;

  /// Initialize streak guard service
  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    // Initialize notification service
    await _notificationService.initialize();

    // Schedule daily check
    _scheduleDailyCheck();

    AppLogger.debug('[STREAK_GUARD] ✅ Service initialized for user: $userId');
  }

  /// Enable or disable streak guard
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _cancelTimer();
      _cancelNotification();
    } else {
      _scheduleDailyCheck();
    }
    AppLogger.debug('[STREAK_GUARD] ${enabled ? 'Enabled' : 'Disabled'}');
  }

  /// Schedule daily check at 20:00
  void _scheduleDailyCheck() {
    _cancelTimer();

    if (!_enabled || _currentUserId == null) return;

    // Calculate time until 20:00 today or tomorrow
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, 20, 0);

    // If already past 20:00, schedule for tomorrow
    if (now.isAfter(targetTime)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    final duration = targetTime.difference(now);

    AppLogger.debug(
        '[STREAK_GUARD] Scheduling check in ${duration.inHours}h ${duration.inMinutes % 60}m');

    _dailyCheckTimer = Timer(duration, () {
      _performDailyCheck();
      // Schedule next check (24 hours later)
      _scheduleDailyCheck();
    });
  }

  /// Perform daily streak check
  Future<void> _performDailyCheck() async {
    if (!_enabled || _currentUserId == null) return;

    AppLogger.debug('[STREAK_GUARD] Performing daily check...');

    try {
      final streak = await _gamificationClient.getStreak(_currentUserId!);

      // Check if user completed tasks today
      if (streak.current > 0 && streak.isAtRisk) {
        AppLogger.warning(
            '[STREAK_GUARD] ⚠️ Streak at risk! Current: ${streak.current} days');
        await _sendStreakGuardAlert(streak);
      } else if (streak.current > 0) {
        AppLogger.debug('[STREAK_GUARD] ✅ Streak safe: ${streak.current} days');
      } else {
        AppLogger.debug('[STREAK_GUARD] 📊 No active streak');
      }
    } catch (e) {
      AppLogger.debug('[STREAK_GUARD] ❌ Check failed: $e');
    }
  }

  /// Send streak guard alert notification
  Future<void> _sendStreakGuardAlert(UserStreak streak) async {
    const androidDetails = AndroidNotificationDetails(
      'streak_guard',
      'Streak Guard',
      channelDescription: 'Alerts to prevent streak breaks',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final localNotifications = FlutterLocalNotificationsPlugin();

    await localNotifications.show(
      _streakGuardNotificationId,
      '🔥 Keep your streak alive!',
      'You have a ${streak.current} day streak! Complete 1 task today to keep it going.',
      details,
      payload: 'streak_guard',
    );

    AppLogger.info(
        '[STREAK_GUARD] 📲 Notification sent: ${streak.current} day streak at risk');
  }

  /// Send streak celebration notification
  Future<void> sendStreakCelebration(int streak) async {
    if (!_enabled) return;

    String title;
    String body;

    if (streak == 7) {
      title = '🔥 Week Streak!';
      body = 'Amazing! You\'ve completed tasks for 7 days in a row!';
    } else if (streak == 30) {
      title = '🔥🔥 Month Streak!';
      body = 'Incredible! 30 days of consistency! You\'re unstoppable!';
    } else if (streak == 100) {
      title = '🔥🔥🔥 Century Streak!';
      body = 'LEGENDARY! 100 days in a row! You\'re a FamQuest champion!';
    } else if (streak % 10 == 0) {
      title = '🔥 $streak Day Streak!';
      body = 'You\'re on fire! $streak days of completed tasks!';
    } else {
      return; // Don't celebrate every day
    }

    const androidDetails = AndroidNotificationDetails(
      'streak_celebrations',
      'Streak Celebrations',
      channelDescription: 'Celebrate streak milestones',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final localNotifications = FlutterLocalNotificationsPlugin();

    await localNotifications.show(
      _streakCelebrationNotificationId,
      title,
      body,
      details,
      payload: 'streak_celebration_$streak',
    );

    AppLogger.debug('[STREAK_GUARD] 🎉 Celebration sent: $streak days!');
  }

  /// Check if streak needs immediate attention (manual trigger)
  Future<bool> checkStreakStatus() async {
    if (_currentUserId == null) return false;

    try {
      final streak = await _gamificationClient.getStreak(_currentUserId!);
      return streak.isAtRisk;
    } catch (e) {
      AppLogger.debug('[STREAK_GUARD] ❌ Status check failed: $e');
      return false;
    }
  }

  /// Get current streak (for UI display)
  Future<UserStreak?> getCurrentStreak() async {
    if (_currentUserId == null) return null;

    try {
      return await _gamificationClient.getStreak(_currentUserId!);
    } catch (e) {
      AppLogger.debug('[STREAK_GUARD] ❌ Get streak failed: $e');
      return null;
    }
  }

  /// Cancel scheduled timer
  void _cancelTimer() {
    _dailyCheckTimer?.cancel();
    _dailyCheckTimer = null;
  }

  /// Cancel notification
  Future<void> _cancelNotification() async {
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.cancel(_streakGuardNotificationId);
  }

  /// Dispose service
  void dispose() {
    _cancelTimer();
    AppLogger.debug('[STREAK_GUARD] Service disposed');
  }

  /// Get enabled status
  bool get isEnabled => _enabled;

  /// Get user ID
  String? get userId => _currentUserId;
}
