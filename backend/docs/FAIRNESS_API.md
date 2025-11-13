# FamQuest Fairness API Guide

Complete guide to the FamQuest fairness system for workload analysis and task distribution.

## Overview

The fairness API provides:
- **Workload Analysis**: Calculate task distribution across family members
- **Fairness Scoring**: Gini coefficient-based fairness measurement
- **AI Insights**: Automated analysis and recommendations
- **Capacity Tracking**: Age-appropriate task capacity monitoring

## Capacity Model

### Role-Based Capacity

| Role | Weekly Capacity | Example Age |
|------|----------------|-------------|
| Child | 2 hours (120 min) | 6-10 years |
| Teen | 4 hours (240 min) | 11-17 years |
| Parent | 6 hours (360 min) | Adult |
| Helper | Excluded from fairness | N/A |

### Capacity Calculation

Total workload = Task duration + Calendar busy hours

Workload percentage = (Total workload / Weekly capacity) × 100

## API Endpoints

### Get Fairness Data

```http
GET /fairness/family/{family_id}?range=this_week
Authorization: Bearer {token}
```

**Query Parameters**:
- `range`: Time range for analysis
  - `this_week`: Last 7 days (default)
  - `this_month`: Last 30 days
  - `all_time`: All time data

**Response**:
```json
{
  "fairness_score": 0.85,
  "workloads": {
    "user-uuid-1": {
      "user_id": "user-uuid-1",
      "display_name": "Noah",
      "role": "teen",
      "used_hours": 3.5,
      "total_capacity": 4.0,
      "tasks_completed": 12,
      "percentage": 87.5,
      "is_overloaded": false,
      "is_underutilized": false
    },
    "user-uuid-2": {
      "user_id": "user-uuid-2",
      "display_name": "Luna",
      "role": "child",
      "used_hours": 1.2,
      "total_capacity": 2.0,
      "tasks_completed": 8,
      "percentage": 60.0,
      "is_overloaded": false,
      "is_underutilized": false
    }
  },
  "task_distribution": {
    "user-uuid-1": 12,
    "user-uuid-2": 8
  },
  "start_date": "2025-11-04T00:00:00Z",
  "end_date": "2025-11-11T00:00:00Z",
  "total_tasks": 20,
  "average_workload": 73.8
}
```

### Get Fairness Insights

```http
GET /fairness/insights/{family_id}
Authorization: Bearer {token}
```

**Response**:
```json
{
  "insights": [
    {
      "type": "warning",
      "user_id": "user-uuid-1",
      "message": "Noah is 20% above average this week",
      "recommendation": "Consider reassigning some tasks or reducing workload"
    },
    {
      "type": "success",
      "user_id": "user-uuid-2",
      "message": "Luna has a 7-day streak! 🔥",
      "recommendation": "Encourage to maintain momentum"
    },
    {
      "type": "info",
      "user_id": "user-uuid-3",
      "message": "Sam has lightest load - consider assigning more tasks",
      "recommendation": "Assign additional tasks to balance workload"
    }
  ],
  "fairness_score": 0.78,
  "total_insights": 3
}
```

**Insight Types**:
- `success`: Positive achievement or milestone
- `warning`: Overload or imbalance detected
- `info`: Informational suggestion
- `alert`: Critical issue requiring attention

### Get Recommendations (Parent Only)

```http
GET /fairness/recommendations/{family_id}
Authorization: Bearer {token}
```

**Response**:
```json
{
  "recommendations": [
    {
      "priority": "high",
      "action": "rebalance_tasks",
      "title": "Rebalance Task Distribution",
      "description": "Move tasks from Noah, Luna to Sam, Eva",
      "users_affected": ["user-uuid-1", "user-uuid-2", "user-uuid-3", "user-uuid-4"]
    },
    {
      "priority": "medium",
      "action": "enable_fairness_rotation",
      "title": "Enable Automatic Fairness Rotation",
      "description": "Switch 5 recurring tasks from manual to fairness rotation strategy",
      "tasks_affected": 5
    },
    {
      "priority": "low",
      "action": "assign_tasks",
      "title": "Assign Pending Tasks",
      "description": "You have 3 unassigned tasks that need an owner",
      "tasks_count": 3
    }
  ],
  "total_count": 3
}
```

**Recommendation Actions**:
- `rebalance_tasks`: Redistribute tasks between users
- `enable_fairness_rotation`: Switch to automatic rotation
- `assign_tasks`: Assign pending tasks

**Priority Levels**:
- `high`: Immediate action recommended
- `medium`: Should address within week
- `low`: Optional improvement

## Fairness Score Calculation

### Gini Coefficient

The fairness score uses the Gini coefficient to measure workload equality:

1. **Formula**: `G = (2 × Σ(i × x[i])) / (n × Σx) - (n + 1) / n`
2. **Range**: 0.0 (perfect inequality) to 1.0 (perfect equality)
3. **Inverted**: We invert the coefficient so higher = more fair

### Interpretation

| Score | Interpretation | Action |
|-------|---------------|---------|
| 0.9-1.0 | Excellent balance | Maintain current strategy |
| 0.7-0.9 | Good balance | Monitor periodically |
| 0.5-0.7 | Moderate imbalance | Consider rebalancing |
| 0.0-0.5 | Significant imbalance | Immediate action needed |

## Integration with Task System

### Rotation Strategies

The fairness system integrates with task rotation:

#### Round Robin
```json
{
  "rotationStrategy": "round_robin",
  "assignees": ["user-1", "user-2", "user-3"]
}
```
Simple rotation through list of assignees.

#### Fairness-Based
```json
{
  "rotationStrategy": "fairness",
  "assignees": ["user-1", "user-2", "user-3"]
}
```
Automatically assigns to user with lowest workload.

#### Random
```json
{
  "rotationStrategy": "random",
  "assignees": ["user-1", "user-2", "user-3"]
}
```
Random assignment from eligible users.

#### Manual
```json
{
  "rotationStrategy": "manual",
  "assignees": []
}
```
Parent assigns manually each time.

### Automatic Rotation

For recurring tasks with `rotationStrategy: "fairness"`:

```python
from core.fairness import FairnessEngine

engine = FairnessEngine(db)
next_assignee = engine.rotate_assignee(task_template, occurrence_date)
```

The engine:
1. Gets current workload for all eligible users
2. Filters users at/over capacity (>90%)
3. Checks availability on task due date
4. Assigns to user with lowest workload

## Use Cases

### Parent Dashboard

Display fairness overview:
```python
# Get fairness data
data = client.get(f'/fairness/family/{family_id}?range=this_week')

# Show fairness score
print(f"Family Fairness: {data['fairness_score']:.0%}")

# Show workload bars
for user_id, workload in data['workloads'].items():
    print(f"{workload['display_name']}: {workload['percentage']:.0f}% capacity")
```

### Weekly Review

Generate weekly fairness report:
```python
# Get insights
insights = client.get(f'/fairness/insights/{family_id}')

# Group by type
warnings = [i for i in insights['insights'] if i['type'] == 'warning']
successes = [i for i in insights['insights'] if i['type'] == 'success']

print(f"🎉 Achievements: {len(successes)}")
print(f"⚠️ Areas for improvement: {len(warnings)}")
```

### Task Assignment

Use fairness engine for manual assignment:
```python
from core.fairness import FairnessEngine

engine = FairnessEngine(db)

# Get eligible users
eligible = db.query(User).filter(
    User.familyId == family_id,
    User.role.in_(['child', 'teen'])
).all()

# Get suggestion
suggested_user_id = engine.suggest_assignee(task, eligible, occurrence_date)

print(f"Suggested assignee: {suggested_user_id}")
```

## Best Practices

### For Parents

1. **Monitor Weekly**: Check fairness score weekly
2. **Act on Warnings**: Address overload warnings promptly
3. **Use Fairness Rotation**: Enable for recurring tasks
4. **Balance Workload**: Aim for fairness score >0.7
5. **Celebrate Streaks**: Acknowledge achievements

### For Developers

1. **Exclude Helpers**: Don't include helpers in fairness calculations
2. **Consider Calendar**: Integrate with calendar busy hours
3. **Update Capacity**: Adjust capacity when user role changes
4. **Cache Results**: Cache fairness calculations for performance
5. **Log Decisions**: Audit fairness-based task assignments

## Troubleshooting

### Inaccurate Workload

**Issue**: Workload percentage doesn't match reality

**Solutions**:
1. Verify task `estDuration` is accurate
2. Check calendar integration is working
3. Ensure user role is correct (child/teen/parent)
4. Verify tasks are properly marked as completed

### Low Fairness Score

**Issue**: Fairness score consistently low

**Solutions**:
1. Switch recurring tasks to fairness rotation
2. Review task assignments manually
3. Check if one user is doing most tasks
4. Consider adjusting task difficulty/duration

### Missing Insights

**Issue**: No insights generated

**Solutions**:
1. Ensure users have completed tasks in time range
2. Check if fairness score is in normal range (0.7-1.0)
3. Verify streaks are being tracked
4. Ensure task logs are being created

## Future Enhancements

Planned improvements:
- Machine learning-based capacity prediction
- Skill-based task matching
- Historical fairness trends
- Family fairness leaderboard
- Automated rebalancing suggestions
