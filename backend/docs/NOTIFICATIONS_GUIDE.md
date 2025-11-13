# FamQuest Notifications System Guide

Complete guide to the FamQuest notification system covering push notifications, email notifications, and scheduled reminders.

## Overview

The notification system provides:
- **Push Notifications**: FCM for Android/iOS, WebPush for browsers
- **Email Notifications**: Sendgrid/Mailgun integration for critical notifications
- **In-App Notifications**: Notification history accessible in the app
- **Scheduled Notifications**: Task reminders and streak guards

## Notification Types

### Task-Related
- `task_due`: Sent 60 min before task due time
- `task_overdue`: Sent when task deadline is missed
- `task_completed`: Sent to parent when child completes task (FYI)
- `task_approval_requested`: Sent to parent when child completes task requiring approval
- `task_approved`: Sent to child when parent approves task
- `task_rejected`: Sent to child when parent rejects task

### Gamification
- `streak_guard`: Sent at 20:00 if user has active streak but no tasks completed today
- `badge_unlocked`: Sent when user earns new badge
- `points_awarded`: Sent when user receives points

### System
- `test`: Test notification for debugging

## API Endpoints

### Device Registration

#### Register Device Token (Android/iOS)
```http
POST /notifications/register-device
Authorization: Bearer {token}
Content-Type: application/json

{
  "token": "fcm-device-token",
  "platform": "android"  // or "ios"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Device registered for push notifications"
}
```

#### Register WebPush Subscription (Web)
```http
POST /notifications/register-webpush
Authorization: Bearer {token}
Content-Type: application/json

{
  "endpoint": "https://fcm.googleapis.com/fcm/send/...",
  "p256dh": "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTp...",
  "auth": "tBHItJI5svbpez7KI4CCXg"
}
```

**Response**:
```json
{
  "success": true,
  "message": "WebPush subscription registered"
}
```

### Notification Management

#### Get Notifications
```http
GET /notifications?unread_only=false&limit=50
Authorization: Bearer {token}
```

**Response**:
```json
[
  {
    "id": "notif-uuid",
    "userId": "user-uuid",
    "type": "task_due",
    "title": "Task due soon: Clean room",
    "body": "Your task is due in 60 minutes",
    "payload": {
      "task_id": "task-uuid",
      "due": "2025-11-11T15:00:00Z"
    },
    "status": "sent",
    "sentAt": "2025-11-11T14:00:00Z",
    "readAt": null,
    "scheduledFor": null,
    "createdAt": "2025-11-11T14:00:00Z"
  }
]
```

#### Get Unread Count
```http
GET /notifications/unread-count
Authorization: Bearer {token}
```

**Response**:
```json
{
  "unread_count": 3
}
```

#### Mark Notification as Read
```http
PUT /notifications/{notification_id}/read
Authorization: Bearer {token}
```

**Response**:
```json
{
  "success": true,
  "notification_id": "notif-uuid"
}
```

#### Mark All as Read
```http
POST /notifications/mark-all-read
Authorization: Bearer {token}
```

**Response**:
```json
{
  "success": true,
  "count": 5,
  "message": "Marked 5 notifications as read"
}
```

#### Delete Notification
```http
DELETE /notifications/{notification_id}
Authorization: Bearer {token}
```

**Response**:
```json
{
  "success": true,
  "notification_id": "notif-uuid"
}
```

### Testing

#### Send Test Notification
```http
POST /notifications/test
Authorization: Bearer {token}
```

**Response**:
```json
{
  "success": true,
  "result": {
    "push_sent": 2,
    "email_sent": false,
    "notification_id": "notif-uuid"
  },
  "message": "Test notification sent to 2 device(s)"
}
```

## Setup Instructions

### Firebase Configuration (FCM)

1. Create Firebase project at https://console.firebase.google.com
2. Download service account key JSON
3. Set environment variable:
   ```bash
   FIREBASE_CREDENTIALS_PATH=/path/to/serviceAccountKey.json
   ```

### Email Configuration

#### Sendgrid
```bash
SENDGRID_API_KEY=your-sendgrid-api-key
```

#### Mailgun (Fallback)
```bash
MAILGUN_API_KEY=your-mailgun-api-key
MAILGUN_DOMAIN=your-domain.com
```

### WebPush Configuration

Generate VAPID keys:
```bash
npx web-push generate-vapid-keys
```

Set environment variable:
```bash
VAPID_PRIVATE_KEY=your-private-key
```

## Client Integration

### Flutter (Android/iOS)

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

// Get FCM token
final fcmToken = await FirebaseMessaging.instance.getToken();

// Register with backend
await http.post(
  Uri.parse('$apiUrl/notifications/register-device'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'token': fcmToken,
    'platform': Platform.isAndroid ? 'android' : 'ios',
  }),
);

// Listen for notifications
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Notification: ${message.notification?.title}');
});
```

### Web (JavaScript)

```javascript
// Request permission
const permission = await Notification.requestPermission();

if (permission === 'granted') {
  // Register service worker
  const registration = await navigator.serviceWorker.register('/sw.js');

  // Subscribe to push
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: VAPID_PUBLIC_KEY
  });

  // Register with backend
  await fetch('/notifications/register-webpush', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      endpoint: subscription.endpoint,
      p256dh: btoa(String.fromCharCode(...new Uint8Array(subscription.keys.p256dh))),
      auth: btoa(String.fromCharCode(...new Uint8Array(subscription.keys.auth)))
    })
  });
}
```

## Background Workers

### Scheduled Notification Processor

Run every 5 minutes to process scheduled notifications:

```python
from services.notification_service import NotificationService

async def process_scheduled_notifications():
    service = NotificationService(db)
    await service.process_scheduled_notifications()
```

### Streak Guard Check

Run daily at 20:00:

```python
from services.notification_service import NotificationService

async def run_streak_guard():
    service = NotificationService(db)
    await service.check_streak_guard()
```

## Troubleshooting

### Push Notifications Not Received

1. **Check device token registration**:
   ```http
   GET /notifications/devices
   Authorization: Bearer {token}
   ```

2. **Verify Firebase credentials**:
   - Ensure `FIREBASE_CREDENTIALS_PATH` is set
   - Verify service account JSON is valid

3. **Test notification sending**:
   ```http
   POST /notifications/test
   Authorization: Bearer {token}
   ```

### Email Notifications Not Sent

1. **Check email provider configuration**:
   - Verify Sendgrid/Mailgun API keys are set
   - Test API keys with provider's test endpoints

2. **Check user email**:
   - Ensure user has valid email address
   - Verify email is not marked as bounce/spam

## Best Practices

1. **Register devices on login**: Always register device token when user logs in
2. **Unregister on logout**: Remove device token when user logs out
3. **Handle permissions**: Request notification permission before registering device
4. **Test thoroughly**: Use test endpoint to verify push delivery
5. **Monitor errors**: Log all notification sending errors for debugging

## Security Considerations

- Device tokens are stored securely and associated with user accounts
- Only users can access their own notifications
- Email notifications only sent for critical events
- Push notification payload should not contain sensitive data
- Use deep links for navigation, not sensitive data in payload
