# Kiosk Mode API Reference

Kiosk mode is a fullscreen PWA view designed for tablets and wall-mounted displays. It provides a read-only overview of the family's daily schedule, showing tasks and events for all family members. Users need a 4-digit PIN to exit kiosk mode.

## Base URL

```
/kiosk
```

All endpoints require authentication via Bearer token in the `Authorization` header.

## Endpoints

### GET /kiosk/today

Get today's schedule overview for all family members.

**Authentication**: Required

**Response**: `200 OK`

```json
{
  "date": "2025-11-11",
  "members": [
    {
      "user_id": "uuid-string",
      "name": "John Doe",
      "avatar_url": "https://example.com/avatar.jpg",
      "capacity_pct": 75.5,
      "tasks": [
        {
          "id": "uuid-string",
          "title": "Clean room",
          "due_time": "14:00",
          "points": 10,
          "status": "open",
          "photo_required": false
        }
      ],
      "events": [
        {
          "id": "uuid-string",
          "title": "Soccer practice",
          "start_time": "16:00",
          "end_time": "17:30"
        }
      ]
    }
  ]
}
```

**Field Descriptions**:

- `date`: Today's date in YYYY-MM-DD format
- `members`: Array of family members with their schedules
  - `user_id`: Unique user identifier
  - `name`: Display name of the family member
  - `avatar_url`: Avatar image URL (optional)
  - `capacity_pct`: Weekly workload as percentage (0-100+)
  - `tasks`: Today's tasks assigned to this member
    - `id`: Task identifier
    - `title`: Task description
    - `due_time`: Due time in HH:MM format (optional)
    - `points`: Points awarded for completion
    - `status`: Task status (open, pendingApproval)
    - `photo_required`: Whether photo proof is required
  - `events`: Today's events where member is attendee
    - `id`: Event identifier
    - `title`: Event description
    - `start_time`: Start time in HH:MM format
    - `end_time`: End time in HH:MM format (optional)

**Notes**:

- Tasks are sorted by due_time ascending
- Events are sorted by start_time ascending
- Only includes tasks with status "open" or "pendingApproval"
- Excludes helpers with expired access (helperEndDate < today)
- Capacity percentage calculated using fairness engine

**Example Request**:

```bash
curl -X GET "https://api.famquest.com/kiosk/today" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### GET /kiosk/week

Get 7-day schedule overview for all family members.

**Authentication**: Required

**Response**: `200 OK`

```json
{
  "start_date": "2025-11-11",
  "end_date": "2025-11-17",
  "days": [
    {
      "date": "2025-11-11",
      "day_name": "Monday",
      "members": [
        {
          "user_id": "uuid-string",
          "name": "John Doe",
          "avatar_url": "https://example.com/avatar.jpg",
          "capacity_pct": 75.5,
          "tasks": [
            {
              "id": "uuid-string",
              "title": "Clean room",
              "due_time": "14:00",
              "points": 10,
              "status": "open",
              "photo_required": false
            }
          ],
          "events": [
            {
              "id": "uuid-string",
              "title": "Soccer practice",
              "start_time": "16:00",
              "end_time": "17:30"
            }
          ]
        }
      ]
    },
    {
      "date": "2025-11-12",
      "day_name": "Tuesday",
      "members": [...]
    }
  ]
}
```

**Field Descriptions**:

- `start_date`: First day (today) in YYYY-MM-DD format
- `end_date`: Last day (today + 6 days) in YYYY-MM-DD format
- `days`: Array of 7 days with schedules
  - `date`: Date in YYYY-MM-DD format
  - `day_name`: Full weekday name (Monday, Tuesday, etc.)
  - `members`: Same structure as /today endpoint

**Notes**:

- Always returns 7 days starting from today
- Each day filters helper access by helperStartDate and helperEndDate
- Capacity percentages recalculated for each day's week context
- Same sorting and filtering rules as /today endpoint

**Example Request**:

```bash
curl -X GET "https://api.famquest.com/kiosk/week" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### POST /kiosk/verify-pin

Verify 4-digit PIN to exit kiosk mode.

**Authentication**: Required

**Request Body**:

```json
{
  "pin": "1234"
}
```

**Response**: `200 OK` (Success)

```json
{
  "valid": true
}
```

**Response**: `200 OK` (Invalid PIN)

```json
{
  "valid": false,
  "error": "Invalid PIN"
}
```

**Response**: `400 Bad Request` (PIN not configured)

```json
{
  "detail": "PIN not configured for this user. Please set a PIN in settings."
}
```

**Field Descriptions**:

Request:

- `pin`: 4-digit numeric string

Response:

- `valid`: Boolean indicating if PIN is correct
- `error`: Error message if invalid (optional)

**Notes**:

- PIN must be exactly 4 digits
- PIN must be numeric characters only
- User must have PIN set in User.pin field
- Returns 200 OK even for invalid PIN (check `valid` field)
- Returns 400 Bad Request if PIN not configured

**Validation Rules**:

- Length must be exactly 4 characters
- All characters must be digits (0-9)
- User must have PIN configured in database

**Example Request**:

```bash
curl -X POST "https://api.famquest.com/kiosk/verify-pin" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"pin": "1234"}'
```

---

## Error Responses

### 401 Unauthorized

Missing or invalid authentication token.

```json
{
  "detail": "Not authenticated"
}
```

### 404 Not Found

User not found in database.

```json
{
  "detail": "User not found"
}
```

### 400 Bad Request

PIN not configured for user (verify-pin only).

```json
{
  "detail": "PIN not configured for this user. Please set a PIN in settings."
}
```

---

## Authentication

All kiosk endpoints require a valid JWT Bearer token:

```bash
Authorization: Bearer <JWT_TOKEN>
```

The token payload must contain:

```json
{
  "sub": "user_id"
}
```

---

## Data Models

### KioskTaskOut

```typescript
{
  id: string;
  title: string;
  due_time?: string;  // HH:MM format
  points: number;
  status: "open" | "pendingApproval";
  photo_required: boolean;
}
```

### KioskEventOut

```typescript
{
  id: string;
  title: string;
  start_time: string;  // HH:MM format
  end_time?: string;   // HH:MM format
}
```

### KioskMemberOut

```typescript
{
  user_id: string;
  name: string;
  avatar_url?: string;
  capacity_pct: number;  // 0-100+
  tasks: KioskTaskOut[];
  events: KioskEventOut[];
}
```

---

## Capacity Calculation

The `capacity_pct` field represents the user's workload as a percentage of their weekly capacity:

- **Child** (6-10 years): 120 minutes/week = 100%
- **Teen** (11-17 years): 240 minutes/week = 100%
- **Parent**: 360 minutes/week = 100%
- **Helper**: Excluded from fairness calculations (0%)

Calculation considers:

- Number of tasks assigned
- Total estimated duration of tasks
- Calendar busy hours from events
- Role-based capacity limits

Values over 100% indicate overload.

---

## Helper Access Filtering

Helpers have time-limited access controlled by:

- `User.helperStartDate`: Access begins
- `User.helperEndDate`: Access expires

Filtering behavior:

- `/today`: Excludes helpers where helperEndDate < today
- `/week`: Filters helpers per day (checks both start and end dates)

Active helpers appear in member lists like regular family members.

---

## Frontend Integration

### Kiosk Mode PWA

The kiosk endpoints support a fullscreen tablet display:

1. User opens PWA in fullscreen mode
2. Display shows today's or week's schedule
3. User enters PIN to exit fullscreen
4. POST /verify-pin validates PIN before exiting

**Recommended refresh interval**: 30-60 seconds for real-time updates

### Example Frontend Flow

```typescript
// Load today's schedule
async function loadKioskToday() {
  const response = await fetch("/kiosk/today", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await response.json();
  renderSchedule(data);
}

// Exit kiosk with PIN
async function exitKiosk(pin: string) {
  const response = await fetch("/kiosk/verify-pin", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ pin }),
  });
  const result = await response.json();

  if (result.valid) {
    document.exitFullscreen();
  } else {
    showError(result.error);
  }
}
```

---

## Testing

Comprehensive test suite available in `backend/tests/test_kiosk.py`.

Run tests:

```bash
cd backend
pytest tests/test_kiosk.py -v
```

Test coverage includes:

- All endpoints with valid data
- Edge cases (no tasks, no events, expired helpers)
- Error cases (invalid PIN, missing PIN, unauthorized)
- Data validation (sorting, filtering, formatting)
- Helper access date boundaries
- Capacity calculations

---

## Security Considerations

1. **PIN Security**:

   - PINs stored in User.pin field (not hashed - consider upgrading for production)
   - PIN must be exactly 4 digits
   - No rate limiting on verify-pin (recommend adding for production)

2. **Data Access**:

   - Users can only see their own family's data
   - Authentication required for all endpoints
   - Helper access automatically filtered by date range

3. **Recommendations**:
   - Hash PINs before storage (bcrypt recommended)
   - Add rate limiting to verify-pin endpoint (max 5 attempts/minute)
   - Consider adding PIN expiration (e.g., 90 days)
   - Add audit logging for PIN verification attempts

---

## Related Documentation

- [Task API Reference](./TASKS_API.md)
- [Calendar API Reference](./CALENDAR_API.md)
- [Fairness Engine Documentation](../core/fairness.py)
- [User Authentication](./AUTH_API.md)
