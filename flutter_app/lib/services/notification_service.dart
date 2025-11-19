/// Firebase Cloud Messaging and Local Notifications Service
///
/// Handles:
/// - Firebase initialization
/// - Device token management
/// - Push notification handlers (foreground/background)
/// - Local notification display
/// - Notification event callbacks

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import '../core/app_logger.dart';

typedef NotificationCallback = void Function(Map<String, dynamic> payload);

/// Background message handler (top-level function required by Firebase)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  AppLogger.debug('[NOTIF_BG] Background message received:');
  AppLogger.debug('[NOTIF_BG] Title: ${message.notification?.title}');
  AppLogger.debug('[NOTIF_BG] Body: ${message.notification?.body}');
  AppLogger.debug('[NOTIF_BG] Data: ${message.data}');

  // Background handler completes - notification already shown by system
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Callbacks for notification events
  NotificationCallback? onNotificationReceived;
  NotificationCallback? onNotificationTapped;

  bool _initialized = false;

  /// Initialize Firebase Messaging and Local Notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      AppLogger.debug('[NOTIF] 🚀 Initializing Firebase Cloud Messaging...');

      // Firebase Core is initialized in main.dart, skip here
      AppLogger.debug('[NOTIF] ✅ Firebase Core already initialized in main()');

      // Request notification permissions
      await _requestNotificationPermissions();
      AppLogger.debug('[NOTIF] ✅ Notification permissions requested');

      // Initialize local notifications
      await _initializeLocalNotifications();
      AppLogger.debug('[NOTIF] ✅ Local notifications initialized');

      // Setup message handlers
      _setupMessageHandlers();
      AppLogger.debug('[NOTIF] ✅ Message handlers configured');

      _initialized = true;
      AppLogger.debug('[NOTIF] 🎉 Notification service fully initialized');
    } catch (e) {
      AppLogger.debug('[NOTIF] ❌ Initialization error: $e');
      rethrow;
    }
  }

  /// Request notification permissions from user
  Future<void> _requestNotificationPermissions() async {
    if (Platform.isIOS) {
      // iOS permissions
      final authStatus = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      AppLogger.debug('[NOTIF] iOS permission status: ${authStatus.authorizationStatus}');
    } else if (Platform.isAndroid) {
      // Android: request POST_NOTIFICATIONS permission (Android 13+)
      // Note: This is handled automatically by firebase_messaging
      AppLogger.debug('[NOTIF] Android notifications will use runtime permissions');
    }
  }

  /// Initialize Flutter Local Notifications
  Future<void> _initializeLocalNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Android setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS setup
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    // Initialize with platform-specific settings
    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onSelectNotification,
      onDidReceiveBackgroundNotificationResponse: _onSelectNotification,
    );

    AppLogger.debug('[NOTIF] Local notifications plugin initialized');
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.debug('[NOTIF] 📨 Foreground message received:');
      AppLogger.debug('[NOTIF] Title: ${message.notification?.title}');
      AppLogger.debug('[NOTIF] Body: ${message.notification?.body}');
      AppLogger.debug('[NOTIF] Data: ${message.data}');

      _handleForegroundMessage(message);

      // Trigger callback
      if (onNotificationReceived != null) {
        onNotificationReceived!(_messageToPayload(message));
      }
    });

    // Handle background message tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.debug('[NOTIF] 📲 Background message tapped:');
      AppLogger.debug('[NOTIF] Title: ${message.notification?.title}');
      AppLogger.debug('[NOTIF] Data: ${message.data}');

      _handleNotificationTap(message);

      // Trigger callback
      if (onNotificationTapped != null) {
        onNotificationTapped!(_messageToPayload(message));
      }
    });

    // Check if app was launched from notification
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        AppLogger.debug('[NOTIF] 🔌 App launched from notification');
        _handleNotificationTap(message);

        // Trigger callback
        if (onNotificationTapped != null) {
          onNotificationTapped!(_messageToPayload(message));
        }
      }
    });
  }

  /// Handle foreground message display
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.notification == null) return;

    // Show local notification
    await _showLocalNotification(
      id: message.hashCode,
      title: message.notification!.title ?? 'Notification',
      body: message.notification!.body ?? '',
      payload: message.data,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.debug('[NOTIF] Handling notification tap with data: ${message.data}');
    // Navigation is handled by the callback in the app
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      // Android notification details
      const androidDetails = AndroidNotificationDetails(
        'famquest_notifications',
        'FamQuest Notifications',
        channelDescription: 'Notifications for tasks, points, and streaks',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        showWhen: true,
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload != null ? Uri(queryParameters: payload.cast<String, String>()).query : null,
      );

      AppLogger.debug('[NOTIF] ✅ Local notification shown: $title');
    } catch (e) {
      AppLogger.debug('[NOTIF] ❌ Failed to show local notification: $e');
    }
  }

  /// iOS local notification handler
  Future<void> _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    AppLogger.debug('[NOTIF] iOS local notification received: $title');
    // Handle iOS notification in foreground
  }

  /// Notification tap handler
  static void _onSelectNotification(NotificationResponse response) {
    AppLogger.debug('[NOTIF] Notification tapped: ${response.payload}');
    // Payload handling done through callback
  }

  /// Convert Firebase message to payload
  Map<String, dynamic> _messageToPayload(RemoteMessage message) {
    return {
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
      'type': message.data['type'] ?? 'unknown',
      'taskId': message.data['taskId'],
      'userId': message.data['userId'],
    };
  }

  /// Get FCM device token
  Future<String?> getDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      AppLogger.debug('[NOTIF] Device token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      AppLogger.debug('[NOTIF] ❌ Failed to get device token: $e');
      return null;
    }
  }

  /// Get APNs token (iOS only)
  Future<String?> getAPNsToken() async {
    if (!Platform.isIOS) return null;

    try {
      final token = await _firebaseMessaging.getAPNSToken();
      AppLogger.debug('[NOTIF] APNs token: ${token?.substring(0, 20) ?? 'null'}...');
      return token;
    } catch (e) {
      AppLogger.debug('[NOTIF] ❌ Failed to get APNs token: $e');
      return null;
    }
  }

  /// Listen to token refresh events
  void onTokenRefresh(void Function(String token) callback) {
    _firebaseMessaging.onTokenRefresh.listen((token) {
      AppLogger.debug('[NOTIF] 🔄 Token refreshed: ${token.substring(0, 20)}...');
      callback(token);
    });
  }

  /// Is notification enabled
  Future<bool> isNotificationEnabled() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Enable all notification types
  Future<void> setNotificationEnabled(bool enabled) async {
    if (enabled) {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        criticalAlert: false,
        provisional: true,
      );
    }
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    AppLogger.debug('[NOTIF] ✅ Notification cancelled: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    AppLogger.debug('[NOTIF] ✅ All notifications cancelled');
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;
}
