# Kiosk Mode Implementation Guide

## Overview
Kiosk mode provides a fullscreen, read-only interface for shared family devices (tablets, smart displays). It displays daily tasks and events with auto-refresh functionality.

## Features Implemented

### Frontend (Flutter Web)

#### 1. Data Models (`lib/models/kiosk_models.dart`)
- **KioskTask**: Task with completion status, points, due date
- **KioskMember**: Family member with avatar, tasks, points
- **KioskEvent**: Calendar event with time, location, color
- **KioskTodayData**: Complete today view data (members + events)
- **KioskWeekData**: Complete week view data (7 days)
- **KioskDayData**: Single day data for week view

#### 2. Providers (`lib/features/kiosk/kiosk_provider.dart`)
- `kioskTodayDataProvider`: Fetches today's data from `/kiosk/today`
- `kioskWeekDataProvider`: Fetches week data from `/kiosk/week`
- `kioskPinProvider`: Verifies exit PIN via `/kiosk/verify-pin`

#### 3. Screens

**KioskTodayScreen** (`lib/features/kiosk/kiosk_today_screen.dart`):
- 4-column member grid (responsive: 3 cols on medium, 2 on small screens)
- Family progress indicator
- Current events (highlighted with "NOW" badge)
- Upcoming events list
- Auto-refresh via pull-to-refresh

**KioskWeekScreen** (`lib/features/kiosk/kiosk_week_screen.dart`):
- 7-day horizontal scrollable columns
- Each day shows: date, task progress, events
- Week completion progress
- "TODAY" badge on current day

#### 4. Widgets

**KioskShell** (`lib/features/kiosk/kiosk_shell.dart`):
- Wraps all kiosk screens
- Clock display (updates every second)
- Auto-refresh timer (5 minutes)
- Fullscreen mode (web)
- Exit button (long-press 3 seconds)

**PinExitDialog** (`lib/widgets/pin_exit_dialog.dart`):
- 4-digit PIN input
- Real-time verification with backend
- Error feedback
- Auto-clear after 3 seconds

**KioskMemberCard** (`lib/widgets/kiosk_member_card.dart`):
- Large avatar (80dp) with progress ring
- Name and task count
- Points display
- Compact task list with completion icons

**KioskEventCard** (`lib/widgets/kiosk_event_card.dart`):
- Time range display
- Event title and location
- Duration badge
- Color indicator
- "NOW" badge for current events

#### 5. Web Support (`web/`)
**fullscreen.js**:
- Cross-browser fullscreen API
- Functions: `requestFullscreenJS()`, `exitFullscreenJS()`, `isFullscreenJS()`
- Supports Chrome, Safari, Firefox, Edge

**index.html**:
- Includes fullscreen.js script
- PWA-ready structure
- Loading indicator

#### 6. Routes (`lib/main.dart`)
- `/kiosk/today` → KioskTodayScreen
- `/kiosk/week` → KioskWeekScreen
- Auth-protected but skip redirect for kiosk routes

## Backend API Requirements

### Required Endpoints

#### 1. GET `/kiosk/today`
**Purpose**: Fetch today's tasks and events for all family members

**Headers**:
```
Authorization: Bearer {token}
```

**Query Parameters**:
- `familyId` (optional): Family ID (auto-detected from token if not provided)

**Response** (200 OK):
```json
{
  "familyName": "The Smith Family",
  "date": "2025-11-11T00:00:00Z",
  "members": [
    {
      "id": "member-uuid-1",
      "displayName": "Noah",
      "avatar": "https://api.example.com/avatars/noah.jpg",
      "totalPoints": 1250,
      "weeklyPoints": 85,
      "tasks": [
        {
          "id": "task-uuid-1",
          "title": "Vaatwasser uitruimen",
          "completed": false,
          "pointValue": 10,
          "dueDate": "2025-11-11T18:00:00Z"
        },
        {
          "id": "task-uuid-2",
          "title": "Huiswerk maken",
          "completed": true,
          "pointValue": 15,
          "dueDate": "2025-11-11T20:00:00Z"
        }
      ]
    },
    {
      "id": "member-uuid-2",
      "displayName": "Emma",
      "avatar": "https://api.example.com/avatars/emma.jpg",
      "totalPoints": 980,
      "weeklyPoints": 72,
      "tasks": [
        {
          "id": "task-uuid-3",
          "title": "Kamer opruimen",
          "completed": false,
          "pointValue": 20,
          "dueDate": null
        }
      ]
    }
  ],
  "events": [
    {
      "id": "event-uuid-1",
      "title": "Soccer Practice",
      "start": "2025-11-11T15:00:00Z",
      "end": "2025-11-11T16:30:00Z",
      "description": "Weekly soccer practice at the park",
      "location": "Sportpark West",
      "color": "#4CAF50",
      "memberIds": ["member-uuid-1"]
    },
    {
      "id": "event-uuid-2",
      "title": "Family Dinner",
      "start": "2025-11-11T18:00:00Z",
      "end": "2025-11-11T19:00:00Z",
      "description": null,
      "location": "Home",
      "color": "#2196F3",
      "memberIds": ["member-uuid-1", "member-uuid-2"]
    }
  ]
}
```

**Business Logic**:
1. Get authenticated user's family ID from token
2. Query tasks where `due_date` = today OR `due_date` IS NULL (recurring tasks)
3. Filter to tasks assigned to family members
4. Include task completion status for today
5. Query calendar events where `start_date` = today
6. Return family name, members with tasks, and events

---

#### 2. GET `/kiosk/week`
**Purpose**: Fetch week overview (7 days) with task/event summary

**Headers**:
```
Authorization: Bearer {token}
```

**Query Parameters**:
- `familyId` (optional): Family ID
- `startDate` (optional): Week start date (defaults to current week's Monday)

**Response** (200 OK):
```json
{
  "familyName": "The Smith Family",
  "startDate": "2025-11-11T00:00:00Z",
  "endDate": "2025-11-17T23:59:59Z",
  "days": [
    {
      "date": "2025-11-11T00:00:00Z",
      "tasksTotal": 8,
      "tasksCompleted": 5,
      "events": [
        {
          "id": "event-uuid-1",
          "title": "Soccer Practice",
          "start": "2025-11-11T15:00:00Z",
          "end": "2025-11-11T16:30:00Z",
          "description": null,
          "location": "Sportpark West",
          "color": "#4CAF50",
          "memberIds": ["member-uuid-1"]
        }
      ]
    },
    {
      "date": "2025-11-12T00:00:00Z",
      "tasksTotal": 6,
      "tasksCompleted": 2,
      "events": []
    },
    {
      "date": "2025-11-13T00:00:00Z",
      "tasksTotal": 7,
      "tasksCompleted": 0,
      "events": [
        {
          "id": "event-uuid-3",
          "title": "Piano Lesson",
          "start": "2025-11-13T16:00:00Z",
          "end": "2025-11-13T17:00:00Z",
          "description": null,
          "location": "Music School",
          "color": "#FF9800",
          "memberIds": ["member-uuid-2"]
        }
      ]
    }
    // ... 4 more days
  ]
}
```

**Business Logic**:
1. Calculate week start (Monday) and end (Sunday) from `startDate` or current date
2. For each day in the week:
   - Count total tasks due that day (across all family members)
   - Count completed tasks for that day
   - Fetch events for that day
3. Return 7-day array with aggregated data

---

#### 3. POST `/kiosk/verify-pin`
**Purpose**: Verify 4-digit PIN to exit kiosk mode

**Headers**:
```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body**:
```json
{
  "pin": "1234"
}
```

**Response** (200 OK):
```json
{
  "valid": true
}
```

**Response** (200 OK - Invalid PIN):
```json
{
  "valid": false
}
```

**Business Logic**:
1. Get authenticated user's family ID from token
2. Query family record for `kiosk_pin` field
3. Compare provided PIN with stored PIN (use constant-time comparison)
4. Return `valid: true` if match, `false` otherwise
5. Consider rate-limiting (max 5 attempts per minute)

---

### Database Schema Changes

Add to `families` table:
```sql
ALTER TABLE families
ADD COLUMN kiosk_pin VARCHAR(4) DEFAULT '0000';

-- Create index for faster lookup
CREATE INDEX idx_families_kiosk_pin ON families(id, kiosk_pin);
```

**Note**: Store PIN as plain text (it's a convenience feature, not security-critical). Family admins can set/change PIN via settings.

---

### Security Considerations

1. **Rate Limiting**: Implement rate limiting on PIN verification (5 attempts/minute)
2. **Token Validation**: All kiosk endpoints require valid JWT token
3. **Family Scope**: Users can only access data for their own family
4. **Read-Only**: Kiosk endpoints are read-only (no POST/PUT/DELETE for tasks/events)

---

## Usage

### Accessing Kiosk Mode

**Web (PWA)**:
1. Navigate to `https://app.famquest.com/kiosk/today` or `/kiosk/week`
2. App automatically requests fullscreen mode
3. Long-press exit button → Enter 4-digit PIN → Return to normal mode

**Recommended Setup**:
- Tablet (10" or larger) in landscape mode
- Mounted on wall or kitchen counter
- Always-on display (adjust device sleep settings)
- Strong Wi-Fi connection for real-time updates

### Configuration

**Set Kiosk PIN** (Admin Panel - To Be Implemented):
```
Settings → Kiosk Mode → Set PIN (4 digits)
```

**Default PIN**: `0000` (family admin should change immediately)

---

## Testing

### Frontend Testing

**Widget Tests**:
```bash
cd flutter_app
flutter test test/widgets/pin_exit_dialog_test.dart
```

**Integration Test**:
```bash
flutter test integration_test/kiosk_mode_test.dart
```

**Manual Test Checklist**:
- [ ] Navigate to `/kiosk/today` → Data loads correctly
- [ ] Member cards display avatars, tasks, progress
- [ ] Events show time, location, duration
- [ ] Current events have "NOW" badge
- [ ] Long-press exit button → PIN dialog appears
- [ ] Enter correct PIN → Returns to `/home`
- [ ] Enter incorrect PIN → Error message, clears input
- [ ] Auto-refresh after 5 minutes (check network tab)
- [ ] Fullscreen mode works on desktop browser (F11 fallback)
- [ ] Responsive design on tablet (1024px width)
- [ ] Clock updates every second
- [ ] Week view shows 7 days horizontally
- [ ] Week view highlights "TODAY"

### Backend Testing

**API Test**:
```bash
# Test today endpoint
curl -X GET https://api.famquest.com/kiosk/today \
  -H "Authorization: Bearer {token}"

# Test week endpoint
curl -X GET https://api.famquest.com/kiosk/week \
  -H "Authorization: Bearer {token}"

# Test PIN verification
curl -X POST https://api.famquest.com/kiosk/verify-pin \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"pin": "1234"}'
```

---

## Troubleshooting

### Issue: Fullscreen Not Working
**Cause**: Browser security restrictions
**Solution**: User must interact with page first (click anywhere), then fullscreen activates

### Issue: Auto-Refresh Not Triggering
**Cause**: Timer cleared on unmount
**Solution**: Check browser console for errors, verify `ref.invalidate()` is called

### Issue: PIN Verification Fails
**Cause**: Network timeout or invalid token
**Solution**: Check network tab, verify token is valid, backend is reachable

### Issue: Clock Not Updating
**Cause**: Timer not started
**Solution**: Check `_startClock()` is called in `initState()`

---

## Future Enhancements

1. **Voice Announcements**: Speak upcoming events via TTS
2. **Weather Widget**: Show current weather and forecast
3. **Photo Carousel**: Display family photos when idle
4. **Gesture Controls**: Swipe to navigate between today/week views
5. **Multi-Family Support**: Switch between families via QR code scan
6. **Offline Mode**: Cache last fetched data, show stale indicator
7. **Admin Remote Control**: Update kiosk display settings from mobile app

---

## File Structure

```
flutter_app/
├── lib/
│   ├── features/
│   │   └── kiosk/
│   │       ├── kiosk_provider.dart          (170 lines)
│   │       ├── kiosk_shell.dart             (150 lines)
│   │       ├── kiosk_today_screen.dart      (280 lines)
│   │       └── kiosk_week_screen.dart       (320 lines)
│   ├── models/
│   │   └── kiosk_models.dart                (380 lines)
│   ├── widgets/
│   │   ├── kiosk_member_card.dart           (210 lines)
│   │   ├── kiosk_event_card.dart            (150 lines)
│   │   └── pin_exit_dialog.dart             (160 lines)
│   └── main.dart                            (Updated with routes)
├── web/
│   ├── fullscreen.js                        (90 lines)
│   └── index.html                           (Updated with script)
└── docs/
    └── KIOSK_MODE_GUIDE.md                  (This file)

Total: ~1,910 lines of new/modified code
```

---

## Backend Implementation Checklist

- [ ] Create `/kiosk/today` endpoint
- [ ] Create `/kiosk/week` endpoint
- [ ] Create `/kiosk/verify-pin` endpoint
- [ ] Add `kiosk_pin` column to `families` table
- [ ] Implement rate limiting for PIN verification
- [ ] Write unit tests for kiosk endpoints
- [ ] Update API documentation
- [ ] Add family admin settings for PIN management

---

## Support

For issues or questions:
- Flutter app: Check `flutter_app/README.md`
- Backend API: See `backend/docs/API.md`
- General: Create GitHub issue with `[kiosk]` prefix
