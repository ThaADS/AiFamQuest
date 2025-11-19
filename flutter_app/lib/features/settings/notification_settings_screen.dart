/// Notification Settings Screen
///
/// Allows users to manage notification preferences for different types

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/push_notification_service.dart';

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, Map<String, bool>>((ref) {
  return NotificationPreferencesNotifier();
});

class NotificationPreferencesNotifier extends StateNotifier<Map<String, bool>> {
  NotificationPreferencesNotifier()
      : super({
          'task_reminder': true,
          'task_due_now': true,
          'task_overdue': true,
          'approval_requested': true,
          'points_earned': true,
          'streak_guard': true,
          'streak_lost': true,
        });

  Future<void> togglePreference(String type, bool enabled) async {
    final service = PushNotificationService();
    final success = await service.updateNotificationPreference(type, enabled);

    if (success) {
      state = {...state, type: enabled};
    }
  }
}

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _loading = false;
  String? _testMessage;

  final PushNotificationService _pushService = PushNotificationService();

  // Notification type descriptions
  static const notificationDescriptions = {
    'task_reminder': {
      'title': 'Task Reminder',
      'description': 'Reminder 60 minutes before task is due'
    },
    'task_due_now': {
      'title': 'Task Due Now',
      'description': 'Task is due immediately'
    },
    'task_overdue': {
      'title': 'Task Overdue',
      'description': 'Alert when task passes due date'
    },
    'approval_requested': {
      'title': 'Approval Needed',
      'description': 'Parent approval required for completed task'
    },
    'points_earned': {
      'title': 'Points Earned',
      'description': 'Notification when earning points'
    },
    'streak_guard': {
      'title': 'Streak Alert',
      'description': 'Alert at 20:00 if no tasks completed today'
    },
    'streak_lost': {
      'title': 'Streak Lost',
      'description': 'Notification when streak ends'
    },
  };

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final enabled = await _pushService.isNotificationEnabled();
    if (!mounted) return;

    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Notifications are disabled. Please enable them in app settings.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _loading = true);
    setState(() => _testMessage = null);

    try {
      final success = await _pushService.sendTestNotification();

      if (mounted) {
        setState(() {
          _testMessage = success
              ? '✅ Test notification sent! Check your device.'
              : '❌ Failed to send test notification';
          _loading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test notification sent!'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testMessage = '❌ Error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);

    try {
      await _pushService.requestNotificationPermission();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permissions updated'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose which notifications you want to receive',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  // Permission button
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _requestPermission,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Enable Notifications'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Notification Preferences
          const Text(
            'Notification Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Notification toggle list
          ...preferences.entries.map((entry) {
            final type = entry.key;
            final enabled = entry.value;
            final config =
                notificationDescriptions[type] ?? {'title': type, 'description': ''};

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(config['title'] ?? type),
                subtitle: Text(config['description'] ?? ''),
                trailing: Switch(
                  value: enabled,
                  onChanged: (value) {
                    ref
                        .read(notificationPreferencesProvider.notifier)
                        .togglePreference(type, value);
                  },
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // Test notification section
          const Text(
            'Testing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Send Test Notification',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verify that notifications are working correctly',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _sendTestNotification,
                      icon: const Icon(Icons.send),
                      label: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Send Test'),
                    ),
                  ),
                  if (_testMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          color: _testMessage!.contains('✅')
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Registered Devices Section
          const Text(
            'Devices',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Registered Devices',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Notifications will be sent to all registered devices',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>?>(
                    future: _pushService.getRegisteredDevices(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 40,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final devices = snapshot.data ?? [];

                      if (devices.isEmpty) {
                        return const Text(
                          'No devices registered',
                          style: TextStyle(color: Colors.grey),
                        );
                      }

                      return Column(
                        children: devices.map((device) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  device['platform'] == 'ios'
                                      ? Icons.apple
                                      : device['platform'] == 'android'
                                          ? Icons.phone_android
                                          : Icons.devices,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device['platform']?.toUpperCase() ??
                                            'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        device['token'] ?? 'Unknown token',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info Section
          Card(
            elevation: 0,
            color: Colors.teal.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Notifications are sent via Firebase Cloud Messaging\n'
                    '• Push notifications require internet connection\n'
                    '• Check app settings if notifications don\'t appear\n'
                    '• You can manage these preferences anytime',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
