"""
Rule-based planner (Tier 3 fallback)
Deterministic task distribution using fairness algorithm
Zero cost, offline-capable
"""
from typing import Dict, List, Any
from datetime import datetime, timedelta
import random

def rule_based_plan(week_context: Dict[str, Any]) -> Dict[str, Any]:
    """
    Generate weekly plan using deterministic rules

    Args:
        week_context: {
            "familyMembers": [{"id": "uuid", "name": "Noah", "age": 10, "role": "child"}],
            "tasks": [{"title": "Vaatwasser", "points": 10, "frequency": "daily"}],
            "calendar": [{"date": "2025-11-17", "events": ["School 9-15"]}],
            "constraints": {"maxTasksPerDay": 3}
        }

    Returns:
        {
            "weekPlan": [...],
            "fairness": {"distribution": {...}, "notes": "..."}
        }
    """
    members = week_context.get("familyMembers", [])
    tasks = week_context.get("tasks", [])
    calendar = week_context.get("calendar", [])
    constraints = week_context.get("constraints", {})

    max_tasks_per_day = constraints.get("maxTasksPerDay", 3)

    # Filter eligible members (exclude very young children, external help)
    eligible_members = [
        m for m in members
        if m.get("role") in ["child", "teen", "parent"] and m.get("age", 0) >= 6
    ]

    if not eligible_members or not tasks:
        return _empty_plan()

    # Calculate workload capacity by age/role
    workload_weights = _calculate_workload_weights(eligible_members)

    # Generate 7-day plan starting today
    today = datetime.utcnow().date()
    week_plan = []

    for day_offset in range(7):
        date = today + timedelta(days=day_offset)
        date_str = date.isoformat()

        # Get calendar events for this day
        day_events = _get_day_events(calendar, date_str)

        # Distribute tasks fairly
        day_tasks = _distribute_daily_tasks(
            tasks,
            eligible_members,
            workload_weights,
            day_events,
            max_tasks_per_day
        )

        week_plan.append({
            "date": date_str,
            "tasks": day_tasks
        })

    # Calculate fairness distribution
    fairness = _calculate_fairness(week_plan, eligible_members)

    return {
        "weekPlan": week_plan,
        "fairness": fairness
    }

def _calculate_workload_weights(members: List[Dict]) -> Dict[str, float]:
    """Calculate relative workload capacity by age/role"""
    weights = {}
    for member in members:
        age = member.get("age", 18)
        role = member.get("role", "child")

        # Base weight by role
        if role == "parent":
            base_weight = 0.3  # Parents do less household chores
        elif role == "teen":
            base_weight = 1.0
        else:  # child
            base_weight = 0.8

        # Age adjustment (younger = less capacity)
        if age < 8:
            age_factor = 0.5
        elif age < 12:
            age_factor = 0.7
        elif age < 16:
            age_factor = 0.9
        else:
            age_factor = 1.0

        weights[member["id"]] = base_weight * age_factor

    return weights

def _get_day_events(calendar: List[Dict], date_str: str) -> List[str]:
    """Get events for specific date"""
    for day in calendar:
        if day.get("date") == date_str:
            return day.get("events", [])
    return []

def _distribute_daily_tasks(
    tasks: List[Dict],
    members: List[Dict],
    workload_weights: Dict[str, float],
    day_events: List[str],
    max_tasks: int
) -> List[Dict]:
    """Distribute tasks for a single day"""
    daily_tasks = []

    # Filter members who are available (not on vacation/training day)
    available_members = [
        m for m in members
        if not any("vacation" in event.lower() or "training" in event.lower()
                   for event in day_events)
    ]

    if not available_members:
        available_members = members  # Fallback if all unavailable

    # Sort members by workload capacity (descending)
    sorted_members = sorted(
        available_members,
        key=lambda m: workload_weights.get(m["id"], 0.5),
        reverse=True
    )

    # Round-robin assignment
    member_index = 0
    for task in tasks[:max_tasks]:
        assignee = sorted_members[member_index % len(sorted_members)]

        daily_tasks.append({
            "title": task["title"],
            "assignee": assignee["id"],
            "assigneeName": assignee["name"],
            "due": f"{datetime.utcnow().isoformat()}Z",  # Today
            "points": task.get("points", 10)
        })

        member_index += 1

    return daily_tasks

def _calculate_fairness(week_plan: List[Dict], members: List[Dict]) -> Dict[str, Any]:
    """Calculate fairness distribution across week"""
    task_counts = {m["id"]: 0 for m in members}
    total_points = {m["id"]: 0 for m in members}

    total_tasks = 0
    for day in week_plan:
        for task in day["tasks"]:
            assignee_id = task["assignee"]
            if assignee_id in task_counts:
                task_counts[assignee_id] += 1
                total_points[assignee_id] += task.get("points", 10)
                total_tasks += 1

    # Calculate distribution percentages
    distribution = {}
    for member in members:
        member_id = member["id"]
        if total_tasks > 0:
            distribution[member["name"]] = round(task_counts[member_id] / total_tasks, 2)
        else:
            distribution[member["name"]] = 0.0

    return {
        "distribution": distribution,
        "notes": "Rule-based fair distribution by age and role"
    }

def _empty_plan() -> Dict[str, Any]:
    """Return empty plan when no tasks or members"""
    today = datetime.utcnow().date()
    return {
        "weekPlan": [
            {"date": (today + timedelta(days=i)).isoformat(), "tasks": []}
            for i in range(7)
        ],
        "fairness": {
            "distribution": {},
            "notes": "No tasks or family members to distribute"
        }
    }
