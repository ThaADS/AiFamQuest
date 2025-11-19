/// Push Notification Service - Backend Integration
///
/// Handles:
/// - Device token registration with backend
/// - Notification preferences management
/// - Navigation on notification tap
/// - Notification type-specific handling

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../api/client.dart';
import 'notification_service.dart';
import '../core/app_logger.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  String? _currentUserId;
  BuildContext? _navigationContext;

  // Notification type handlers
  static const Map<String, Map<String, String>> notificationTypeConfig = {
    'task_reminder': {'title': 'Task Reminder', 'description': 'Reminder about upcoming task'},
    'task_due_now': {'title': 'Task Due Now', 'description': 'Task is due immediately'},
    'task_overdue': {'title': 'Task Overdue', 'description': 'You have overdue tasks'},
    'approval_requested': {'title': 'Approval Needed', 'description': 'Task needs parent approval'},
    'points_earned': {'title': 'Points Earned', 'description': 'You earned points'},
    'streak_guard': {'title': 'Streak Alert', 'description': 'Complete a task to keep your streak'},
    'streak_lost': {'title': 'Streak Lost', 'description': 'Your streak has ended'},
  };

  /// Initialize push notification service and register device token
  Future<void> initialize(String userId, BuildContext context) async {
    try {
      AppLogger.debug('[PUSH] 🚀 Initializing push notification service...');

      _currentUserId = userId;
      _navigationContext = context;

      // Initialize notification service
      await _notificationService.initialize();
      AppLogger.debug('[PUSH] ✅ Notification service initialized');

      // Get device token and register with backend
      await _registerDeviceToken();
      AppLogger.debug('[PUSH] ✅ Device token registered');

      // Setup notification callbacks
      _setupNotificationCallbacks();
      AppLogger.debug('[PUSH] ✅ Notification callbacks configured');

      // Listen for token refreshes
      _notificationService.onTokenRefresh((newToken) {
        _registerTokenWithBackend(newToken);
      });
      AppLogger.debug('[PUSH] ✅ Token refresh listener configured');

      // Load notification preferences
      await _loadNotificationPreferences();
      AppLogger.debug('[PUSH] ✅ Notification preferences loaded');

      AppLogger.debug('[PUSH] 🎉 Push notification service fully initialized');
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Initialization error: $e');
      rethrow;
    }
  }

  /// Register device token with backend
  Future<void> _registerDeviceToken() async {
    try {
      final token = await _notificationService.getDeviceToken();
      if (token == null) {
        AppLogger.debug('[PUSH] ⚠️ No device token available');
        return;
      }

      await _registerTokenWithBackend(token);
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Failed to register device token: $e');
    }
  }

  /// Register token with backend API
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final apiToken = await ApiClient.instance.getToken();
      if (apiToken == null) {
        AppLogger.debug('[PUSH] ⚠️ No auth token available, skipping registration');
        return;
      }

      // Detect platform
      String platform = 'unknown';
      if (identical(0, 0.0)) {
        platform = 'ios';
      } else {
        platform = 'android';
      }

      final response = await http.post(
        Uri.parse('${ApiClient.instance.baseUrl}/notifications/register-device'),
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'platform': platform,
        }),
      );

      if (response.statusCode == 200) {
        AppLogger.debug('[PUSH] ✅ Token registered with backend');
      } else {
        AppLogger.debug('[PUSH] ⚠️ Token registration failed: ${response.statusCode}');
        AppLogger.debug('[PUSH] Response: ${response.body}');
      }
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Failed to register token with backend: $e');
    }
  }

  /// Setup notification callbacks
  void _setupNotificationCallbacks() {
    // Foreground notification received
    _notificationService.onNotificationReceived = (payload) {
      AppLogger.debug('[PUSH] 📨 Notification received: ${payload['type']}');
      _handleNotification(payload, foreground: true);
    };

    // Notification tapped (background or from tray)
    _notificationService.onNotificationTapped = (payload) {
      AppLogger.debug('[PUSH] 📲 Notification tapped: ${payload['type']}');
      _handleNotification(payload, foreground: false);
    };
  }

  /// Handle notification based on type
  void _handleNotification(Map<String, dynamic> payload, {required bool foreground}) {
    final type = payload['type'] as String?;

    if (type == null) {
      AppLogger.debug('[PUSH] ⚠️ Unknown notification type');
      return;
    }

    AppLogger.debug('[PUSH] Processing notification type: $type');

    switch (type) {
      case 'task_reminder':
      case 'task_due_now':
      case 'task_overdue':
        _handleTaskNotification(payload);
        break;

      case 'approval_requested':
        _handleApprovalNotification(payload);
        break;

      case 'points_earned':
        _handlePointsNotification(payload);
        break;

      case 'streak_guard':
      case 'streak_lost':
        _handleStreakNotification(payload);
        break;

      default:
        AppLogger.debug('[PUSH] ⚠️ Unhandled notification type: $type');
    }
  }

  /// Handle task-related notifications
  void _handleTaskNotification(Map<String, dynamic> payload) {
    final taskId = payload['taskId'] as String?;
    if (taskId != null && _navigationContext != null) {
      AppLogger.debug('[PUSH] 🔗 Navigating to task: $taskId');
      // Navigate to task detail
      // GoRouter.of(_navigationContext!).push('/tasks/detail?id=$taskId');
    }
  }

  /// Handle approval notifications
  void _handleApprovalNotification(Map<String, dynamic> payload) {
    if (_navigationContext != null) {
      AppLogger.debug('[PUSH] 🔗 Navigating to approval screen');
      // GoRouter.of(_navigationContext!).push('/tasks/approval');
    }
  }

  /// Handle points notifications
  void _handlePointsNotification(Map<String, dynamic> payload) {
    final points = payload['data']?['points'] as String?;
    if (points != null) {
      AppLogger.debug('[PUSH] 🎯 Points awarded: $points');
      // Could show a celebration animation or toast
    }
  }

  /// Handle streak notifications
  void _handleStreakNotification(Map<String, dynamic> payload) {
    final type = payload['type'] as String?;
    if (type == 'streak_guard' && _navigationContext != null) {
      AppLogger.debug('[PUSH] 🔗 Navigating to tasks for streak guard');
      // GoRouter.of(_navigationContext!).push('/tasks');
    }
  }

  /// Load notification preferences from backend
  Future<void> _loadNotificationPreferences() async {
    try {
      final apiToken = await ApiClient.instance.getToken();
      if (apiToken == null) {
        AppLogger.debug('[PUSH] ⚠️ No auth token available');
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiClient.instance.baseUrl}/notifications/preferences'),
        headers: {
          'Authorization': 'Bearer $apiToken',
        },
      );

      if (response.statusCode == 200) {
        // final data = jsonDecode(response.body) as Map<String, dynamic>;
        AppLogger.debug('[PUSH] ✅ Notification preferences loaded');
        // Store preferences if needed
        // _preferences = data;
      } else {
        AppLogger.debug('[PUSH] ⚠️ Failed to load preferences: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.debug('[PUSH] ⚠️ Failed to load notification preferences: $e');
      // Continue without preferences (defaults apply)
    }
  }

  /// Update notification preferences on backend
  Future<bool> updateNotificationPreference(String type, bool enabled) async {
    try {
      final apiToken = await ApiClient.instance.getToken();
      if (apiToken == null) {
        AppLogger.debug('[PUSH] ⚠️ No auth token available');
        return false;
      }

      final response = await http.put(
        Uri.parse('${ApiClient.instance.baseUrl}/notifications/preferences/$type'),
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'enabled': enabled,
        }),
      );

      if (response.statusCode == 200) {
        AppLogger.debug('[PUSH] ✅ Preference updated: $type = $enabled');
        return true;
      } else {
        AppLogger.debug('[PUSH] ⚠️ Failed to update preference: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Failed to update preference: $e');
      return false;
    }
  }

  /// Test notification (development only)
  Future<bool> sendTestNotification() async {
    try {
      final apiToken = await ApiClient.instance.getToken();
      if (apiToken == null) {
        AppLogger.debug('[PUSH] ⚠️ No auth token available');
        return false;
      }

      final response = await http.post(
        Uri.parse('${ApiClient.instance.baseUrl}/notifications/test'),
        headers: {
          'Authorization': 'Bearer $apiToken',
        },
      );

      if (response.statusCode == 200) {
        AppLogger.debug('[PUSH] ✅ Test notification sent');
        return true;
      } else {
        AppLogger.debug('[PUSH] ⚠️ Failed to send test notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Failed to send test notification: $e');
      return false;
    }
  }

  /// Get list of registered devices
  Future<List<Map<String, dynamic>>?> getRegisteredDevices() async {
    try {
      final apiToken = await ApiClient.instance.getToken();
      if (apiToken == null) return null;

      final response = await http.get(
        Uri.parse('${ApiClient.instance.baseUrl}/notifications/devices'),
        headers: {
          'Authorization': 'Bearer $apiToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final devices = (data['devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        AppLogger.debug('[PUSH] ✅ Retrieved ${devices.length} registered device(s)');
        return devices;
      }
      return null;
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Failed to get devices: $e');
      return null;
    }
  }

  /// Unregister device
  Future<bool> unregisterDevice(String deviceId) async {
    try {
      final apiToken = await ApiClient.instance.getToken();
      if (apiToken == null) return false;

      final response = await http.delete(
        Uri.parse('${ApiClient.instance.baseUrl}/notifications/devices/$deviceId'),
        headers: {
          'Authorization': 'Bearer $apiToken',
        },
      );

      if (response.statusCode == 200) {
        AppLogger.debug('[PUSH] ✅ Device unregistered: $deviceId');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.debug('[PUSH] ❌ Failed to unregister device: $e');
      return false;
    }
  }

  /// Get notification permission status
  Future<bool> isNotificationEnabled() async {
    return _notificationService.isNotificationEnabled();
  }

  /// Request notification permission
  Future<void> requestNotificationPermission() async {
    await _notificationService.setNotificationEnabled(true);
  }

  /// Unregister on logout
  Future<void> cleanup() async {
    AppLogger.debug('[PUSH] 🧹 Cleaning up push notification service');
    // Cancel all notifications
    await _notificationService.cancelAllNotifications();
    _currentUserId = null;
    _navigationContext = null;
    AppLogger.debug('[PUSH] ✅ Cleanup complete');
  }

  // Getters
  String? get currentUserId => _currentUserId;
  NotificationService get notificationService => _notificationService;
}
