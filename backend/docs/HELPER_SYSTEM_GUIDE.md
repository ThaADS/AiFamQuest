# FamQuest Helper System Guide

Complete guide to the FamQuest helper invite system for temporary family access.

## Overview

The helper system enables families to grant temporary access to:
- Babysitters
- Grandparents
- Nannies
- Other temporary caregivers

**Key Features**:
- 6-digit PIN code invites
- Time-limited access (start/end dates)
- Customizable permissions
- Auto-expiring invites (7 days)
- Parent-only management

## Workflow

1. **Parent creates invite** → Generates 6-digit PIN
2. **Parent shares PIN** → Via SMS, email, or in person
3. **Helper verifies PIN** → Checks invite details
4. **Helper accepts invite** → Creates helper account
5. **Helper accesses app** → Limited by permissions and dates
6. **Parent deactivates helper** → Ends access when no longer needed

## API Endpoints

### Create Helper Invite (Parent Only)

```http
POST /helpers/invite
Authorization: Bearer {parent_token}
Content-Type: application/json

{
  "name": "Sarah Wilson",
  "email": "sarah@example.com",
  "start_date": "2025-11-15T00:00:00Z",
  "end_date": "2025-11-22T00:00:00Z",
  "permissions": {
    "can_view": true,
    "can_complete": true,
    "can_upload_photos": false
  }
}
```

**Response**:
```json
{
  "code": "123456",
  "expires_at": "2025-11-18T00:00:00Z",
  "invite_id": "invite-uuid",
  "name": "Sarah Wilson",
  "start_date": "2025-11-15T00:00:00Z",
  "end_date": "2025-11-22T00:00:00Z"
}
```

### Verify Helper Code

```http
POST /helpers/verify?code=123456
```

**Response**:
```json
{
  "valid": true,
  "family_name": "Smith Family",
  "parent_name": "John Smith",
  "helper_name": "Sarah Wilson",
  "start_date": "2025-11-15T00:00:00Z",
  "end_date": "2025-11-22T00:00:00Z",
  "permissions": {
    "can_view": true,
    "can_complete": true,
    "can_upload_photos": false
  }
}
```

### Accept Helper Invite

```http
POST /helpers/accept?code=123456&password=optional_password
```

**Response**:
```json
{
  "access_token": "jwt-token",
  "refresh_token": "refresh-token",
  "token_type": "bearer",
  "user": {
    "id": "helper-uuid",
    "email": "sarah@example.com",
    "display_name": "Sarah Wilson",
    "role": "helper",
    "family_id": "family-uuid",
    "permissions": {
      "can_view": true,
      "can_complete": true,
      "can_upload_photos": false,
      "helper_start_date": "2025-11-15T00:00:00Z",
      "helper_end_date": "2025-11-22T00:00:00Z"
    }
  }
}
```

### List Active Helpers (Parent Only)

```http
GET /helpers
Authorization: Bearer {parent_token}
```

**Response**:
```json
[
  {
    "id": "helper-uuid",
    "display_name": "Sarah Wilson",
    "email": "sarah@example.com",
    "role": "helper",
    "permissions": {
      "can_view": true,
      "can_complete": true,
      "can_upload_photos": false,
      "helper_start_date": "2025-11-15T00:00:00Z",
      "helper_end_date": "2025-11-22T00:00:00Z"
    },
    "created_at": "2025-11-14T10:00:00Z"
  }
]
```

### Deactivate Helper (Parent Only)

```http
DELETE /helpers/{helper_id}
Authorization: Bearer {parent_token}
```

**Response**:
```json
{
  "success": true,
  "helper_id": "helper-uuid",
  "message": "Helper Sarah Wilson deactivated"
}
```

### List Invites (Parent Only)

```http
GET /helpers/invites
Authorization: Bearer {parent_token}
```

**Response**:
```json
{
  "invites": [
    {
      "code": "123456",
      "name": "Sarah Wilson",
      "email": "sarah@example.com",
      "start_date": "2025-11-15T00:00:00Z",
      "end_date": "2025-11-22T00:00:00Z",
      "expires_at": "2025-11-18T00:00:00Z",
      "used": true,
      "used_at": "2025-11-14T12:00:00Z",
      "created_at": "2025-11-14T10:00:00Z"
    }
  ],
  "total_count": 1
}
```

### Revoke Invite (Parent Only)

```http
DELETE /helpers/invites/{code}
Authorization: Bearer {parent_token}
```

**Response**:
```json
{
  "success": true,
  "code": "123456",
  "message": "Invite revoked"
}
```

## Permissions System

### Available Permissions

| Permission | Description | Default |
|-----------|-------------|---------|
| `can_view` | View tasks and family data | `true` |
| `can_complete` | Mark tasks as complete | `true` |
| `can_upload_photos` | Upload task proof photos | `false` |

### Permission Enforcement

Permissions are checked at API level:

```python
# Example: Check photo upload permission
if not user.permissions.get('can_upload_photos', False):
    raise HTTPException(403, "Helper cannot upload photos")
```

### Recommended Permission Sets

#### Babysitter
```json
{
  "can_view": true,
  "can_complete": true,
  "can_upload_photos": false
}
```
Can see tasks and mark complete, but cannot upload photos.

#### Grandparent
```json
{
  "can_view": true,
  "can_complete": true,
  "can_upload_photos": true
}
```
Full task management capabilities.

#### View-Only Helper
```json
{
  "can_view": true,
  "can_complete": false,
  "can_upload_photos": false
}
```
Can only view tasks, cannot make changes.

## Security Considerations

### Invite Codes

- **6-digit numeric**: Easy to share via phone or text
- **7-day expiration**: Reduces risk of code misuse
- **One-time use**: Code becomes invalid after acceptance
- **Revocable**: Parents can revoke unused codes

### Access Control

- **Time-bound**: Access automatically ends on `end_date`
- **Family-scoped**: Helpers only see their assigned family
- **Permission-limited**: Cannot access admin functions
- **No financial data**: Cannot see points ledger or rewards

### Best Practices

1. **Short-term access**: Limit helper access to specific dates
2. **Minimal permissions**: Grant only necessary permissions
3. **Monitor activity**: Review helper actions in audit log
4. **Deactivate promptly**: End access when no longer needed
5. **Unique emails**: Each helper must have unique email address

## User Experience

### Parent Flow

1. **Open Settings** → "Helpers & Access"
2. **Tap "Invite Helper"**
3. **Enter Details**:
   - Helper name
   - Email address
   - Start/end dates
   - Select permissions
4. **Receive PIN Code**
5. **Share PIN** via SMS, WhatsApp, or verbally

### Helper Flow

1. **Download FamQuest App**
2. **Tap "Join as Helper"**
3. **Enter 6-digit PIN**
4. **Review Details**:
   - Family name
   - Access period
   - Permissions
5. **Tap "Accept"**
6. **Set Password** (optional)
7. **Access App** with limited permissions

## Integration Examples

### Flutter Client

```dart
// Create helper invite
final response = await http.post(
  Uri.parse('$apiUrl/helpers/invite'),
  headers: {
    'Authorization': 'Bearer $parentToken',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'name': 'Sarah Wilson',
    'email': 'sarah@example.com',
    'start_date': DateTime.now().add(Duration(days: 1)).toIso8601String(),
    'end_date': DateTime.now().add(Duration(days: 8)).toIso8601String(),
    'permissions': {
      'can_view': true,
      'can_complete': true,
      'can_upload_photos': false,
    },
  }),
);

final invite = jsonDecode(response.body);
final code = invite['code']; // "123456"

// Share code with helper
Share.share('Your FamQuest helper code: $code');
```

```dart
// Accept helper invite
final response = await http.post(
  Uri.parse('$apiUrl/helpers/accept?code=$code'),
);

final data = jsonDecode(response.body);
final accessToken = data['access_token'];

// Save token and navigate to app
```

### React Web

```typescript
// Create helper invite
const response = await fetch('/helpers/invite', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${parentToken}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    name: 'Sarah Wilson',
    email: 'sarah@example.com',
    start_date: new Date(Date.now() + 86400000).toISOString(),
    end_date: new Date(Date.now() + 691200000).toISOString(),
    permissions: {
      can_view: true,
      can_complete: true,
      can_upload_photos: false,
    },
  }),
});

const invite = await response.json();
console.log(`Share this code: ${invite.code}`);
```

## Database Schema

### HelperInvite Table

```sql
CREATE TABLE helper_invites (
  id VARCHAR PRIMARY KEY,
  familyId VARCHAR REFERENCES families(id),
  createdById VARCHAR REFERENCES users(id),
  code VARCHAR(6) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  startDate TIMESTAMP NOT NULL,
  endDate TIMESTAMP NOT NULL,
  permissions JSONB NOT NULL DEFAULT '{}',
  expiresAt TIMESTAMP NOT NULL,
  used BOOLEAN DEFAULT false,
  usedAt TIMESTAMP,
  usedById VARCHAR REFERENCES users(id),
  createdAt TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_helper_invite_code ON helper_invites(code);
CREATE INDEX idx_helper_invite_family ON helper_invites(familyId);
```

### User Extensions

```sql
ALTER TABLE users ADD COLUMN helperStartDate TIMESTAMP;
ALTER TABLE users ADD COLUMN helperEndDate TIMESTAMP;
```

## Troubleshooting

### Code Not Working

**Issue**: Helper enters code, gets "Invalid or expired code"

**Solutions**:
1. Verify code was typed correctly (6 digits)
2. Check if code has expired (7 days from creation)
3. Verify code hasn't been used already
4. Confirm parent didn't revoke the invite

### Helper Cannot Access Features

**Issue**: Helper logged in but cannot complete tasks

**Solutions**:
1. Check helper permissions: `can_complete` must be true
2. Verify current date is within `start_date` and `end_date`
3. Ensure helper isn't deactivated (check `end_date`)
4. Confirm helper belongs to correct family

### Email Already Registered

**Issue**: Cannot accept invite with existing email

**Solutions**:
1. Use different email address for helper account
2. If helper already has account, parent should add as family member instead
3. Helper can use temporary email if needed

## Migration Guide

Apply migration to add helper system:

```bash
# Run Alembic migration
cd backend
alembic upgrade head

# Migration file: 0004_add_helper_system.py
```

## Future Enhancements

Planned improvements:
- SMS code delivery
- Helper activity dashboard
- Temporary task delegation
- Helper ratings/feedback
- Recurring helper schedules
- Multiple family access
