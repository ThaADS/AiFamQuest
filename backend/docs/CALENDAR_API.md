# Calendar & Events API Documentation

Complete implementation of the FamQuest Calendar API with CRUD operations, recurring events (RRULE), access control, and AI planner integration.

## API Endpoints

### Base URL
```
/calendar
```

### Authentication
All endpoints require Bearer token authentication:
```
Authorization: Bearer <jwt_token>
```

---

## Endpoints

### 1. List Events
**GET** `/calendar`

List events with optional filtering and pagination.

**Query Parameters:**
- `familyId` (optional): Filter by family ID (defaults to user's family)
- `userId` (optional): Filter by attendee user ID
- `start_date` (optional): Start date filter (ISO 8601 format)
- `end_date` (optional): End date filter (ISO 8601 format)
- `category` (optional): Event category (`school|sport|appointment|family|other`)
- `limit` (optional, default=100): Maximum results (1-1000)
- `offset` (optional, default=0): Pagination offset

**Response:** `200 OK`
```json
[
  {
    "id": "event-uuid",
    "title": "Soccer Practice",
    "description": "Weekly soccer practice",
    "start": "2025-11-17T15:00:00Z",
    "end": "2025-11-17T16:30:00Z",
    "allDay": false,
    "attendees": ["user-uuid-1", "user-uuid-2"],
    "color": "#FF5733",
    "category": "sport",
    "familyId": "family-uuid",
    "createdBy": "user-uuid",
    "isRecurring": true,
    "rrule": "FREQ=WEEKLY;BYDAY=MO,WE"
  }
]
```

**Access Control:**
- Parents: View all family events
- Teens: View all family events
- Children: View only events where they are attendees
- Helpers: No calendar access (403)

---

### 2. Get Single Event
**GET** `/calendar/{event_id}`

Get single event by ID.

**Response:** `200 OK`
```json
{
  "id": "event-uuid",
  "title": "Doctor Appointment",
  "description": "Annual checkup",
  "start": "2025-11-20T10:00:00Z",
  "end": "2025-11-20T11:00:00Z",
  "allDay": false,
  "attendees": ["user-uuid"],
  "color": "#3498db",
  "category": "appointment",
  "familyId": "family-uuid",
  "createdBy": "user-uuid",
  "createdAt": "2025-11-15T12:00:00Z",
  "updatedAt": "2025-11-15T12:00:00Z"
}
```

**Errors:**
- `404`: Event not found
- `403`: No access to event

---

### 3. Create Event
**POST** `/calendar`

Create new calendar event.

**Request Body:**
```json
{
  "title": "Birthday Party",
  "description": "Luna's 9th birthday celebration",
  "start": "2025-12-05T14:00:00Z",
  "end": "2025-12-05T17:00:00Z",
  "allDay": false,
  "attendees": ["user-uuid-1", "user-uuid-2"],
  "color": "#FF6EB4",
  "rrule": null,
  "category": "family"
}
```

**Recurring Event Example (Daily):**
```json
{
  "title": "Morning Routine",
  "description": "Daily morning tasks",
  "start": "2025-11-17T07:00:00Z",
  "end": "2025-11-17T08:00:00Z",
  "allDay": false,
  "attendees": ["user-uuid"],
  "rrule": "FREQ=DAILY",
  "category": "family"
}
```

**Recurring Event Example (Weekly on specific days):**
```json
{
  "title": "Swimming Lessons",
  "description": "Monday and Wednesday swimming",
  "start": "2025-11-17T17:00:00Z",
  "end": "2025-11-17T18:00:00Z",
  "allDay": false,
  "attendees": ["user-uuid"],
  "rrule": "FREQ=WEEKLY;BYDAY=MO,WE",
  "category": "sport"
}
```

**Response:** `200 OK`
Returns created event (same structure as GET single event)

**Validation:**
- Start time must be before end time
- RRULE must be valid format
- Attendees must exist in family
- Title is required

**Access Control:**
- Parents: Can create any event
- Teens: Can create own events
- Children/Helpers: Cannot create events (403)

**Errors:**
- `400`: Validation error (invalid dates, RRULE, or attendees)
- `403`: Insufficient permissions

---

### 4. Update Event
**PUT** `/calendar/{event_id}`

Update existing event. For recurring events, updates all future occurrences.

**Request Body:** Same as Create Event

**Response:** `200 OK`
Returns updated event

**Access Control:**
- Parents: Can update any family event
- Teens: Can update only own events
- Children/Helpers: Cannot update events (403)

**Errors:**
- `400`: Validation error
- `403`: Insufficient permissions
- `404`: Event not found

---

### 5. Delete Event
**DELETE** `/calendar/{event_id}`

Delete event. For recurring events, deletes entire series.

**Response:** `200 OK`
```json
{
  "status": "deleted",
  "id": "event-uuid"
}
```

**Access Control:**
- Parents: Can delete any family event
- Teens: Can delete only own events
- Children/Helpers: Cannot delete events (403)

**Errors:**
- `403`: Insufficient permissions
- `404`: Event not found

---

### 6. Month View
**GET** `/calendar/calendar/{year}/{month}`

Get all events for specified month with recurring events expanded.

**Path Parameters:**
- `year`: Calendar year (e.g., 2025)
- `month`: Calendar month (1-12)

**Example:**
```
GET /calendar/calendar/2025/11
```

**Response:** `200 OK`
Returns list of events (same structure as List Events)

**Errors:**
- `400`: Invalid month (must be 1-12)

---

### 7. Current Week View
**GET** `/calendar/week/current`

Get events for current week (Monday to Sunday).

**Response:** `200 OK`
Returns list of events (same structure as List Events)

---

## RRULE Examples

The API supports standard RRULE format for recurring events:

### Daily Recurrence
```
FREQ=DAILY
```
Every day

### Weekly Recurrence
```
FREQ=WEEKLY;BYDAY=MO,WE,FR
```
Every Monday, Wednesday, Friday

### Monthly Recurrence
```
FREQ=MONTHLY;BYMONTHDAY=15
```
15th of every month

### Complex Recurrence
```
FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH
```
Every 2 weeks on Tuesday and Thursday

For complete RRULE specification, see: https://www.rfc-editor.org/rfc/rfc5545#section-3.3.10

---

## Access Control Matrix

| Role    | View Events | Create Events | Update Events | Delete Events |
|---------|-------------|---------------|---------------|---------------|
| Parent  | All family  | Any event     | Any event     | Any event     |
| Teen    | All family  | Own events    | Own events    | Own events    |
| Child   | Own events* | ❌            | ❌            | ❌            |
| Helper  | ❌          | ❌            | ❌            | ❌            |

*Children can only view events where they are listed as attendees

---

## Event Categories

Valid event categories:
- `school`: School-related events (classes, meetings)
- `sport`: Sports activities and practices
- `appointment`: Medical, dental, or other appointments
- `family`: Family activities and gatherings
- `other`: Other event types

---

## AI Planner Integration

The calendar API includes a helper function for AI planner integration:

### `get_busy_hours(user_id, date, db_session)`

Returns list of busy time slots for a user on a given date.

**Usage:**
```python
from routers.calendar import get_busy_hours
from datetime import datetime

busy_hours = get_busy_hours(user_id, datetime(2025, 11, 17), db_session)
# Returns: [(start_datetime, end_datetime), ...]
```

This function is used by the AI planner to avoid scheduling tasks during calendar events.

---

## Performance Considerations

### Response Times
- Single event operations: < 100ms
- Month view (with expansion): < 500ms
- List events (with filters): < 200ms

### Limits
- Maximum occurrences per recurring event: 365 (safety limit)
- Maximum results per list request: 1000
- Date range expansion: Up to 1 year ahead

---

## Error Responses

All error responses follow this format:
```json
{
  "detail": "Error message describing what went wrong"
}
```

Common HTTP status codes:
- `200`: Success
- `400`: Bad Request (validation error)
- `403`: Forbidden (insufficient permissions)
- `404`: Not Found (event or user not found)
- `500`: Internal Server Error

---

## Example Usage Scenarios

### Scenario 1: Create Weekly Recurring Event
```bash
curl -X POST https://api.famquest.app/calendar \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Piano Lessons",
    "description": "Weekly piano practice",
    "start": "2025-11-17T16:00:00Z",
    "end": "2025-11-17T17:00:00Z",
    "allDay": false,
    "attendees": ["child-user-id"],
    "rrule": "FREQ=WEEKLY;BYDAY=TU",
    "category": "other"
  }'
```

### Scenario 2: Get Events for Specific User in Date Range
```bash
curl -X GET "https://api.famquest.app/calendar?userId=user-id&start_date=2025-11-17T00:00:00Z&end_date=2025-11-24T23:59:59Z" \
  -H "Authorization: Bearer <token>"
```

### Scenario 3: Get Month View
```bash
curl -X GET "https://api.famquest.app/calendar/calendar/2025/11" \
  -H "Authorization: Bearer <token>"
```

### Scenario 4: Filter Events by Category
```bash
curl -X GET "https://api.famquest.app/calendar?category=sport" \
  -H "Authorization: Bearer <token>"
```

---

## Implementation Details

### Technologies Used
- **FastAPI**: Web framework
- **SQLAlchemy**: ORM for database operations
- **python-dateutil**: RRULE parsing and expansion
- **pytz**: Timezone handling
- **Pydantic**: Request/response validation

### Database Schema
Events are stored in the `events` table with the following indexed fields:
- `familyId` + `start` (composite index)
- `familyId` + `category` (composite index)

### Recurring Event Expansion
Recurring events are stored as a single database record with an RRULE string. When querying:
1. Base event is retrieved from database
2. RRULE is parsed using python-dateutil
3. Occurrences are generated for the requested date range
4. Each occurrence gets a unique ID: `{event_id}_{occurrence_date}`

### Security
- JWT authentication required for all endpoints
- Role-based access control enforced at API level
- Family isolation (users can only access their family's events)
- Input validation for RRULE format
- Attendee validation (must be family members)

---

## Testing

Comprehensive test suite with 20+ tests covering:
- CRUD operations
- Recurring event expansion (daily, weekly, monthly)
- Access control per role
- Filtering and pagination
- Month and week views
- RRULE validation
- Attendee validation
- Edge cases

Run tests:
```bash
cd backend
pytest tests/test_calendar.py -v
```

---

## Future Enhancements (Phase 2)

Planned features for future releases:
- **Single Occurrence Updates**: Modify single occurrence of recurring event
- **Event Exceptions**: Exclude specific dates from recurrence
- **ICS Export**: Export events to .ics file format
- **Google Calendar Sync**: Read-only sync with Google Calendar
- **Conflict Detection**: Warn about overlapping events
- **Reminders**: Configurable event reminders
- **Timezone Support**: Store and display events in family timezone

---

## Support

For API support or bug reports:
- Email: support@famquest.app
- Documentation: https://docs.famquest.app
- GitHub: https://github.com/famquest/backend

---

**Version:** 1.0.0
**Last Updated:** November 11, 2025
**Maintainer:** FamQuest Backend Team
