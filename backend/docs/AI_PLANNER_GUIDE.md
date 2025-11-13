# AI Planner Guide

## Overview

The AI Planner generates intelligent weekly task schedules using a 4-tier fallback system:
1. **Tier 1:** Claude Sonnet (OpenRouter) - High quality, expensive
2. **Tier 2:** Claude Haiku (OpenRouter) - Fast, 10x cheaper
3. **Tier 3:** Rule-based planner - Deterministic, offline-capable
4. **Tier 4:** Cached responses - Instant, zero cost

## Key Features

- Fairness-aware task distribution
- Calendar conflict avoidance
- Age-appropriate task assignment
- Rotation strategy support
- Cost optimization ($0.001-0.005 per plan)
- Offline fallback capability

## API Endpoints

### 1. Generate Plan

**POST** `/ai/plan-week`

**Request:**
```json
{
  "start_date": "2025-11-17",
  "preferences": {
    "prefer_evening": true,
    "avoid_overload": true
  }
}
```

**Response:**
```json
{
  "week_plan": [
    {
      "date": "2025-11-17",
      "tasks": [
        {
          "task_id": "uuid-123",
          "title": "Vaatwasser",
          "assignee_id": "uuid-noah",
          "assignee_name": "Noah",
          "due_time": "19:00",
          "points": 20,
          "est_duration": 15,
          "category": "cleaning"
        }
      ]
    }
  ],
  "fairness": {
    "distribution": {
      "Noah": 0.28,
      "Luna": 0.24,
      "Sam": 0.22
    },
    "distribution_minutes": {
      "uuid-noah": 120,
      "uuid-luna": 100,
      "uuid-sam": 90
    },
    "notes": "Balanced on age and calendar availability"
  },
  "conflicts": [],
  "total_tasks": 28,
  "cost": 0.003,
  "model_used": "claude-sonnet",
  "tier": 1
}
```

### 2. Apply Plan

**POST** `/ai/apply-plan`

**Request:**
```json
{
  "week_plan": [
    {
      "date": "2025-11-17",
      "tasks": [
        {
          "task_id": "uuid-123",
          "assignee_id": "uuid-noah",
          "due_time": "19:00"
        }
      ]
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "tasks_created": 15,
  "tasks_updated": 3,
  "message": "Created 15 task assignments, updated 3 existing tasks"
}
```

## Fairness Algorithm

### Capacity by Role

- **Child (6-10 years):** 120 minutes/week (2 hours)
- **Teen (11-17 years):** 240 minutes/week (4 hours)
- **Parent:** 360 minutes/week (6 hours)
- **Helper:** 0 minutes (excluded from assignments)

### Distribution Rules

1. **Equal Split (Baseline):** Distribute tasks equally by duration
2. **Age Adjustment:** Younger children get easier/shorter tasks
3. **Calendar Awareness:** Reduce load on busy days
4. **Workload Balance:** Aim for ±10% deviation from equal split

### Example Calculation

Family: Noah (10y), Luna (15y), Sam (parent)

**Step 1: Calculate Ideal Distribution**
- Total capacity: 120 + 240 + 360 = 720 min/week
- Noah ideal: 120/720 = 16.7%
- Luna ideal: 240/720 = 33.3%
- Sam ideal: 360/720 = 50%

**Step 2: Assign Tasks**
- Total task duration: 420 minutes
- Noah gets: 420 × 0.167 = 70 minutes
- Luna gets: 420 × 0.333 = 140 minutes
- Sam gets: 420 × 0.50 = 210 minutes

**Step 3: Validate**
- Noah: 70/120 = 58% capacity ✅
- Luna: 140/240 = 58% capacity ✅
- Sam: 210/360 = 58% capacity ✅

## Conflict Detection

### Calendar Event Conflicts

The AI planner checks for time overlaps:

**Conflict Detected:**
```json
{
  "task": "Vaatwasser",
  "event": "Soccer Practice",
  "user": "Noah",
  "date": "2025-11-17",
  "task_time": "16:30",
  "event_time": "16:00",
  "suggestion": "Move task to after 17:00"
}
```

**Resolution:**
1. AI suggests alternative times
2. Parent reviews conflicts
3. Parent edits plan or accepts suggestions
4. Apply final plan

## Rotation Strategies

### Round Robin

**Usage:** Fair rotation for recurring tasks

**Example:**
- Monday: Noah
- Tuesday: Luna
- Wednesday: Sam
- Thursday: Noah (cycle repeats)

**Implementation:**
```python
rotation_state = {
    "index": 0,
    "lastRotationDate": "2025-11-17"
}
```

### Fairness-Based

**Usage:** Assign to user with lowest current workload

**Algorithm:**
1. Calculate current workload for each eligible user
2. Sort by workload (ascending)
3. Assign to user with lowest load

### Random

**Usage:** Variety for less critical tasks

### Manual

**Usage:** Parent assigns each time

## AI Prompt Engineering

### System Prompt

```
You are an AI family task planning assistant. Generate a fair weekly task plan.

Fairness Rules:
- Child (8-10y): Max 120 minutes/week (2 hours)
- Teen (11-17y): Max 240 minutes/week (4 hours)
- Parent: Max 360 minutes/week (6 hours)

Task Assignment Strategy:
1. Check user capacity and current workload
2. Avoid assigning tasks during calendar events
3. Prefer users with lower current workload
4. Consider age-appropriateness
5. Limit to max 3 tasks per person per day

Output Format: Pure JSON
```

### User Prompt

```
Generate a weekly task plan for this family.

Week: 2025-11-17 to 2025-11-23 (Monday to Sunday)

Family Members:
- Noah (age 10, child): Capacity 120min/week, Current load 45%
- Luna (age 15, teen): Capacity 240min/week, Current load 32%

Recurring Tasks to Assign:
- Vaatwasser (15min, 20pts, daily)
- Stofzuigen (30min, 30pts, weekly MO,TH)

Calendar Events (busy times to avoid):
- Soccer Practice on Mon 16:00 (attendees: Noah)
- Piano Lesson on Wed 17:00 (attendees: Luna)

Generate the plan now:
```

## Fallback Tiers

### Tier 1: Claude Sonnet (Primary)

**Characteristics:**
- Highest quality plans
- Best fairness optimization
- Context-aware reasoning
- Cost: $3/1M input, $15/1M output
- Typical cost: $0.003-0.005 per plan

**When Used:**
- Primary tier for all planning requests
- Retries: 3 attempts with exponential backoff

### Tier 2: Claude Haiku (Fallback)

**Characteristics:**
- Good quality plans
- Fast response (<2s)
- Cost: $0.25/1M input, $1.25/1M output
- Typical cost: $0.0003-0.0005 per plan

**When Used:**
- Sonnet fails after retries
- Timeout (>30s)
- API rate limit reached

### Tier 3: Rule-Based Planner

**Characteristics:**
- Deterministic plans
- Simple round-robin assignment
- No AI required
- Offline-capable
- Cost: $0

**Algorithm:**
```python
def rule_based_plan(context, start_date):
    users = sorted(context["users"], key=lambda u: u["current_workload"])

    for day in range(7):
        for task in recurring_tasks:
            user = users[day % len(users)]
            assign_task(task, user, day)

    return plan
```

**When Used:**
- AI tiers fail completely
- No OpenRouter API key configured
- Emergency fallback

### Tier 4: Cached Responses

**Characteristics:**
- Instant response (<10ms)
- Identical context returns cached plan
- Cost: $0

**Cache Key:**
```python
key = hash({
    "family_id": family_id,
    "start_date": start_date,
    "user_count": len(users),
    "task_count": len(tasks),
    "event_count": len(events)
})
```

**TTL:** 1 hour

**When Used:**
- Identical request within cache window
- Reduces API costs for repeated requests

## Cost Optimization

### Cost Breakdown

**Typical Plan Generation:**
- Input tokens: 500 (context)
- Output tokens: 200 (plan JSON)
- Sonnet cost: $0.0015 + $0.003 = $0.0045
- Haiku cost: $0.000125 + $0.00025 = $0.000375

**Monthly Cost Estimate:**
- 1 family, 4 plans/month: $0.02 (Sonnet) or $0.002 (Haiku)
- 100 families, 4 plans/month: $1.80 (Sonnet) or $0.15 (Haiku)
- 1000 families, 4 plans/month: $18 (Sonnet) or $1.50 (Haiku)

### Optimization Strategies

1. **Caching:** 50% cache hit rate → 50% cost reduction
2. **Haiku Preference:** 10x cheaper, good quality
3. **Batch Planning:** Multiple families in single request
4. **Token Reduction:** Optimize prompt length

## Usage Examples

### Example 1: Weekly Plan for Family

```python
import requests

# Generate plan
response = requests.post("http://localhost:8000/ai/plan-week",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "start_date": "2025-11-17",
        "preferences": {"prefer_evening": True}
    }
)

plan = response.json()

# Review plan
print(f"Total tasks: {plan['total_tasks']}")
print(f"Cost: ${plan['cost']}")
print(f"Conflicts: {len(plan['conflicts'])}")

# Apply plan
if len(plan['conflicts']) == 0:
    response = requests.post("http://localhost:8000/ai/apply-plan",
        headers={"Authorization": f"Bearer {token}"},
        json={"week_plan": plan['week_plan']}
    )
    print(f"Tasks created: {response.json()['tasks_created']}")
```

### Example 2: Handle Conflicts

```python
# Generate plan
response = requests.post("http://localhost:8000/ai/plan-week",
    headers={"Authorization": f"Bearer {token}"},
    json={"start_date": "2025-11-17"}
)

plan = response.json()

# Check for conflicts
if plan['conflicts']:
    print("Conflicts detected:")
    for conflict in plan['conflicts']:
        print(f"  - {conflict['task']} conflicts with {conflict['event']}")
        print(f"    Suggestion: {conflict['suggestion']}")

    # Option 1: Edit plan manually
    for day in plan['week_plan']:
        for task in day['tasks']:
            if task['title'] in [c['task'] for c in plan['conflicts']]:
                task['due_time'] = "20:00"  # Move to evening

    # Option 2: Reject and regenerate
    # (Add exclusion preferences and retry)
```

### Example 3: Custom Preferences

```python
# Generate plan with custom preferences
response = requests.post("http://localhost:8000/ai/plan-week",
    headers={"Authorization": f"Bearer {token}"},
    json={
        "start_date": "2025-11-17",
        "preferences": {
            "prefer_evening": True,
            "avoid_mondays": ["Noah"],  # Noah busy on Mondays
            "max_tasks_per_day": 2,
            "rotation_override": {
                "Vaatwasser": "round_robin",
                "Stofzuigen": "fairness"
            }
        }
    }
)
```

## Testing

Run AI planner tests:

```bash
cd backend
pytest tests/test_ai_planner.py -v
```

**Test Coverage:**
- ✅ AI planner generates valid plan
- ✅ Respects capacity limits
- ✅ Avoids event conflicts
- ✅ Fair distribution (±10%)
- ✅ Fallback to rule-based planner
- ✅ Caching behavior
- ✅ Apply plan creates tasks

## Monitoring

### Metrics to Track

- **AI Usage:**
  - Plans per day/week/month
  - Cost per plan
  - Tier distribution (Sonnet/Haiku/Rule-based)
  - Cache hit rate

- **Quality:**
  - Conflict rate (target: <5%)
  - Fairness deviation (target: <10%)
  - User satisfaction (surveys)

- **Performance:**
  - Response time per tier
  - Timeout rate
  - Fallback frequency

### Logging

All AI operations logged:
```
[INFO] AI Plan: family=uuid-123, model=claude-sonnet, cost=0.003, tasks=28, conflicts=0
[WARN] AI Fallback: family=uuid-456, reason=timeout, tier=2
[ERROR] AI Failed: family=uuid-789, error=rate_limit, fallback=rule-based
```

## Troubleshooting

### Issue: High Cost

**Symptoms:** >$50/month for AI planning

**Solutions:**
- Increase cache TTL
- Prefer Haiku over Sonnet
- Batch planning requests
- Reduce planning frequency

### Issue: Poor Quality Plans

**Symptoms:** High conflict rate, unfair distribution

**Solutions:**
- Use Sonnet instead of Haiku
- Improve prompt engineering
- Add more context (past completions)
- Fine-tune fairness algorithm

### Issue: Slow Response

**Symptoms:** >10s response time

**Solutions:**
- Use Haiku (10x faster)
- Reduce context size
- Enable caching
- Check API latency

## Future Enhancements

**Phase 2:**
- Learning from past plans (ML)
- Personalized preferences per user
- Multi-week planning
- Smart rescheduling on conflicts
- Voice-based plan generation

**Phase 3:**
- Predictive task assignment
- Habit formation tracking
- Gamification integration
- Family collaboration features
