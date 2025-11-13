# FamQuest Database Schema Documentation

**Version:** 2.0 (Complete MVP Schema)
**Database:** PostgreSQL 15+
**ORM:** SQLAlchemy 2.0 with Mapped types
**Migration Tool:** Alembic
**Last Updated:** 2025-11-11

---

## Overview

The FamQuest database schema consists of **16 tables** designed to support the MVP feature set:

- **Family Management**: Family grouping and user roles
- **Calendar**: Events with recurrence support
- **Task Management**: Tasks with rotation, claiming, and approval workflows
- **Gamification**: Points, badges, streaks, and rewards
- **Homework Coach**: Study items and sessions with AI-generated plans
- **Media Storage**: Photo metadata for task proofs and vision tips
- **Notifications**: Push, email, and in-app notification queue
- **Audit**: Comprehensive activity logging

---

## Entity Relationship Diagram

```mermaid
erDiagram
    FAMILY ||--o{ USER : has
    FAMILY ||--o{ TASK : has
    FAMILY ||--o{ EVENT : has
    FAMILY ||--o{ REWARD : has
    FAMILY ||--o{ MEDIA : has

    USER ||--o{ POINTS_LEDGER : earns
    USER ||--o{ BADGE : earns
    USER ||--o{ USER_STREAK : tracks
    USER ||--o{ STUDY_ITEM : has
    USER ||--o{ DEVICE_TOKEN : registers
    USER ||--o{ WEBPUSH_SUB : subscribes
    USER ||--o{ NOTIFICATION : receives
    USER ||--o{ AUDIT_LOG : creates

    TASK ||--o{ TASK_LOG : records

    STUDY_ITEM ||--o{ STUDY_SESSION : schedules

    FAMILY {
        string id PK
        string name
        datetime createdAt
        datetime updatedAt
    }

    USER {
        string id PK
        string familyId FK
        string email UK
        string displayName
        string role
        string avatar
        string passwordHash
        string locale
        string theme
        boolean emailVerified
        boolean twoFAEnabled
        string twoFASecret
        string pin
        jsonb permissions
        jsonb sso
        datetime createdAt
        datetime updatedAt
    }

    EVENT {
        string id PK
        string familyId FK
        string title
        text description
        datetime start
        datetime end
        boolean allDay
        array attendees
        string color
        string rrule
        string category
        string createdBy FK
        datetime createdAt
        datetime updatedAt
    }

    TASK {
        string id PK
        string familyId FK
        string title
        text desc
        string category
        datetime due
        string frequency
        string rrule
        array assignees
        boolean claimable
        string claimedBy
        datetime claimedAt
        string status
        integer points
        boolean photoRequired
        boolean parentApproval
        array proofPhotos
        string priority
        integer estDuration
        string createdBy FK
        string completedBy
        datetime completedAt
        integer version
        datetime createdAt
        datetime updatedAt
    }

    TASK_LOG {
        string id PK
        string taskId FK
        string userId FK
        string action
        jsonb metadata
        datetime createdAt
    }

    POINTS_LEDGER {
        string id PK
        string userId FK
        integer delta
        string reason
        string taskId
        string rewardId
        datetime createdAt
    }

    BADGE {
        string id PK
        string userId FK
        string code
        datetime awardedAt
    }

    USER_STREAK {
        string id PK
        string userId FK UK
        integer currentStreak
        integer longestStreak
        datetime lastCompletionDate
        datetime updatedAt
    }

    REWARD {
        string id PK
        string familyId FK
        string name
        text description
        integer cost
        string icon
        boolean isActive
        datetime createdAt
    }

    STUDY_ITEM {
        string id PK
        string userId FK
        string subject
        string topic
        datetime testDate
        jsonb studyPlan
        string status
        datetime createdAt
        datetime updatedAt
    }

    STUDY_SESSION {
        string id PK
        string studyItemId FK
        datetime scheduledDate
        datetime completedAt
        jsonb quizQuestions
        integer score
    }

    MEDIA {
        string id PK
        string familyId FK
        string uploadedBy FK
        string url
        string storageKey
        string mimeType
        integer sizeBytes
        string avScanStatus
        string context
        string contextId
        datetime expiresAt
        datetime createdAt
    }

    NOTIFICATION {
        string id PK
        string userId FK
        string type
        string title
        text body
        jsonb payload
        string status
        datetime sentAt
        datetime readAt
        datetime scheduledFor
        datetime createdAt
    }
```

---

## Table Definitions

### 1. families

**Purpose:** Top-level grouping for all family members and their data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| name | String | NOT NULL | Family display name |
| createdAt | DateTime | NOT NULL, Default: now() | Family creation timestamp |
| updatedAt | DateTime | NOT NULL, Default: now() | Last update timestamp |

**Relationships:**
- One-to-many: users, tasks, events, rewards

**Indexes:** None (small table)

---

### 2. users

**Purpose:** User accounts with role-based access control (parent/teen/child/helper).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| familyId | String | FK → families.id, Index | Family membership |
| email | String | UNIQUE, Index | Email address |
| displayName | String | NOT NULL | Display name |
| role | String | Default: 'child' | parent\|teen\|child\|helper |
| avatar | String | Nullable | Avatar URL or preset code |
| passwordHash | String | Nullable | Bcrypt hash (null for child with PIN) |
| locale | String | Default: 'nl' | nl\|en\|de\|fr\|tr\|pl\|ar |
| theme | String | Default: 'minimal' | cartoony\|minimal\|classy\|dark |
| emailVerified | Boolean | Default: false | Email verification status |
| twoFAEnabled | Boolean | Default: false | 2FA enabled flag |
| twoFASecret | String | Nullable | TOTP secret (Base32) |
| pin | String | Nullable | Child account PIN (hashed) |
| permissions | JSONB | Default: {} | Granular permission toggles |
| sso | JSONB | Default: {} | SSO provider metadata |
| createdAt | DateTime | NOT NULL, Index | Account creation |
| updatedAt | DateTime | NOT NULL | Last update |

**Permissions JSONB Example:**
```json
{
  "childCanCreateTasks": true,
  "childCanCreateStudyItems": true
}
```

**SSO JSONB Example:**
```json
{
  "providers": ["google", "apple"],
  "google_id": "123456789",
  "apple_id": "000123.abc456def.1234"
}
```

**Indexes:**
- `idx_user_family_role` (familyId, role) - Filter users by role
- `idx_user_email_verified` (email, emailVerified) - SSO lookup

---

### 3. events

**Purpose:** Calendar events (appointments, school events, family activities).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| familyId | String | FK → families.id, Index | Family ownership |
| title | String | NOT NULL | Event title |
| description | Text | Default: '' | Event details |
| start | DateTime | NOT NULL, Index | Start date/time (UTC) |
| end | DateTime | Nullable | End date/time (null for untimed) |
| allDay | Boolean | Default: false | All-day event flag |
| attendees | String[] | Default: [] | Array of user IDs |
| color | String | Nullable | Hex color (#RRGGBB) |
| rrule | String | Nullable | Recurrence rule (RFC 5545) |
| category | String | Default: 'other' | school\|sport\|appointment\|family\|other |
| createdBy | String | FK → users.id | Creator user ID |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| updatedAt | DateTime | NOT NULL | Last update |

**Indexes:**
- `idx_event_family_start` (familyId, start) - Calendar range queries
- `idx_event_family_category` (familyId, category) - Filter by type

**RRULE Example:**
```
FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=10
```

---

### 4. tasks

**Purpose:** Chore tasks with recurrence, rotation, claiming, and approval workflows.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| familyId | String | FK → families.id, Index | Family ownership |
| title | String | NOT NULL | Task title |
| desc | Text | Default: '' | Task description |
| category | String | Default: 'other' | cleaning\|care\|pet\|homework\|other |
| due | DateTime | Nullable, Index | Due date/time (UTC) |
| frequency | String | Default: 'none' | none\|daily\|weekly\|custom |
| rrule | String | Nullable | Recurrence rule (RFC 5545) |
| assignees | String[] | Default: [] | Array of user IDs |
| claimable | Boolean | Default: false | Task can be claimed from pool |
| claimedBy | String | Nullable | User ID who claimed (TTL 10min) |
| claimedAt | DateTime | Nullable | Claim timestamp |
| status | String | Default: 'open', Index | open\|pendingApproval\|done |
| points | Integer | Default: 10 | Points awarded on completion |
| photoRequired | Boolean | Default: false | Photo proof required |
| parentApproval | Boolean | Default: false | Parent review required |
| proofPhotos | String[] | Default: [] | Array of photo URLs |
| priority | String | Default: 'med' | low\|med\|high |
| estDuration | Integer | Default: 15 | Estimated minutes |
| createdBy | String | FK → users.id | Creator user ID |
| completedBy | String | Nullable | User ID who completed |
| completedAt | DateTime | Nullable | Completion timestamp |
| version | Integer | Default: 0 | Optimistic locking version |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| updatedAt | DateTime | NOT NULL, Index | Last update |

**Indexes:**
- `idx_task_family_status` (familyId, status) - Filter by status
- `idx_task_family_due` (familyId, due) - Sort by due date
- `idx_task_claimable` (familyId, claimable, status) - Claimable pool

---

### 5. task_logs

**Purpose:** Audit trail for task completions, approvals, and changes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| taskId | String | FK → tasks.id, Index | Task reference |
| userId | String | FK → users.id | Actor user ID |
| action | String | NOT NULL | completed\|approved\|rejected\|reassigned |
| metadata | JSONB | Default: {} | Action-specific data |
| createdAt | DateTime | NOT NULL, Index | Action timestamp |

**Metadata JSONB Example:**
```json
{
  "photos": ["https://cdn/photo1.jpg"],
  "rating": 4,
  "comment": "Good job!"
}
```

---

### 6. points_ledger

**Purpose:** Points transaction log for gamification economy.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, Index | User earning/spending points |
| delta | Integer | NOT NULL | Points change (+/- value) |
| reason | String | Default: '' | Human-readable reason |
| taskId | String | Nullable | Task reference (if earned from task) |
| rewardId | String | Nullable | Reward reference (if spent on reward) |
| createdAt | DateTime | NOT NULL, Index | Transaction timestamp |

**Index:**
- `idx_points_user_created` (userId, createdAt) - Calculate user balance

**Query Example (User Balance):**
```sql
SELECT SUM(delta) AS balance
FROM points_ledger
WHERE userId = 'user_123';
```

---

### 7. badges

**Purpose:** Achievement badges earned by users.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, Index | Badge owner |
| code | String | NOT NULL | Badge type code |
| awardedAt | DateTime | NOT NULL | Award timestamp |

**Index:**
- `idx_badge_user_code` (userId, code) - Prevent duplicate badges

**Badge Codes (Examples):**
- `first_task_complete`
- `week_streak_7`
- `month_streak_30`
- `super_cleaner` (10 cleaning tasks)

---

### 8. user_streaks

**Purpose:** Daily completion streaks for gamification.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, UNIQUE, Index | One streak per user |
| currentStreak | Integer | Default: 0 | Current consecutive days |
| longestStreak | Integer | Default: 0 | All-time best streak |
| lastCompletionDate | DateTime | Nullable | Last task completion date (date only) |
| updatedAt | DateTime | NOT NULL | Last streak update |

**Streak Logic:**
- Complete task → increment currentStreak if date = today
- Missed day → reset currentStreak to 0
- Update longestStreak if currentStreak > longestStreak

---

### 9. rewards

**Purpose:** Reward shop items redeemable with points.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| familyId | String | FK → families.id, Index | Family-specific rewards |
| name | String | NOT NULL | Reward name |
| description | Text | Default: '' | Reward details |
| cost | Integer | Default: 100 | Points required |
| icon | String | Nullable | Icon URL or code |
| isActive | Boolean | Default: true | Reward available flag |
| createdAt | DateTime | NOT NULL | Creation timestamp |

---

### 10. study_items

**Purpose:** Homework/study topics for the Homework Coach feature.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, Index | Student user ID |
| subject | String | NOT NULL | Subject (Math, History, etc.) |
| topic | String | NOT NULL | Specific topic |
| testDate | DateTime | Nullable, Index | Test/exam date |
| studyPlan | JSONB | Default: {} | AI-generated study sessions |
| status | String | Default: 'active' | active\|completed\|cancelled |
| createdAt | DateTime | NOT NULL | Creation timestamp |
| updatedAt | DateTime | NOT NULL | Last update |

**StudyPlan JSONB Example:**
```json
{
  "sessions": [
    {
      "date": "2025-11-12T18:00:00Z",
      "duration": 30,
      "topics": ["algebra", "equations"]
    },
    {
      "date": "2025-11-14T18:00:00Z",
      "duration": 30,
      "topics": ["practice problems"]
    }
  ]
}
```

---

### 11. study_sessions

**Purpose:** Individual study sessions (20-30min blocks) with quiz results.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| studyItemId | String | FK → study_items.id, Index | Parent study item |
| scheduledDate | DateTime | NOT NULL, Index | Scheduled session date/time |
| completedAt | DateTime | Nullable | Completion timestamp |
| quizQuestions | JSONB | Default: {} | Micro-quiz questions + answers |
| score | Integer | Nullable | Quiz score (0-100%) |

**QuizQuestions JSONB Example:**
```json
{
  "questions": [
    {
      "q": "What is 2 + 2?",
      "a": "4",
      "correct": true
    },
    {
      "q": "Solve: 3x = 9",
      "a": "x = 3",
      "correct": true
    }
  ]
}
```

---

### 12. media

**Purpose:** Media file metadata (photos for task proofs, vision tips, avatars).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| familyId | String | FK → families.id, Index | Family ownership |
| uploadedBy | String | FK → users.id | Uploader user ID |
| url | String | NOT NULL | Presigned or permanent URL |
| storageKey | String | NOT NULL | S3 key or storage path |
| mimeType | String | NOT NULL | MIME type (image/jpeg, etc.) |
| sizeBytes | Integer | NOT NULL | File size in bytes |
| avScanStatus | String | Default: 'pending' | pending\|clean\|infected |
| context | String | NOT NULL | task_proof\|vision_tip\|avatar |
| contextId | String | Nullable | Task ID, etc. |
| expiresAt | DateTime | Nullable | Expiration date (auto-delete) |
| createdAt | DateTime | NOT NULL, Index | Upload timestamp |

**Indexes:**
- `idx_media_family_context` (familyId, context) - Filter by type
- `idx_media_expires` (expiresAt) - Cleanup expired files

---

### 13. notifications

**Purpose:** Notification queue for push, email, and in-app notifications.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, Index | Recipient user ID |
| type | String | NOT NULL | push\|email\|in_app |
| title | String | NOT NULL | Notification title |
| body | Text | NOT NULL | Notification body |
| payload | JSONB | Default: {} | Deep link data |
| status | String | Default: 'pending' | pending\|sent\|failed |
| sentAt | DateTime | Nullable | Send timestamp |
| readAt | DateTime | Nullable | Read timestamp (in-app only) |
| scheduledFor | DateTime | Nullable, Index | Scheduled send time |
| createdAt | DateTime | NOT NULL | Creation timestamp |

**Indexes:**
- `idx_notification_user_status` (userId, status) - Filter by status
- `idx_notification_scheduled` (scheduledFor, status) - Scheduler query

**Payload JSONB Example:**
```json
{
  "taskId": "task_123",
  "route": "/tasks/123",
  "action": "open_task"
}
```

---

### 14. device_tokens

**Purpose:** Push notification device tokens (FCM/APNs).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, Index | Device owner |
| platform | String | NOT NULL | ios\|android\|web |
| token | String | NOT NULL, UNIQUE | FCM/APNs token |
| createdAt | DateTime | NOT NULL | Registration timestamp |

---

### 15. webpush_subs

**Purpose:** Web Push subscription data (VAPID).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| userId | String | FK → users.id, Index | Subscriber user ID |
| endpoint | String | NOT NULL | Push service endpoint URL |
| p256dh | String | NOT NULL | Public key (Base64) |
| auth | String | NOT NULL | Auth secret (Base64) |
| createdAt | DateTime | NOT NULL | Subscription timestamp |

---

### 16. audit_log

**Purpose:** Comprehensive activity audit log for compliance and debugging.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | String | PK | UUID primary key |
| actorUserId | String | FK → users.id, Index | User who performed action |
| familyId | String | FK → families.id, Index | Family context |
| action | String | NOT NULL | Action type (task_created, etc.) |
| meta | JSONB | Default: {} | Action-specific metadata |
| createdAt | DateTime | NOT NULL, Index | Action timestamp |

**Indexes:**
- `idx_audit_family_created` (familyId, createdAt) - Family activity timeline
- `idx_audit_actor_action` (actorUserId, action) - User action history

**Meta JSONB Example:**
```json
{
  "taskId": "task_123",
  "title": "Vaatwasser uitruimen",
  "changes": {
    "status": {"from": "open", "to": "done"},
    "completedBy": "user_456"
  }
}
```

---

## Query Optimization

### Hot Query Paths and Indexes

| Query Pattern | Table | Index | Purpose |
|---------------|-------|-------|---------|
| Get family tasks by status | tasks | `idx_task_family_status` | Filter open/pending tasks |
| Get upcoming tasks | tasks | `idx_task_family_due` | Sort by due date |
| Get claimable tasks | tasks | `idx_task_claimable` | Pool of claimable tasks |
| Get calendar events for range | events | `idx_event_family_start` | Month/week view queries |
| Get user points balance | points_ledger | `idx_points_user_created` | SUM(delta) aggregation |
| Get user badges | badges | `idx_badge_user_code` | Prevent duplicates |
| Get pending notifications | notifications | `idx_notification_user_status` | Unread/unsent notifications |
| Get scheduled notifications | notifications | `idx_notification_scheduled` | Cron job scheduler |
| Get family audit trail | audit_log | `idx_audit_family_created` | Activity timeline |

### Performance Targets

- **Family task list**: < 10ms (with indexes)
- **User points calculation**: < 5ms (SUM aggregation)
- **Calendar range query (1 month)**: < 15ms
- **Task completion write**: < 20ms (with task_log insert)

---

## Data Types and Constraints

### UUID Generation
All primary keys use UUIDs (v4) to support distributed systems and prevent ID collisions:

```python
import uuid
id = str(uuid.uuid4())  # '123e4567-e89b-12d3-a456-426614174000'
```

### JSONB Usage
JSONB fields provide schema flexibility without sacrificing query performance:

- **Indexable**: GIN indexes for fast JSONB queries
- **Extensible**: Add fields without migrations
- **Typed**: PostgreSQL validates JSON structure

### Timestamp Best Practices
- **All timestamps in UTC**: Never store local timezone
- **Default to now()**: Use `server_default=sa.func.now()`
- **Auto-update**: Use `onupdate=sa.func.now()` for updatedAt

---

## Migration Strategy

### Alembic Workflow

```bash
# Generate migration (auto-detect changes)
alembic revision --autogenerate -m "description"

# Apply migration
alembic upgrade head

# Rollback migration
alembic downgrade -1

# Show current version
alembic current

# Show migration history
alembic history
```

### Migration Files
- `0001_initial.py` - Base schema (9 tables)
- `0002_complete_mvp_schema.py` - Complete MVP (16 tables + enhancements)

---

## Seed Data

Development seed data script: `backend/scripts/seed_dev_data.py`

**Includes:**
- 2 families (Eva's family + Mark's family)
- 9 users (parents, teens, children, helper)
- 7 tasks (completed, pending approval, open, claimable)
- 4 calendar events
- Points ledger entries
- Badges and streaks
- 4 rewards
- 2 study items with sessions
- Audit logs

**Usage:**
```bash
python scripts/seed_dev_data.py
```

**Test Accounts:**
- Parent (Eva): `eva@famquest.dev` / `famquest123`
- Teen (Sam): `sam@famquest.dev` / `famquest123`
- Child (Noah): PIN `1234`
- Child (Luna): PIN `5678`

---

## Security Considerations

### Data Protection
- **At-rest encryption**: PostgreSQL column encryption for sensitive fields
- **TLS 1.2+**: Encrypted connections only
- **No PII in logs**: Scrub personally identifiable information

### Access Control
- **Row-level security (RLS)**: Family-scoped data isolation
- **Role-based access**: parent/teen/child/helper permissions
- **JSONB permissions**: Granular per-user toggles

### Audit Requirements
- **AVG compliance**: Right to be forgotten, data export
- **COPPA compliance**: Parental consent for child accounts
- **Audit trail**: All sensitive actions logged

---

## Backup and Recovery

### Backup Strategy
- **Daily automated backups**: Full database dump
- **Point-in-time recovery**: WAL archiving enabled
- **Offsite storage**: S3 or equivalent
- **Retention**: 30 days rolling

### Recovery SLA
- **RTO (Recovery Time Objective)**: < 1 hour
- **RPO (Recovery Point Objective)**: < 15 minutes

---

## Monitoring

### Key Metrics
- **Query performance**: p95 latency < 200ms
- **Database size**: Track table growth
- **Index usage**: Monitor unused indexes
- **Connection pool**: Track active/idle connections

### Alerts
- **Slow queries**: > 1 second execution time
- **Failed migrations**: Alembic errors
- **Disk space**: < 20% free space
- **Connection pool exhaustion**: > 90% utilization

---

## Future Enhancements (Post-MVP)

### Phase 2 Tables (Deferred)
- `family_quests`: Team challenges/goals
- `entitlements`: IAP/subscription tracking
- `sso_links`: Multi-provider SSO mappings

### Performance Optimizations
- **Read replicas**: Scale read-heavy queries
- **Partitioning**: Partition large tables (audit_log, points_ledger) by date
- **Materialized views**: Pre-compute complex aggregations

---

## Appendix: SQL Scripts

### Create Database
```sql
CREATE DATABASE famquest
  WITH OWNER = postgres
       ENCODING = 'UTF8'
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8';
```

### Enable Extensions
```sql
-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- JSONB operators
CREATE EXTENSION IF NOT EXISTS "btree_gin";
```

### Sample Queries

**Get user points balance:**
```sql
SELECT u.displayName, SUM(pl.delta) AS points
FROM users u
LEFT JOIN points_ledger pl ON u.id = pl.userId
WHERE u.familyId = 'family_123'
GROUP BY u.id, u.displayName
ORDER BY points DESC;
```

**Get upcoming tasks for family:**
```sql
SELECT t.title, t.due, t.status, t.assignees
FROM tasks t
WHERE t.familyId = 'family_123'
  AND t.status = 'open'
  AND t.due > NOW()
ORDER BY t.due ASC
LIMIT 10;
```

**Get user streak status:**
```sql
SELECT u.displayName, us.currentStreak, us.longestStreak
FROM users u
LEFT JOIN user_streaks us ON u.id = us.userId
WHERE u.familyId = 'family_123'
  AND u.role IN ('child', 'teen')
ORDER BY us.currentStreak DESC;
```

---

**End of Database Schema Documentation**
