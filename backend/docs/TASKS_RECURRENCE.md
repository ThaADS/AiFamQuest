# Task Recurrence and Fairness Engine Documentation

**Version**: 1.0
**Date**: 2025-11-11
**Status**: Production-ready

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [RRULE Format](#rrule-format)
4. [Rotation Strategies](#rotation-strategies)
5. [Fairness Algorithm](#fairness-algorithm)
6. [API Endpoints](#api-endpoints)
7. [Usage Examples](#usage-examples)
8. [Integration with Calendar](#integration-with-calendar)
9. [Testing](#testing)
10. [Performance](#performance)

---

## Overview

The Task Recurrence and Fairness Engine provides intelligent task distribution and scheduling for families. It supports:

- **Recurring tasks** using RRULE (iCalendar RFC 5545)
- **Automatic rotation** with 4 strategies (round-robin, fairness, random, manual)
- **Fairness-based workload balancing** considering age, capacity, and calendar availability
- **Calendar integration** for conflict detection
- **Occurrence management** (skip, complete series, generate instances)

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                      Task Router                            │
│  routers/tasks.py - REST API endpoints                      │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
┌───────▼──────────┐ ┌────▼─────────────────────────────────┐
│ Task Generator   │ │      Fairness Engine                 │
│ Services/        │ │      core/fairness.py                │
│ task_generator.py│ │                                      │
│                  │ │  - Workload calculation              │
│ - RRULE expansion│ │  - Capacity management               │
│ - Instance gen   │ │  - Rotation strategies               │
│ - Duplicate check│ │  - Calendar integration              │
└──────────────────┘ └──────────────────────────────────────┘
```

### Data Flow

1. **Parent creates recurring task** → Task template stored with RRULE
2. **Weekly generation job** → Task Generator expands RRULE for week
3. **For each occurrence** → Fairness Engine determines assignee
4. **Task instance created** → Child sees task with specific due date
5. **TaskLog tracks generation** → Prevents duplicates

---

## RRULE Format

### Supported Frequencies

| Frequency | RRULE | Description |
|-----------|-------|-------------|
| Daily | `FREQ=DAILY` | Every day |
| Daily (weekdays) | `FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR` | Monday-Friday only |
| Weekly | `FREQ=WEEKLY` | Once per week |
| Weekly (specific days) | `FREQ=WEEKLY;BYDAY=MO,WE,FR` | Monday, Wednesday, Friday |
| Bi-weekly | `FREQ=WEEKLY;INTERVAL=2` | Every 2 weeks |
| Monthly | `FREQ=MONTHLY` | Once per month |
| Monthly (specific day) | `FREQ=MONTHLY;BYMONTHDAY=1` | First day of month |
| Monthly (day of week) | `FREQ=MONTHLY;BYDAY=1MO` | First Monday of month |

### Examples

**Daily homework (weekdays only)**:
```
FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR
```

**Weekly room cleaning (Saturday)**:
```
FREQ=WEEKLY;BYDAY=SA
```

**Bi-weekly lawn mowing**:
```
FREQ=WEEKLY;INTERVAL=2;BYDAY=SA
```

**Monthly allowance (1st of month)**:
```
FREQ=MONTHLY;BYMONTHDAY=1
```

---

## Rotation Strategies

### 1. Round Robin (`round_robin`)

**Behavior**: Cycles through assignees sequentially.

**Use Case**: Fair distribution when all users have equal capacity and availability.

**Example**:
```python
# Assignees: [teen_id, child_id]
# Week 1: teen
# Week 2: child
# Week 3: teen
# Week 4: child
```

**State Management**: Tracks current index in `rotationState.index`.

---

### 2. Fairness (`fairness`)

**Behavior**: Assigns to user with lowest workload percentage.

**Algorithm**:
1. Calculate workload for each eligible user
2. Filter out users at/over capacity (>90%)
3. Check calendar availability for task due date
4. Select user with lowest workload score

**Use Case**: Optimal when users have different capacities or busy schedules.

**Example**:
```python
# Teen: 120 min used / 240 min capacity = 50%
# Child: 30 min used / 120 min capacity = 25%
# → Assigns to child (lower %)
```

---

### 3. Random (`random`)

**Behavior**: Randomly selects from eligible assignees.

**Use Case**: When fairness is less critical, or to add variety.

**Example**:
```python
# Assignees: [teen_id, child_id]
# Each occurrence randomly assigned
```

---

### 4. Manual (`manual`)

**Behavior**: Does not auto-assign. Parent must manually assign each occurrence.

**Use Case**: Tasks requiring custom judgment or varying complexity.

**API Response**: `assignee: null` in generated instances.

---

## Fairness Algorithm

### Workload Calculation

**Formula**:
```python
workload_percentage = (task_minutes + busy_minutes) / capacity_minutes
```

**Capacity by Role**:
- Child (6-10 years): 120 minutes/week (2 hours)
- Teen (11-17 years): 240 minutes/week (4 hours)
- Parent: 360 minutes/week (6 hours)
- Helper: 0 (excluded from fairness calculations)

**Factors Considered**:
1. **Task duration**: Sum of `estDuration` for all open tasks in week
2. **Calendar busy hours**: Events where user is attendee
3. **Age/role capacity**: Adjusted for user's age group
4. **Availability gaps**: Preferred after-school hours (16:00-20:00)

### Example Calculation

**Child (120 min capacity)**:
- Open tasks: 3 × 20 min = 60 min
- Calendar events: 2 × 15 min = 30 min
- Total: 90 min
- Workload: 90 / 120 = **75%**

**Teen (240 min capacity)**:
- Open tasks: 5 × 30 min = 150 min
- Calendar events: 4 × 20 min = 80 min
- Total: 230 min
- Workload: 230 / 240 = **96%** (at capacity)

**Result**: Fairness engine assigns next task to **child** (75% < 96%).

---

## API Endpoints

### 1. Create Recurring Task

**Endpoint**: `POST /api/tasks`

**Request Body**:
```json
{
  "title": "Daily Homework",
  "desc": "Complete homework every weekday",
  "category": "homework",
  "due": "2025-11-11T18:00:00Z",
  "rrule": "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
  "rotationStrategy": "fairness",
  "assignees": ["teen_id", "child_id"],
  "points": 10,
  "estDuration": 30,
  "priority": "med",
  "photoRequired": false,
  "parentApproval": false
}
```

**Response**: Task template object with `rrule` set.

---

### 2. List Recurring Tasks

**Endpoint**: `GET /api/tasks/recurring`

**Response**:
```json
[
  {
    "id": "task_123",
    "title": "Daily Homework",
    "rrule": "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
    "rotationStrategy": "fairness",
    "assignees": ["teen_id", "child_id"],
    "status": "open"
  }
]
```

---

### 3. Get Task Occurrences

**Endpoint**: `GET /api/tasks/occurrences?start=2025-11-11&end=2025-11-18`

**Query Parameters**:
- `start` (required): Start date (YYYY-MM-DD)
- `end` (required): End date (YYYY-MM-DD)

**Response**:
```json
[
  {
    "occurrence_date": "2025-11-11",
    "is_generated": true,
    "is_skipped": false,
    "instance_id": "task_inst_456",
    "status": "open",
    "assignee_id": "teen_id"
  },
  {
    "occurrence_date": "2025-11-12",
    "is_generated": false,
    "is_skipped": false,
    "instance_id": null,
    "status": "pending",
    "assignee_id": null
  }
]
```

---

### 4. Generate Week Tasks

**Endpoint**: `POST /api/tasks/generate-week?week_start=2025-11-11`

**Auth**: Parent only

**Response**:
```json
{
  "status": "generated",
  "week_start": "2025-11-11",
  "week_end": "2025-11-18",
  "count": 15,
  "task_ids": ["task_inst_1", "task_inst_2", ...]
}
```

**Process**:
1. Fetches all recurring task templates
2. Expands RRULE for week (max 365 occurrences)
3. For each occurrence:
   - Checks if already generated (TaskLog)
   - Checks if skipped
   - Applies rotation strategy
   - Creates task instance with assignee

---

### 5. Skip Occurrence

**Endpoint**: `POST /api/tasks/{task_id}/skip-occurrence?occurrence_date=2025-11-12`

**Auth**: Parent only

**Response**:
```json
{
  "status": "skipped",
  "task_id": "task_123",
  "occurrence_date": "2025-11-12"
}
```

**Use Case**: Parent knows family will be on vacation, skip homework for that day.

---

### 6. Complete Series

**Endpoint**: `POST /api/tasks/{task_id}/complete-series`

**Auth**: Parent only

**Response**:
```json
{
  "status": "completed",
  "task_id": "task_123"
}
```

**Effect**: Marks template as `status: "done"`, stops future occurrence generation.

---

### 7. Rotate Assignee Manually

**Endpoint**: `POST /api/tasks/{task_id}/rotate-assignee`

**Auth**: Parent only

**Response**:
```json
{
  "status": "rotated",
  "task_id": "task_123",
  "next_assignee": "child_id",
  "occurrence_date": "2025-11-12",
  "strategy": "fairness"
}
```

**Use Case**: Preview who will get next occurrence or force rotation.

---

### 8. Fairness Report

**Endpoint**: `GET /api/tasks/fairness?week_start=2025-11-11`

**Auth**: Parent only

**Response**:
```json
{
  "fairness_scores": {
    "teen_id": 0.48,
    "child_id": 0.32,
    "parent_id": 0.65
  },
  "week_start": "2025-11-11",
  "week_end": "2025-11-18",
  "over_capacity": [],
  "under_capacity": ["child_id"],
  "recommendations": [
    {
      "type": "suggestion",
      "message": "Child is under-utilized at 32% capacity",
      "action": "Consider assigning more tasks or increasing task complexity"
    }
  ]
}
```

---

## Usage Examples

### Example 1: Daily Homework with Fairness

**Parent Setup**:
1. Create recurring task with `rotationStrategy: "fairness"`
2. Add teen and child as eligible assignees
3. Set RRULE: `FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR`

**System Behavior**:
- Each Sunday night, cron job generates homework tasks for the week
- Fairness engine checks teen and child workload
- Assigns Monday's homework to child (lower workload)
- Assigns Tuesday's homework to teen (now lower workload)
- Continues balancing throughout week

**Parent Dashboard**:
- Views fairness report
- Sees workload distribution (teen: 52%, child: 38%)
- No action needed (system auto-balances)

---

### Example 2: Weekly Chores with Round-Robin

**Parent Setup**:
1. Create "Saturday Room Cleaning" task
2. Set `rotationStrategy: "round_robin"`
3. Add all children as assignees
4. Set RRULE: `FREQ=WEEKLY;BYDAY=SA`

**System Behavior**:
- Week 1: Child A cleans room
- Week 2: Child B cleans room
- Week 3: Child C cleans room
- Week 4: Child A (cycle repeats)

**Predictability**: Children know their schedule weeks in advance.

---

### Example 3: Vacation Handling

**Scenario**: Family on vacation Nov 15-20, skip all tasks.

**Parent Actions**:
1. View recurring tasks
2. For each task:
   - Call `POST /tasks/{id}/skip-occurrence?occurrence_date=2025-11-15`
   - Call `POST /tasks/{id}/skip-occurrence?occurrence_date=2025-11-16`
   - Repeat for all vacation dates

**System Behavior**:
- Skipped occurrences not generated
- TaskLog tracks skips with reason
- Resume normal generation after vacation

---

## Integration with Calendar

### Conflict Detection

**Scenario**: Child has soccer practice 17:00-18:30.

**Task**: Homework due at 18:00.

**Fairness Engine Check**:
1. Queries calendar for child's events
2. Finds soccer practice conflict
3. Calculates available gaps (before 17:00 or after 18:30)
4. If insufficient time before practice:
   - Assigns to other sibling
   - Or suggests time shift to parent

### Busy Hours Calculation

**Process**:
1. Fetch all events where user is attendee
2. Expand recurring events for week
3. Sum duration in minutes
4. Add to task workload calculation

**Example**:
- Child has 3 events: school (7 hrs), sports (2 hrs), music (1 hr)
- Total busy hours: 600 minutes
- Adds to weekly workload (on top of task durations)

---

## Testing

### Test Coverage

**Location**: `backend/tests/test_tasks_recurrence.py`

**Test Categories**:
1. **RRULE Validation**: Daily, weekly, monthly, invalid formats
2. **RRULE Expansion**: Correct occurrence dates, max limits, weekday filtering
3. **Rotation Strategies**: Round-robin sequence, fairness selection, random variation, manual null
4. **Fairness Engine**: Workload calculation, capacity limits, distribution analysis
5. **Task Generation**: Instance creation, duplicate prevention, rotation application
6. **Occurrence Management**: Skip, complete series, status tracking
7. **Edge Cases**: No assignees, all at capacity, equal workload

**Test Count**: 25+ comprehensive tests

### Running Tests

```bash
# Run all recurrence tests
pytest backend/tests/test_tasks_recurrence.py -v

# Run specific test category
pytest backend/tests/test_tasks_recurrence.py::test_rotation_fairness_least_loaded -v

# Run with coverage
pytest backend/tests/test_tasks_recurrence.py --cov=services.task_generator --cov=core.fairness
```

**Expected Coverage**: 90%+ for task_generator.py and fairness.py

---

## Performance

### Benchmarks

**Task Generation** (100 tasks, 1 week):
- RRULE expansion: <50ms
- Fairness calculation: <20ms per user
- Instance creation: <100ms total
- **Total**: <200ms for weekly generation

**Fairness Report** (family of 5, 1 week):
- Workload calculation: <30ms
- Calendar busy hours: <50ms
- Distribution analysis: <10ms
- **Total**: <100ms for dashboard view

### Optimization Strategies

1. **Batch generation**: Process all templates in single transaction
2. **TaskLog indexing**: Fast duplicate check via `(taskId, action, occurrence_date)` composite index
3. **Calendar caching**: Cache recurring event expansion for week
4. **Lazy loading**: Generate only when requested (no background jobs initially)

### Scaling Considerations

**Current limits**:
- Max 365 occurrences per expansion (1 year)
- Weekly generation window (prevents unbounded growth)
- TaskLog cleanup after 90 days (archive old generations)

**Future optimizations** (if needed):
- Materialize next 4 weeks of occurrences
- Background worker for generation (Celery)
- Redis cache for fairness scores

---

## Best Practices

### For Parents

1. **Review fairness report weekly** - Ensure balanced workload
2. **Skip occurrences proactively** - Mark vacations, sick days
3. **Adjust rotation strategy** - Switch if one isn't working
4. **Set realistic durations** - Accurate `estDuration` improves fairness

### For Developers

1. **Always validate RRULE** - Use `validate_rrule()` before saving
2. **Limit max occurrences** - Prevent infinite loops (max 365)
3. **Check duplicates** - Use TaskLog before generating instances
4. **Handle edge cases** - No assignees, all at capacity, manual strategy
5. **Test rotation logic** - Verify each strategy works as expected

### For System Administrators

1. **Monitor TaskLog growth** - Archive or delete old entries
2. **Set up weekly cron job** - Generate tasks for upcoming week
3. **Alert on failures** - Generation errors should notify admins
4. **Backup rotation state** - rotationState JSONB field is critical

---

## Troubleshooting

### Issue: Tasks not generating

**Check**:
1. Template status is `open` (not `done`)
2. RRULE is valid (test with `validate_rrule()`)
3. No TaskLog entries blocking generation
4. Assignees list is not empty
5. Cron job is running weekly

**Fix**: Manually trigger `POST /api/tasks/generate-week`

---

### Issue: Unfair distribution

**Symptoms**: One child gets all tasks, others get none.

**Causes**:
1. Rotation strategy is `manual` (parent must assign)
2. One child is only eligible assignee
3. Capacity misconfigured (check role)

**Fix**:
- Switch to `fairness` strategy
- Verify multiple eligible assignees
- Check fairness report for workload

---

### Issue: Duplicate tasks generated

**Causes**:
1. TaskLog not checked before generation
2. Multiple parallel generation calls

**Fix**:
- Ensure TaskLog checks in `_is_occurrence_generated()`
- Use database transaction locks for generation

---

## Future Enhancements

### Planned (Phase 3)

1. **AI-powered rotation** - Learn from completion patterns
2. **Conflict resolution UI** - Visual calendar + task overlay
3. **Predictive workload** - Forecast busy weeks, suggest adjustments
4. **Task swapping** - Children can trade tasks (parent approval)
5. **Streaks integration** - Bonus points for consecutive completions

### Under Consideration

1. **Multi-family templates** - Share recurring task templates
2. **Seasonal adjustments** - Adjust capacity during school breaks
3. **Skill-based assignment** - Match task complexity to child ability
4. **Weather integration** - Skip outdoor tasks on rainy days

---

## Related Documentation

- [Database Schema](database_schema.md) - Task and TaskLog tables
- [Calendar API](CALENDAR_API.md) - Event and busy hours integration
- [Gamification](gamification.md) - Points and streak integration
- [API Reference](api_reference.md) - Complete endpoint documentation

---

**Last Updated**: 2025-11-11
**Maintained By**: FamQuest Backend Team
**Questions**: backend@famquest.app
