# Helper Role UI Guide

## Overview
The Helper Role UI enables families to grant time-limited access to external helpers (cleaners, babysitters, etc.) with restricted permissions and a simplified task interface.

## Features Implemented

### 1. Helper Invite Screen (`lib/features/helper/helper_invite_screen.dart`)

Parent-facing screen for managing external help:

**Invite Creation Form:**
- Name input (e.g., "Maria (Cleaner)")
- Email input (for future communication)
- Date range selection (Start date → End date)
- Permission configuration:
  - ✓ View assigned tasks (default: enabled)
  - ✓ Complete tasks (default: enabled)
  - ✓ Upload photos (default: enabled)
  - ✗ View points (default: disabled)

**Invite Code Generation:**
- 6-digit PIN code (e.g., "123456")
- Shareable via clipboard copy
- Valid for 7 days
- Displayed in modal dialog with copy button

**Active Helpers List:**
- View all active helpers
- See access duration
- Task assignment count
- Last seen timestamp
- Deactivate/delete actions

### 2. Helper Join Screen (`lib/features/helper/helper_join_screen.dart`)

Helper-facing screen to accept invites:

**PIN Entry:**
- 6-digit code input using `pin_code_fields` package
- Auto-verification on completion
- Visual feedback (error/success states)
- Clear error messages

**Invite Preview:**
After valid code entry, displays:
- Family name
- Inviter name (parent)
- Access duration (start → end date)
- Granted permissions list
- Accept/Decline buttons

**Validation:**
- Expired code detection
- Invalid code handling
- Network error recovery

### 3. Helper Home Screen (`lib/features/helper/helper_home_screen.dart`)

Simplified task interface for helpers:

**Header:**
- Family name display
- "External Help" role badge
- Current date
- Tasks assigned today count

**Task List:**
- Only assigned tasks visible (privacy preserved)
- Card per task with:
  - Category icon
  - Title + description
  - Due date with urgency color coding
  - Points (if permission granted)
  - Complete button

**Task Actions:**
- Mark as complete
- View task details (modal)
- Upload photo (if permitted)
- No access to family-wide data

**Navigation:**
- Refresh button
- Logout button

## Data Models

### HelperInvite (`lib/models/helper_models.dart`)
```dart
class HelperInvite {
  final String id;
  final String code;              // 6-digit PIN
  final String familyId;
  final String familyName;
  final String inviterName;
  final String helperName;
  final String helperEmail;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime expiresAt;      // Code expiry (7 days)
  final HelperPermissions permissions;
  final bool isActive;
  final DateTime? acceptedAt;
}
```

### HelperPermissions
```dart
class HelperPermissions {
  final bool canViewAssignedTasks;  // default: true
  final bool canCompleteTasks;      // default: true
  final bool canUploadPhotos;       // default: true
  final bool canViewPoints;         // default: false
}
```

### HelperUser
```dart
class HelperUser {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final DateTime activeUntil;
  final int tasksAssigned;
  final DateTime? lastSeen;
  final HelperPermissions permissions;
}
```

### CreateHelperInviteRequest
```dart
class CreateHelperInviteRequest {
  final String helperName;
  final String helperEmail;
  final DateTime startDate;
  final DateTime endDate;
  final HelperPermissions permissions;
}
```

## API Integration

### Required Backend Endpoints

1. **POST /helpers/invite**
   - Body: CreateHelperInviteRequest JSON
   - Returns: HelperInvite with generated code
   ```json
   {
     "id": "inv123",
     "code": "123456",
     "family_id": "fam456",
     "family_name": "Smith Family",
     "inviter_name": "John Smith",
     "helper_name": "Maria",
     "helper_email": "maria@example.com",
     "start_date": "2025-11-11T00:00:00Z",
     "end_date": "2025-12-11T23:59:59Z",
     "expires_at": "2025-11-18T23:59:59Z",
     "permissions": {
       "can_view_assigned_tasks": true,
       "can_complete_tasks": true,
       "can_upload_photos": true,
       "can_view_points": false
     },
     "is_active": true
   }
   ```

2. **POST /helpers/verify**
   - Body: `{"code": "123456"}`
   - Returns: HelperInvite details (without sensitive family data)
   ```json
   {
     "family_name": "Smith Family",
     "inviter_name": "John Smith",
     "start_date": "2025-11-11T00:00:00Z",
     "end_date": "2025-12-11T23:59:59Z",
     "permissions": {...}
   }
   ```

3. **POST /helpers/accept**
   - Body: `{"code": "123456"}`
   - Returns: Auth tokens + user object
   ```json
   {
     "accessToken": "jwt_token_here",
     "refreshToken": "refresh_token_here",
     "userId": "helper789",
     "familyId": "fam456",
     "role": "helper"
   }
   ```

4. **GET /helpers**
   - Returns: List of active helpers for family
   ```json
   [
     {
       "id": "helper789",
       "name": "Maria",
       "email": "maria@example.com",
       "active_until": "2025-12-11T23:59:59Z",
       "tasks_assigned": 5,
       "last_seen": "2025-11-11T10:30:00Z",
       "permissions": {...}
     }
   ]
   ```

5. **DELETE /helpers/{helperId}**
   - Deactivates helper (soft delete or set active: false)
   - Returns: 204 No Content

6. **GET /helpers/tasks**
   - Returns: Tasks assigned to current helper
   ```json
   [
     {
       "id": "task123",
       "title": "Clean kitchen",
       "description": "Wipe counters and mop floor",
       "category": "cleaning",
       "due_date": "2025-11-11T14:00:00Z",
       "points": 50,
       "status": "pending"
     }
   ]
   ```

## Security Considerations

### Access Control
- Helpers can ONLY see tasks assigned to them
- No access to family member profiles
- No access to rewards/shop
- No access to admin features
- No access to other helpers' tasks

### Code Security
- 6-digit codes provide 1,000,000 combinations
- Codes expire after 7 days
- One-time use (invalidated after acceptance)
- Rate limiting on verification attempts (backend)

### Time-Limited Access
- Access automatically expires after end date
- Backend must validate helper permissions on each request
- Frontend should handle 403 Forbidden gracefully

### Data Privacy
- Helpers cannot see:
  - Family member names (only assigned tasks)
  - Family calendar
  - Family stats/leaderboard
  - Other tasks not assigned to them
  - Points (unless permission granted)

## User Flows

### Parent: Invite Helper
1. Navigate to Helper Management (from settings/admin)
2. Fill in helper details (name, email, dates)
3. Configure permissions
4. Generate invite code
5. Share code with helper (via SMS, email, or in-person)
6. Helper appears in active list after acceptance

### Helper: Join Family
1. Receive invite code from family
2. Open FamQuest app (or install)
3. Select "Join as Helper" (or similar entry point)
4. Enter 6-digit code
5. Review family info and permissions
6. Accept invite
7. Redirected to helper home screen

### Helper: Daily Usage
1. Login to app
2. See list of assigned tasks
3. Tap task to view details
4. Complete task (with optional photo)
5. Task marked complete, notification sent to parent
6. Logout when done

## Navigation Integration

Add to router configuration:
```dart
// Parent routes
GoRoute(
  path: '/helpers/invite',
  builder: (context, state) => const HelperInviteScreen(),
),

// Public routes (no auth required)
GoRoute(
  path: '/helpers/join',
  builder: (context, state) => const HelperJoinScreen(),
),

// Helper routes (helper role required)
GoRoute(
  path: '/helper/home',
  builder: (context, state) => const HelperHomeScreen(),
),
```

Access from parent settings:
```dart
ListTile(
  leading: const Icon(Icons.support_agent),
  title: const Text('External Help'),
  subtitle: const Text('Manage helpers and invites'),
  onTap: () => context.go('/helpers/invite'),
)
```

## Material 3 Design

All screens follow Material 3 guidelines:
- Primary color for action buttons
- Surface containers for cards
- Outline variants for borders
- Typography scale for hierarchy
- Elevation system (0, 2, 4)

## Accessibility

- High contrast colors for PIN input
- Clear error messages
- Touch targets ≥48dp
- Semantic labels for screen readers
- Keyboard navigation support
- Sufficient color contrast ratios

## Testing

### Widget Tests

Create `test/features/helper/helper_invite_screen_test.dart`:
```dart
testWidgets('Helper invite form validates inputs', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: HelperInviteScreen()),
  );

  // Tap generate without filling form
  await tester.tap(find.text('Generate Invite Code'));
  await tester.pump();

  // Should show validation errors
  expect(find.text('Name is required'), findsOneWidget);
  expect(find.text('Email is required'), findsOneWidget);
});
```

### Integration Tests

Create `integration_test/helper_flow_test.dart`:
```dart
testWidgets('Complete helper invite flow', (tester) async {
  // 1. Parent creates invite
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('External Help'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'Test Helper');
  await tester.enterText(find.byType(TextField).at(1), 'test@example.com');
  await tester.tap(find.text('Generate Invite Code'));
  await tester.pumpAndSettle();

  final codeText = find.byType(Text).evaluate()
    .firstWhere((e) => e.widget.toString().contains('123456'));

  // 2. Helper joins with code
  await tester.tap(find.text('Close'));
  await tester.pumpAndSettle();

  // Navigate to join screen and enter code
  // ... continue test
});
```

## Error Handling

### Common Scenarios

**Expired Code:**
```dart
if (invite.isExpired) {
  setState(() => _errorMessage = 'This invite code has expired');
}
```

**Invalid Code:**
```dart
catch (e) {
  setState(() => _errorMessage = 'Invalid code. Please check and try again.');
}
```

**Network Errors:**
```dart
try {
  await api.verifyHelperCode(code);
} catch (e) {
  if (e is TimeoutException) {
    showSnackBar('Request timed out. Check your connection.');
  } else {
    showSnackBar('Network error. Please try again.');
  }
}
```

## Backend Coordination

### Database Schema (Reference)

**helper_invites table:**
```sql
CREATE TABLE helper_invites (
  id UUID PRIMARY KEY,
  code VARCHAR(6) UNIQUE NOT NULL,
  family_id UUID REFERENCES families(id),
  inviter_id UUID REFERENCES users(id),
  helper_name VARCHAR(255) NOT NULL,
  helper_email VARCHAR(255) NOT NULL,
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  permissions JSONB NOT NULL,
  is_active BOOLEAN DEFAULT true,
  accepted_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**users table (helper role):**
```sql
ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'child';
-- role can be: 'parent', 'teen', 'child', 'helper'
```

### Permission Enforcement (Backend)

Every task-related endpoint must validate helper permissions:
```python
def check_helper_permissions(user: User, task: Task):
    if user.role != 'helper':
        return  # Not a helper, normal permissions apply

    if task.assigned_to != user.id:
        raise PermissionError("Helpers can only access assigned tasks")

    if not user.permissions.can_complete_tasks:
        raise PermissionError("Helper cannot complete tasks")
```

## Future Enhancements

1. **SMS Invites**: Send code via SMS instead of manual sharing
2. **QR Codes**: Generate QR code for easier code entry
3. **Task Assignment UI**: Parent UI to assign specific tasks to helpers
4. **Helper History**: View helper's past task completions
5. **Recurring Access**: Option for recurring helper schedules
6. **Multiple Families**: Helper can work for multiple families
7. **Rating System**: Parents rate helper performance
8. **Notifications**: Push notifications for new task assignments

## Troubleshooting

### Issue: Helper cannot see tasks
**Solution**: Verify backend is filtering tasks by `assigned_to = helper.id` and helper has `canViewAssignedTasks` permission.

### Issue: Invite code not working
**Solution**: Check code expiry, ensure it hasn't been used already, verify network connectivity.

### Issue: Helper sees family-wide data
**Critical Security Issue**: Immediately fix backend permission checks. Helper role must be restricted in all endpoints.

## Best Practices

1. **Clear Role Indication**: Always show "External Help" badge to prevent confusion
2. **Limited UI**: Keep helper interface minimal to avoid overwhelm
3. **Time Awareness**: Show access expiry clearly to avoid surprise logout
4. **Privacy First**: Never expose family member names/profiles to helpers
5. **Graceful Degradation**: Handle expired access gracefully with clear messaging
