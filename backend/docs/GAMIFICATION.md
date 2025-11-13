# FamQuest Gamification System

Complete documentation for the gamification backend logic including streaks, badges, points, and integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Badge System](#badge-system)
3. [Points Economy](#points-economy)
4. [Streak Mechanics](#streak-mechanics)
5. [Integration](#integration)
6. [API Reference](#api-reference)
7. [Examples](#examples)

---

## Overview

The FamQuest gamification system motivates family members through:
- **Points**: Earned from task completion with multipliers
- **Badges**: Achievement milestones for various accomplishments
- **Streaks**: Daily completion chains with bonus multipliers
- **Leaderboards**: Family-wide rankings to encourage friendly competition

### Architecture

```
GamificationService (Orchestrator)
├── StreakService      → Track daily completion chains
├── BadgeService       → Award achievement badges
└── PointsService      → Calculate and manage points economy
```

### Workflow on Task Completion

```
1. Task marked as "done"
2. PointsService calculates points with multipliers
3. StreakService updates daily streak
4. BadgeService checks for new badge conditions
5. Returns complete gamification response to UI
```

---

## Badge System

### Badge Categories

#### 🔥 Streak Badges
Track consecutive days of task completions.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `streak_3` | 3-Day Streak | 🔥 | Complete tasks for 3 consecutive days | All |
| `streak_7` | Week Warrior | ⭐ | Complete tasks for 7 consecutive days | All |
| `streak_14` | Two Week Champion | 🏅 | Complete tasks for 14 consecutive days | Teen, Parent |
| `streak_30` | Monthly Master | 👑 | Complete tasks for 30 consecutive days | Teen, Parent |

#### 🎯 Completion Badges
Progressive task completion milestones.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `first_task` | First Steps | 🎯 | Complete your first task | Child, Teen |
| `tasks_10` | Getting Started | 💪 | Complete 10 tasks | Child, Teen |
| `tasks_25` | Helping Hand | 🌟 | Complete 25 tasks | Child, Teen |
| `tasks_50` | Task Master | 🏆 | Complete 50 tasks | All |
| `tasks_100` | Century Club | 💎 | Complete 100 tasks | Teen, Parent |

#### ⚡ Speed Badges
Reward fast and efficient completion.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `speed_demon` | Speed Demon | ⚡ | Complete task in <50% estimated time | Child, Teen |
| `efficiency_master` | Efficiency Master | 🚀 | Complete 10 tasks faster than estimated | Teen |

#### ✨ Quality Badges
Excellence in task execution.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `first_approval` | Approved! | 👍 | Get your first parental approval | Child, Teen |
| `perfectionist` | Perfectionist | ✨ | Get 5-star approval on 10 tasks | Child, Teen |

#### 🦸 Helper Badges
Teamwork and claiming shared tasks.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `helper_hero` | Helper Hero | 🦸 | Claim and complete a task from shared pool | All |
| `team_player` | Team Player | 🤝 | Claim and complete 10 tasks from shared pool | Teen, Parent |

#### 🌅 Time-Based Badges
Fun milestones for timing.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `early_bird` | Early Bird | 🌅 | Complete task before 08:00 | Child, Teen |
| `night_owl` | Night Owl | 🌙 | Complete task after 20:00 | Teen |

#### 🧹 Category Badges
Specialization in specific task types.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `cleaning_ace` | Cleaning Ace | 🧹 | Complete 20 cleaning tasks | Child, Teen |
| `homework_hero` | Homework Hero | 📚 | Complete 20 homework tasks | Child, Teen |
| `pet_guardian` | Pet Guardian | 🐾 | Complete 20 pet care tasks | Child, Teen |

#### ⏰ Timeliness Badges
Punctuality rewards.

| Code | Name | Icon | Condition | Personas |
|------|------|------|-----------|----------|
| `punctual_pro` | Punctual Pro | ⏰ | Complete 10 tasks before due date | Teen, Parent |

### Badge Logic

**Persona Filtering**: Badges are only checked for users with matching roles (child/teen/parent).

**Condition Evaluation**: Each badge has a condition function that checks user statistics.

**Awarding**: Badges are awarded automatically on task completion if conditions are met.

**Duplicate Prevention**: System prevents awarding the same badge twice.

---

## Points Economy

### Base Points

Each task has a `points` field (default: 10).

### Multipliers

Points are calculated with the following multipliers:

#### Timeliness Multipliers

| Condition | Multiplier | Example |
|-----------|------------|---------|
| Completed before due date | **1.2x** | 10 → 12 points |
| Completed after due date | **0.8x** | 10 → 8 points |

#### Quality Multipliers (Parent Approval)

| Rating | Multiplier | Example |
|--------|------------|---------|
| 5 stars | **1.2x** | 10 → 12 points |
| 4 stars | **1.1x** | 10 → 11 points |
| <4 stars | **1.0x** | No bonus |

#### Streak Multipliers

| Streak Length | Multiplier | Example |
|---------------|------------|---------|
| 30+ days | **1.3x** | 10 → 13 points |
| 14-29 days | **1.2x** | 10 → 12 points |
| 7-13 days | **1.1x** | 10 → 11 points |
| <7 days | **1.0x** | No bonus |

#### Performance Multipliers

| Condition | Multiplier | Example |
|-----------|------------|---------|
| Completed in <50% estimated time | **1.15x** | 10 → 11.5 points |
| Completed in <75% estimated time | **1.05x** | 10 → 10.5 points |
| Photo proof provided | **1.05x** | 10 → 10.5 points |
| Claimed from shared pool | **1.1x** | 10 → 11 points |

### Stacking Multipliers

All applicable multipliers are stacked multiplicatively.

**Example**: Task with 10 base points
- On-time: 1.2x
- 7-day streak: 1.1x
- 5-star approval: 1.2x
- **Total**: 10 × 1.2 × 1.1 × 1.2 = **15.84 points** → 15 points (rounded down)

### Points Ledger

All points transactions are recorded in `PointsLedger`:
- `delta`: Points awarded (positive) or spent (negative)
- `reason`: Human-readable description
- `taskId`: Task that earned points (if applicable)
- `rewardId`: Reward purchased (if points spent)
- `createdAt`: Timestamp

### Balance Calculation

User balance = SUM(all PointsLedger.delta for userId)

---

## Streak Mechanics

### Streak Rules

1. **First Completion**: Creates streak with `currentStreak = 1`
2. **Consecutive Day**: Increments `currentStreak` by 1
3. **Same Day**: No change (already counted)
4. **Gap (>1 day)**: Resets `currentStreak` to 1
5. **Longest Streak**: Tracks all-time best streak

### Streak States

```python
# Example streak progression
Day 1: Complete task → currentStreak = 1, longestStreak = 1
Day 2: Complete task → currentStreak = 2, longestStreak = 2
Day 2: Complete again → currentStreak = 2 (no change)
Day 4: Complete task (missed day 3) → currentStreak = 1, longestStreak = 2
```

### Streak Protection

**At-Risk Detection**: Streak is at risk if:
- `lastCompletionDate` was yesterday
- No completion today
- `currentStreak > 0`

**Notification**: Cron job at 20:00 checks all users and sends reminders.

### Timezone Handling

All dates are stored as UTC and converted to user's local timezone for display.

---

## Integration

### Task Completion Flow

```python
# In routers/tasks.py

@router.post("/{task_id}/complete")
def complete_task(task_id: str, ...):
    # 1. Mark task as done
    task.status = "done"
    task.completedBy = user.id
    task.completedAt = datetime.utcnow()

    # 2. Create task log
    task_log = TaskLog(
        taskId=task_id,
        userId=user.id,
        action="completed",
        metadata={}
    )

    # 3. Trigger gamification
    result = gamification_service.on_task_completed(
        task=task,
        user=user,
        completion_time=datetime.utcnow(),
        db=db,
        approval_rating=None
    )

    # 4. Return response
    return {
        "task": task,
        "gamification": result
    }
```

### Gamification Response

```json
{
  "success": true,
  "user_id": "uuid",
  "task_id": "uuid",
  "points_earned": 15,
  "multipliers": [
    {"name": "on_time", "value": 1.2},
    {"name": "streak_week", "value": 1.1}
  ],
  "total_points": 125,
  "streak": {
    "current": 7,
    "longest": 14,
    "days_since_last": 0,
    "is_at_risk": false
  },
  "new_badges": [
    {
      "code": "streak_7",
      "name": "Week Warrior",
      "description": "Complete tasks for 7 consecutive days",
      "icon": "⭐",
      "category": "streak"
    }
  ],
  "close_to_unlock": {
    "tasks_25": {
      "name": "Helping Hand",
      "progress": 0.8,
      "current": 20,
      "target": 25
    }
  },
  "leaderboard_position": 2,
  "special_achievements": [
    {
      "type": "streak_milestone",
      "message": "7-day streak achieved!",
      "icon": "🔥"
    }
  ]
}
```

---

## API Reference

### Gamification Endpoints

Base path: `/api/gamification`

#### `GET /profile/{user_id}`

Get complete gamification profile.

**Response**:
```json
{
  "user_id": "uuid",
  "display_name": "John Doe",
  "role": "child",
  "points": {
    "current_balance": 125,
    "total_earned": 150,
    "total_spent": 25,
    "leaderboard_position": 2
  },
  "streak": {
    "current": 7,
    "longest": 14,
    "is_at_risk": false
  },
  "badges": {
    "earned": [...],
    "total_earned": 5,
    "progress": {...},
    "available": 24
  },
  "leaderboard": {
    "week": [...],
    "alltime": [...]
  },
  "rewards": {
    "affordable": [...],
    "count": 3
  }
}
```

#### `GET /leaderboard?family_id={id}&period={week|month|alltime}`

Get family leaderboard.

**Response**:
```json
{
  "period": "week",
  "family_id": "uuid",
  "leaderboard": [
    {
      "rank": 1,
      "user_id": "uuid",
      "display_name": "Alice",
      "points": 150,
      "avatar": "url",
      "role": "child"
    }
  ]
}
```

#### `POST /redeem-reward`

Spend points on reward.

**Request**:
```json
{
  "reward_id": "uuid",
  "require_approval": false
}
```

**Response**:
```json
{
  "success": true,
  "reward_id": "uuid",
  "reward_name": "30 minutes screen time",
  "cost": 50,
  "new_balance": 75,
  "requires_approval": false
}
```

#### `GET /badges/available?user_id={id}`

Get earned badges and progress.

**Response**:
```json
{
  "user_id": "uuid",
  "earned_badges": [...],
  "total_earned": 5,
  "progress": {
    "tasks_25": {
      "name": "Helping Hand",
      "current": 20,
      "target": 25,
      "progress": 0.8
    }
  },
  "total_available": 24
}
```

#### `GET /streak/{user_id}`

Get streak statistics.

**Response**:
```json
{
  "user_id": "uuid",
  "current": 7,
  "longest": 14,
  "days_since_last": 0,
  "is_at_risk": false,
  "last_completion_date": "2025-11-11"
}
```

#### `GET /points/history/{user_id}?limit=50`

Get points transaction history.

**Response**:
```json
{
  "user_id": "uuid",
  "history": [
    {
      "id": "uuid",
      "delta": 15,
      "reason": "Task completed: Clean room",
      "task_id": "uuid",
      "created_at": "2025-11-11T10:00:00Z",
      "balance_after": 125
    }
  ],
  "count": 10
}
```

#### `GET /task/{task_id}/preview`

Preview rewards before completion.

**Response**:
```json
{
  "task_id": "uuid",
  "user_id": "uuid",
  "base_points": 10,
  "estimated_points": 13,
  "estimated_multipliers": [
    {
      "name": "on_time",
      "value": 1.2,
      "description": "Complete before due date"
    }
  ],
  "potential_badges": [
    {
      "code": "tasks_25",
      "name": "Helping Hand",
      "icon": "🌟",
      "progress": 0.96
    }
  ],
  "current_streak": 7
}
```

---

## Examples

### Example 1: Simple Task Completion

```python
# Task: Clean room (10 points, no special conditions)
# User: Child with no streak

# Points calculation:
base_points = 10
multipliers = []  # No bonuses
final_points = 10

# Badges awarded:
- "first_task" (if first completion)

# Streak updated:
current_streak = 1
longest_streak = 1
```

### Example 2: Perfect Task Completion

```python
# Task: Homework (15 points, due tomorrow)
# User: Teen with 7-day streak
# Completion: Before due date, 5-star approval

# Points calculation:
base_points = 15
multipliers = [
    ("on_time", 1.2),      # Completed early
    ("streak_week", 1.1),  # 7-day streak
    ("quality_excellent", 1.2)  # 5-star approval
]
final_points = 15 * 1.2 * 1.1 * 1.2 = 23.76 → 23 points

# Badges awarded:
- "streak_7" (if just reached)
- "homework_hero" (if 20th homework task)
- "punctual_pro" (if 10th on-time task)

# Streak updated:
current_streak = 8
longest_streak = 8
```

### Example 3: Speed Completion

```python
# Task: Take out trash (10 points, 15 min estimate)
# User: Child, completed in 5 minutes
# Completion: Same day as previous task

# Points calculation:
base_points = 10
multipliers = [
    ("speed_demon", 1.15),  # Completed in <50% time
]
final_points = 10 * 1.15 = 11.5 → 11 points

# Badges awarded:
- "speed_demon" (if first speed completion)
- "efficiency_master" (if 10th speed completion)

# Streak:
current_streak = 5  # No change (same day)
longest_streak = 7
```

### Example 4: Streak Broken

```python
# Task: Feed pet (10 points)
# User: Parent, last completion was 3 days ago
# Previous streak: 14 days

# Points calculation:
base_points = 10
multipliers = []  # No streak bonus (broken)
final_points = 10

# Badges: None (streak badges already earned)

# Streak updated:
current_streak = 1  # Reset!
longest_streak = 14  # Preserved
last_completion_date = today

# Special notification:
- "Streak broken! Start fresh today 💪"
```

---

## Implementation Notes

### Performance Considerations

- **Badge checking**: Only checks unearn badges to minimize queries
- **Leaderboard**: Cached per family with 5-minute TTL
- **Points balance**: Indexed query on userId for fast calculation
- **Streak detection**: Single query with date comparison

### Security

- **Access control**: Users can only access their own data (except parents)
- **Audit logging**: All points and badge awards are logged
- **Validation**: Points cannot be negative unless spending on rewards
- **Rate limiting**: Badge awarding prevents duplicate awards

### Database Indexes

```sql
-- Points ledger
CREATE INDEX idx_points_user_created ON points_ledger(userId, createdAt);

-- Badges
CREATE INDEX idx_badge_user_code ON badges(userId, code);

-- Task logs
CREATE INDEX idx_tasklog_user_action ON task_logs(userId, action);
```

### Testing

See `backend/tests/test_gamification.py` for comprehensive test suite covering:
- Streak logic (consecutive days, gaps, same-day)
- Badge conditions (all 24 badges)
- Points calculation (all multipliers)
- Integration flow (end-to-end)
- Edge cases (timezone, zero points, overdue penalties)

---

## Roadmap

### Phase 1 (Current)
- ✅ Core gamification services
- ✅ Badge system (24 badges)
- ✅ Points economy with multipliers
- ✅ Streak tracking
- ✅ Leaderboards
- ✅ API endpoints

### Phase 2 (Week 6)
- 🎯 Parent approval flow with quality ratings
- 🎯 Reward shop redemption
- 🎯 Notification system for streaks at risk
- 🎯 Weekly challenges

### Phase 3 (Week 7)
- 🎯 Family goals with collaborative rewards
- 🎯 Seasonal badges (holidays, events)
- 🎯 Personal best tracking
- 🎯 Achievement sharing

---

## Support

For questions or issues:
- Backend: Check `services/gamification_service.py`
- Tests: Run `pytest backend/tests/test_gamification.py -v`
- API: See OpenAPI docs at `/docs`

---

**Version**: 1.0.0
**Last Updated**: 2025-11-11
**Status**: Production Ready ✅
