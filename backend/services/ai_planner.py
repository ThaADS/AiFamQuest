"""
AI Planner Service

Intelligent weekly task planning with fairness-aware distribution,
calendar conflict avoidance, and 4-tier AI fallback system.

Features:
- OpenRouter LLM integration (Sonnet → Haiku fallback)
- Fairness-based task distribution
- Calendar conflict detection
- Rule-based fallback planner
- Caching for performance
"""

from sqlalchemy.orm import Session
from datetime import datetime, timedelta, time
from typing import List, Dict, Any, Optional
from core import models
from core.ai_client import _call_with_fallback
from core.fairness import FairnessEngine
from core.cache import get_cached_response, set_cached_response
import json
import logging
from dateutil import rrule

logger = logging.getLogger(__name__)


class AIPlanner:
    """AI-powered weekly task planner with fairness optimization"""

    def __init__(self, db: Session, family_id: str):
        self.db = db
        self.family_id = family_id
        self.fairness = FairnessEngine(db)

    async def generate_week_plan(
        self,
        start_date: datetime,
        user_preferences: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Generate AI-powered weekly task plan.

        Steps:
        1. Fetch family context (users, existing tasks, events, capacities)
        2. Identify unassigned/recurring tasks needing assignment
        3. Build AI prompt with context
        4. Call OpenRouter LLM (Sonnet preferred)
        5. Parse AI response (JSON)
        6. Apply fairness rules
        7. Validate plan (no conflicts, within capacities)
        8. Return plan for parent approval

        Returns:
        {
            "week_plan": [
                {
                    "date": "2025-11-17",
                    "tasks": [
                        {
                            "task_id": "uuid",
                            "title": "Vaatwasser",
                            "assignee_id": "uuid-noah",
                            "assignee_name": "Noah",
                            "due": "2025-11-17T19:00:00Z",
                            "points": 20,
                            "est_duration": 15
                        }
                    ]
                }
            ],
            "fairness": {
                "distribution": {
                    "noah": 0.28,
                    "luna": 0.24,
                    "sam": 0.22
                },
                "notes": "Balanced on age/agenda"
            },
            "conflicts": [],
            "total_tasks": 28,
            "cost": 0.003
        }
        """
        start_time = datetime.utcnow()

        # 1. Fetch family context
        context = await self._build_family_context(start_date)

        # Check cache first
        cache_key = self._generate_cache_key(context, start_date)
        cached_plan = await get_cached_response(cache_key, "planner", temperature=0.4)
        if cached_plan:
            logger.info(f"Returning cached plan for family {self.family_id}")
            return cached_plan

        # 2. Build AI prompt
        prompt = self._build_planning_prompt(context, start_date)

        # 3. Call AI (with fallback)
        try:
            messages = [
                {"role": "system", "content": self._get_system_prompt()},
                {"role": "user", "content": prompt}
            ]

            ai_response, tier, cache_hit, model = await _call_with_fallback(messages, temperature=0.4)

            if ai_response and tier < 3:
                # Parse AI response
                plan = self._parse_ai_response(ai_response, context)

                # 4. Apply fairness validation
                plan = self.fairness_validate_plan(plan, context)

                # 5. Check conflicts
                plan["conflicts"] = self._detect_conflicts(plan, context)

                # Calculate cost estimate
                tokens = ai_response.get("usage", {})
                plan["cost"] = self._estimate_cost(tokens.get("prompt_tokens", 0), tokens.get("completion_tokens", 0), model)
                plan["model_used"] = model
                plan["tier"] = tier

                # Cache successful plan
                await set_cached_response(cache_key, "planner", 0.4, plan)

                logger.info(f"Generated AI plan for family {self.family_id} using {model} (tier {tier})")
                return plan

        except Exception as e:
            logger.error(f"AI planner failed: {e}")

        # TIER 3: Fallback to rule-based planner
        logger.info(f"Falling back to rule-based planner for family {self.family_id}")
        plan = self._rule_based_plan(context, start_date)

        plan["model_used"] = "rule-based"
        plan["tier"] = 3
        plan["cost"] = 0

        return plan

    async def _build_family_context(self, start_date: datetime) -> Dict[str, Any]:
        """
        Gather all relevant family context for AI planning.

        Returns:
        {
            "users": [...],
            "recurring_tasks": [...],
            "one_time_tasks": [...],
            "events_this_week": [...],
            "past_completions": [...]
        }
        """
        end_date = start_date + timedelta(days=7)

        # Get family members (exclude helpers from task assignment)
        users = self.db.query(models.User).filter(
            models.User.familyId == self.family_id,
            models.User.role != "helper"
        ).all()

        user_context = []
        for user in users:
            # Calculate age from date of birth (if available)
            age = None
            # Note: User model doesn't have date_of_birth field yet, use role as proxy
            age_map = {"child": 9, "teen": 15, "parent": 40}
            age = age_map.get(user.role, 18)

            # Get current workload
            workload = self.fairness.calculate_workload(user.id, start_date.date())

            user_context.append({
                "id": str(user.id),
                "name": user.displayName,
                "age": age,
                "role": user.role,
                "capacity_minutes_per_week": self.fairness.get_user_capacity(user),
                "current_workload": workload,
                "permissions": user.permissions
            })

        # Get recurring tasks
        recurring = self.db.query(models.Task).filter(
            models.Task.familyId == self.family_id,
            models.Task.rrule.isnot(None),
            models.Task.status != "done"
        ).all()

        recurring_context = []
        for task in recurring:
            # Expand recurrences for this week
            occurrences = self._expand_task_occurrences(task, start_date, end_date)
            recurring_context.append({
                "id": str(task.id),
                "title": task.title,
                "desc": task.desc,
                "category": task.category,
                "points": task.points,
                "est_duration": task.estDuration,
                "rrule": task.rrule,
                "assignees": task.assignees,
                "rotation_strategy": task.rotationStrategy,
                "occurrences_this_week": len(occurrences)
            })

        # Get one-time tasks
        one_time = self.db.query(models.Task).filter(
            models.Task.familyId == self.family_id,
            models.Task.rrule.is_(None),
            models.Task.status == "open",
            models.Task.due >= start_date,
            models.Task.due < end_date
        ).all()

        one_time_context = []
        for task in one_time:
            one_time_context.append({
                "id": str(task.id),
                "title": task.title,
                "due": task.due.isoformat() if task.due else None,
                "assignees": task.assignees,
                "points": task.points,
                "est_duration": task.estDuration
            })

        # Get events this week
        events = self.db.query(models.Event).filter(
            models.Event.familyId == self.family_id,
            models.Event.start >= start_date,
            models.Event.start < end_date
        ).all()

        events_context = []
        for event in events:
            events_context.append({
                "id": str(event.id),
                "title": event.title,
                "start": event.start.isoformat(),
                "end": event.end.isoformat() if event.end else None,
                "attendees": event.attendees,
                "category": event.category,
                "all_day": event.allDay
            })

        # Get past 4 weeks of completions for pattern analysis
        past_start = start_date - timedelta(days=28)
        past_completions = self.db.query(models.Task).filter(
            models.Task.familyId == self.family_id,
            models.Task.status == "done",
            models.Task.completedAt >= past_start,
            models.Task.completedAt < start_date
        ).all()

        completion_context = []
        for task in past_completions[:50]:  # Limit to 50 most recent
            completion_context.append({
                "title": task.title,
                "completed_by": task.completedBy,
                "completed_at": task.completedAt.isoformat() if task.completedAt else None,
                "points": task.points
            })

        return {
            "users": user_context,
            "recurring_tasks": recurring_context,
            "one_time_tasks": one_time_context,
            "events_this_week": events_context,
            "past_completions": completion_context,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat()
        }

    def _expand_task_occurrences(
        self,
        task: models.Task,
        start: datetime,
        end: datetime
    ) -> List[datetime]:
        """Expand recurring task occurrences for date range"""
        if not task.rrule:
            return []

        try:
            # Parse RRULE
            rule = rrule.rrulestr(task.rrule, dtstart=start)

            # Get occurrences in range
            occurrences = []
            for occurrence in rule:
                if occurrence >= start and occurrence < end:
                    occurrences.append(occurrence)
                if occurrence >= end:
                    break
                if len(occurrences) >= 100:  # Safety limit
                    break

            return occurrences
        except Exception as e:
            logger.error(f"Failed to parse RRULE for task {task.id}: {e}")
            return []

    def _get_system_prompt(self) -> str:
        """Get system prompt for AI planner"""
        return """You are an AI family task planning assistant. Generate a fair weekly task plan.

**Your Goal**: Create a balanced weekly schedule that:
1. Distributes tasks fairly based on age and capacity
2. Avoids scheduling conflicts with calendar events
3. Maintains variety (rotate tasks among family members)
4. Respects work-life balance (no overloading)

**Fairness Rules**:
- Child (8-10y): Max 120 minutes/week (2 hours)
- Teen (11-17y): Max 240 minutes/week (4 hours)
- Parent: Max 360 minutes/week (6 hours)
- Helper: Not assigned tasks (excluded)

**Task Assignment Strategy**:
1. Check user capacity and current workload
2. Avoid assigning tasks during calendar events
3. Prefer users with lower current workload
4. Consider age-appropriateness (e.g., pet care for older kids)
5. Limit to max 3 tasks per person per day

**Output Format**: Pure JSON (no markdown, no explanation)
{
  "week_plan": [
    {
      "date": "2025-11-17",
      "tasks": [
        {
          "task_id": "uuid-from-context",
          "assignee_id": "uuid-of-user",
          "due_time": "19:00",
          "reasoning": "Brief explanation"
        }
      ]
    }
  ],
  "fairness_notes": "Brief summary of distribution strategy"
}"""

    def _build_planning_prompt(self, context: Dict, start_date: datetime) -> str:
        """Build detailed prompt for AI planner"""
        end_date = start_date + timedelta(days=6)

        prompt = f"""Generate a weekly task plan for this family.

**Week**: {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')} (Monday to Sunday)

**Family Members**:
{self._format_users(context['users'])}

**Recurring Tasks to Assign**:
{self._format_tasks(context['recurring_tasks'])}

**One-Time Tasks**:
{self._format_tasks(context['one_time_tasks'])}

**Calendar Events** (busy times to avoid):
{self._format_events(context['events_this_week'])}

**Past Completion Patterns** (last 4 weeks):
{self._format_completions(context['past_completions'])}

**Instructions**:
1. Assign all recurring task occurrences for the week
2. Respect existing one-time task assignments (if already assigned)
3. Avoid scheduling tasks during calendar events
4. Distribute fairly based on capacity and current workload
5. Use rotation strategies where specified
6. Output pure JSON (no markdown code blocks)

Generate the plan now:"""

        return prompt

    def _format_users(self, users: List[Dict]) -> str:
        """Format users for prompt"""
        lines = []
        for user in users:
            workload_pct = int(user['current_workload'] * 100)
            lines.append(
                f"- {user['name']} (age {user['age']}, {user['role']}): "
                f"Capacity {user['capacity_minutes_per_week']}min/week, "
                f"Current load {workload_pct}%"
            )
        return "\n".join(lines) if lines else "No family members"

    def _format_tasks(self, tasks: List[Dict]) -> str:
        """Format tasks for prompt"""
        if not tasks:
            return "None"

        lines = []
        for task in tasks[:20]:  # Limit to prevent prompt overflow
            lines.append(
                f"- {task['title']} (ID: {task['id']}, {task['est_duration']}min, {task['points']}pts)"
            )
        return "\n".join(lines)

    def _format_events(self, events: List[Dict]) -> str:
        """Format events for prompt"""
        if not events:
            return "None"

        lines = []
        for event in events[:30]:  # Limit
            start_str = datetime.fromisoformat(event['start']).strftime('%a %H:%M')
            attendees = ", ".join([a[:8] for a in event['attendees'][:3]])  # First 3 attendees
            lines.append(f"- {event['title']} on {start_str} (attendees: {attendees})")
        return "\n".join(lines)

    def _format_completions(self, completions: List[Dict]) -> str:
        """Format past completions for pattern analysis"""
        if not completions:
            return "No recent completions"

        # Count completions per user
        user_counts = {}
        for comp in completions:
            user_id = comp.get('completed_by', 'unknown')
            user_counts[user_id] = user_counts.get(user_id, 0) + 1

        lines = [f"- User {uid[:8]}: {count} tasks" for uid, count in user_counts.items()]
        return "\n".join(lines[:10])  # Top 10

    def _parse_ai_response(self, ai_response: Dict, context: Dict) -> Dict[str, Any]:
        """Parse AI JSON response into structured plan"""
        try:
            content = ai_response["choices"][0]["message"]["content"]

            # Extract JSON from response (handle markdown code blocks)
            if "```json" in content:
                start = content.index("```json") + 7
                end = content.rindex("```")
                content = content[start:end].strip()
            elif "```" in content:
                start = content.index("```") + 3
                end = content.rindex("```")
                content = content[start:end].strip()

            plan_data = json.loads(content)

            # Enrich with user names, task titles from context
            for day in plan_data.get("week_plan", []):
                for task_item in day.get("tasks", []):
                    # Look up user name
                    user = next((u for u in context["users"] if u["id"] == task_item.get("assignee_id")), None)
                    if user:
                        task_item["assignee_name"] = user["name"]

                    # Look up task details
                    task_obj = self.db.query(models.Task).filter(
                        models.Task.id == task_item.get("task_id")
                    ).first()

                    if task_obj:
                        task_item["title"] = task_obj.title
                        task_item["points"] = task_obj.points
                        task_item["est_duration"] = task_obj.estDuration
                        task_item["category"] = task_obj.category

            # Add total task count
            total_tasks = sum(len(day.get("tasks", [])) for day in plan_data.get("week_plan", []))
            plan_data["total_tasks"] = total_tasks

            return plan_data

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response as JSON: {e}")
            raise
        except Exception as e:
            logger.error(f"Error parsing AI response: {e}")
            raise

    def fairness_validate_plan(self, plan: Dict, context: Dict) -> Dict:
        """Validate plan meets fairness requirements"""
        # Calculate distribution
        distribution = {}
        total_duration = 0

        for day in plan.get("week_plan", []):
            for task in day.get("tasks", []):
                assignee_id = task.get("assignee_id")
                duration = task.get("est_duration", 15)
                distribution[assignee_id] = distribution.get(assignee_id, 0) + duration
                total_duration += duration

        # Convert to percentages
        if total_duration > 0:
            distribution_pct = {
                uid: minutes / total_duration
                for uid, minutes in distribution.items()
            }
        else:
            distribution_pct = {}

        # Add user names
        distribution_named = {}
        for uid, pct in distribution_pct.items():
            user = next((u for u in context["users"] if u["id"] == uid), None)
            if user:
                distribution_named[user["name"]] = round(pct, 2)

        plan["fairness"] = {
            "distribution": distribution_named,
            "distribution_minutes": distribution,
            "notes": "AI-generated fair distribution"
        }

        return plan

    def _detect_conflicts(self, plan: Dict, context: Dict) -> List[Dict]:
        """Detect conflicts between planned tasks and calendar events"""
        conflicts = []

        # Build events index by date and attendee
        events_by_date_user = {}
        for event in context.get("events_this_week", []):
            event_start = datetime.fromisoformat(event["start"])
            event_end = datetime.fromisoformat(event["end"]) if event.get("end") else event_start + timedelta(hours=1)
            date_str = event_start.date().isoformat()

            for attendee_id in event.get("attendees", []):
                key = f"{date_str}_{attendee_id}"
                if key not in events_by_date_user:
                    events_by_date_user[key] = []
                events_by_date_user[key].append({
                    "title": event["title"],
                    "start": event_start,
                    "end": event_end
                })

        # Check each task
        for day in plan.get("week_plan", []):
            date_str = day["date"]
            for task in day.get("tasks", []):
                assignee_id = task.get("assignee_id")
                due_time = task.get("due_time", "19:00")

                # Construct task due datetime
                task_due = datetime.fromisoformat(f"{date_str}T{due_time}:00")
                task_end = task_due + timedelta(minutes=task.get("est_duration", 15))

                # Check for conflicts
                key = f"{date_str}_{assignee_id}"
                for event in events_by_date_user.get(key, []):
                    # Check time overlap
                    if not (task_end <= event["start"] or task_due >= event["end"]):
                        conflicts.append({
                            "task": task.get("title", "Unknown task"),
                            "event": event["title"],
                            "user": task.get("assignee_name", "Unknown"),
                            "date": date_str,
                            "task_time": due_time,
                            "event_time": event["start"].strftime("%H:%M"),
                            "suggestion": f"Move task to after {event['end'].strftime('%H:%M')}"
                        })

        return conflicts

    def _rule_based_plan(self, context: Dict, start_date: datetime) -> Dict[str, Any]:
        """
        Fallback rule-based planner (deterministic, offline-capable).

        Simple algorithm:
        1. Round-robin assignment
        2. Prefer after-school hours (16:00-20:00)
        3. Avoid event conflicts
        """
        week_plan = []

        # Get all tasks needing assignment
        all_tasks = context["recurring_tasks"] + context["one_time_tasks"]

        # Sort users by current workload (ascending)
        users = sorted(context["users"], key=lambda u: u["current_workload"])

        user_index = 0

        # Generate 7 days
        for day_offset in range(7):
            current_date = (start_date + timedelta(days=day_offset)).date()
            daily_tasks = []

            # Assign tasks for this day (simple round-robin)
            for task in all_tasks[:5]:  # Limit to 5 tasks per day
                if user_index >= len(users):
                    user_index = 0

                user = users[user_index]

                daily_tasks.append({
                    "task_id": task["id"],
                    "title": task["title"],
                    "assignee_id": user["id"],
                    "assignee_name": user["name"],
                    "due_time": "19:00",
                    "points": task["points"],
                    "est_duration": task["est_duration"],
                    "reasoning": "Rule-based round-robin"
                })

                user_index += 1

            week_plan.append({
                "date": current_date.isoformat(),
                "tasks": daily_tasks
            })

        return {
            "week_plan": week_plan,
            "fairness": {
                "distribution": {},
                "notes": "Rule-based fallback (simple round-robin)"
            },
            "conflicts": [],
            "total_tasks": sum(len(d["tasks"]) for d in week_plan)
        }

    def _generate_cache_key(self, context: Dict, start_date: datetime) -> str:
        """Generate cache key from context and date"""
        # Use hash of critical context elements
        import hashlib

        key_data = {
            "family_id": self.family_id,
            "start_date": start_date.isoformat(),
            "user_count": len(context["users"]),
            "task_count": len(context["recurring_tasks"]) + len(context["one_time_tasks"]),
            "event_count": len(context["events_this_week"])
        }

        key_string = json.dumps(key_data, sort_keys=True)
        return f"plan_{hashlib.md5(key_string.encode()).hexdigest()}"

    def _estimate_cost(self, prompt_tokens: int, completion_tokens: int, model: str) -> float:
        """Estimate API cost based on tokens and model"""
        # OpenRouter pricing (approximate)
        if "sonnet" in model.lower():
            # Claude Sonnet: $3/1M input, $15/1M output
            input_cost = (prompt_tokens / 1_000_000) * 3.0
            output_cost = (completion_tokens / 1_000_000) * 15.0
        elif "haiku" in model.lower():
            # Claude Haiku: $0.25/1M input, $1.25/1M output
            input_cost = (prompt_tokens / 1_000_000) * 0.25
            output_cost = (completion_tokens / 1_000_000) * 1.25
        else:
            # Default estimate
            input_cost = (prompt_tokens / 1_000_000) * 1.0
            output_cost = (completion_tokens / 1_000_000) * 2.0

        return round(input_cost + output_cost, 6)
