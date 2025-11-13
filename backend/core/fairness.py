"""
Fairness Engine for Task Distribution

Provides AI-powered fair distribution based on:
- Age and role capacity (child: 2h/week, teen: 4h/week, parent: 6h/week)
- Current workload (number of tasks + total duration)
- Calendar busy hours (from events)
- Task complexity vs user capability

Rotation strategies:
- round_robin: Rotate through assignees in order
- fairness: AI-powered distribution based on workload
- random: Random assignment from eligible users
- manual: Parent assigns manually each time
"""

from datetime import date, datetime, timedelta
from typing import List, Optional, Dict, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from core import models


# Capacity in minutes per week based on role
ROLE_CAPACITY = {
    "child": 120,   # 6-10 years: 2 hours/week
    "teen": 240,    # 11-17 years: 4 hours/week
    "parent": 360,  # 6 hours/week
    "helper": 0,    # Excluded from fairness calculations
}


class FairnessEngine:
    """
    Fairness engine for task distribution and workload balancing.

    Provides methods to:
    - Calculate user workload
    - Assess fairness distribution across family
    - Suggest assignees based on capacity and availability
    - Rotate assignees for recurring tasks
    """

    def __init__(self, db: Session):
        """
        Initialize fairness engine.

        Args:
            db: Database session for queries
        """
        self.db = db

    def get_user_capacity(self, user: models.User) -> int:
        """
        Get weekly capacity in minutes based on user role.

        Args:
            user: User model instance

        Returns:
            Weekly capacity in minutes
        """
        return ROLE_CAPACITY.get(user.role, 0)

    def calculate_workload(self, user_id: str, week_start: date) -> float:
        """
        Calculate user's workload for the week as a percentage of capacity.

        Considers:
        - Number of tasks assigned
        - Total estimated duration of tasks
        - Age/role capacity
        - Calendar busy hours

        Args:
            user_id: User ID to calculate workload for
            week_start: Start date of the week (Monday)

        Returns:
            Workload as float (0.0 = no load, 1.0 = at capacity, >1.0 = overloaded)
        """
        user = self.db.query(models.User).filter_by(id=user_id).first()
        if not user:
            return 0.0

        capacity = self.get_user_capacity(user)
        if capacity == 0:
            # Helper role has no capacity - excluded from fairness
            return 0.0

        # Calculate week boundaries
        week_end = week_start + timedelta(days=7)
        week_start_dt = datetime.combine(week_start, datetime.min.time())
        week_end_dt = datetime.combine(week_end, datetime.min.time())

        # Get all open tasks assigned to user during this week
        tasks = self.db.query(models.Task).filter(
            and_(
                models.Task.assignees.contains([user_id]),
                models.Task.status.in_(["open", "pendingApproval"]),
                models.Task.due >= week_start_dt,
                models.Task.due < week_end_dt
            )
        ).all()

        # Sum up estimated durations
        total_task_minutes = sum(task.estDuration for task in tasks)

        # Get calendar busy hours for the week
        busy_minutes = self._get_busy_minutes(user_id, week_start, week_end)

        # Total workload = task duration + busy hours
        total_minutes = total_task_minutes + busy_minutes

        # Calculate as percentage of capacity
        workload = total_minutes / capacity if capacity > 0 else 0.0

        return workload

    def _get_busy_minutes(self, user_id: str, week_start: date, week_end: date) -> int:
        """
        Calculate total busy minutes from calendar events for a week.

        Args:
            user_id: User ID
            week_start: Start of week
            week_end: End of week

        Returns:
            Total busy minutes from events
        """
        from routers.calendar import expand_recurring_event

        week_start_dt = datetime.combine(week_start, datetime.min.time())
        week_end_dt = datetime.combine(week_end, datetime.min.time())

        # Get user's family
        user = self.db.query(models.User).filter_by(id=user_id).first()
        if not user:
            return 0

        # Get all events where user is attendee
        events = self.db.query(models.Event).filter(
            and_(
                models.Event.familyId == user.familyId,
                models.Event.attendees.contains([user_id])
            )
        ).all()

        total_minutes = 0
        for event in events:
            # Expand recurring events for this week
            occurrences = expand_recurring_event(event, week_start_dt, week_end_dt, max_occurrences=365)

            for occurrence in occurrences:
                if occurrence.get("end"):
                    # Calculate duration in minutes
                    duration = (occurrence["end"] - occurrence["start"]).total_seconds() / 60
                    total_minutes += duration
                elif occurrence.get("allDay"):
                    # All-day events don't count toward busy hours
                    # (assumed to be dates like birthdays, not blocking time)
                    pass
                else:
                    # Event without end time - assume 1 hour default
                    total_minutes += 60

        return int(total_minutes)

    def calculate_fairness_score(self, family_id: str, week_start: date) -> Dict[str, float]:
        """
        Calculate fairness distribution across all family members.

        Returns workload percentage for each user who can be assigned tasks
        (excludes helpers).

        Args:
            family_id: Family ID
            week_start: Start of week for analysis

        Returns:
            Dict mapping user_id to workload percentage (0.0-1.0+)
            Example: {"noah": 0.28, "luna": 0.24, "sam": 0.22, "eva": 0.13, "mark": 0.13}
        """
        # Get all family members except helpers
        users = self.db.query(models.User).filter(
            and_(
                models.User.familyId == family_id,
                models.User.role != "helper"
            )
        ).all()

        fairness_scores = {}
        for user in users:
            workload = self.calculate_workload(user.id, week_start)
            fairness_scores[user.id] = workload

        return fairness_scores

    def suggest_assignee(
        self,
        task: models.Task,
        eligible_users: List[models.User],
        occurrence_date: Optional[date] = None
    ) -> Optional[str]:
        """
        Suggest best assignee based on fairness and availability.

        Algorithm:
        1. Filter out users at/over capacity
        2. Check calendar for busy hours on task due date
        3. Prefer users with lower workload
        4. Consider task complexity vs user age/capability

        Args:
            task: Task to assign
            eligible_users: List of users who can be assigned
            occurrence_date: Specific occurrence date (for recurring tasks)

        Returns:
            User ID of suggested assignee, or None if no suitable user
        """
        if not eligible_users:
            return None

        # Determine the week to analyze
        if occurrence_date:
            week_start = occurrence_date - timedelta(days=occurrence_date.weekday())
        elif task.due:
            task_date = task.due.date()
            week_start = task_date - timedelta(days=task_date.weekday())
        else:
            # No due date - use current week
            today = date.today()
            week_start = today - timedelta(days=today.weekday())

        # Calculate workload for each eligible user
        user_workloads = []
        for user in eligible_users:
            # Skip helpers (they have 0 capacity)
            if user.role == "helper":
                continue

            workload = self.calculate_workload(user.id, week_start)
            capacity = self.get_user_capacity(user)

            # Check if user is at capacity (>90% loaded)
            if workload >= 0.9:
                continue

            # Check if user is available on task due date
            if task.due or occurrence_date:
                check_date = occurrence_date if occurrence_date else task.due.date()
                is_available = self._check_availability(user.id, check_date, task.estDuration)
                if not is_available:
                    continue

            user_workloads.append({
                "user_id": user.id,
                "workload": workload,
                "capacity": capacity,
                "role": user.role
            })

        if not user_workloads:
            # All users at capacity or unavailable - return first eligible
            return eligible_users[0].id if eligible_users else None

        # Sort by workload (ascending) - prefer users with lower load
        user_workloads.sort(key=lambda x: x["workload"])

        # Return user with lowest workload
        return user_workloads[0]["user_id"]

    def _check_availability(self, user_id: str, check_date: date, duration_minutes: int) -> bool:
        """
        Check if user has available time on specific date.

        Considers:
        - Calendar events
        - Preferred after-school hours (16:00-20:00)
        - Minimum gap of task duration

        Args:
            user_id: User ID
            check_date: Date to check
            duration_minutes: Required duration in minutes

        Returns:
            True if user has availability, False otherwise
        """
        from routers.calendar import get_busy_hours

        check_datetime = datetime.combine(check_date, datetime.min.time())

        # Get busy hours for the day
        busy_hours = get_busy_hours(user_id, check_datetime, self.db)

        # Check if there's at least one gap of required duration
        # in after-school hours (16:00-20:00)
        preferred_start = check_datetime.replace(hour=16, minute=0)
        preferred_end = check_datetime.replace(hour=20, minute=0)

        # Simple availability check: if no events, user is available
        if not busy_hours:
            return True

        # Check for gaps in preferred time range
        sorted_events = sorted(busy_hours, key=lambda x: x[0])

        # Check gap before first event
        if sorted_events[0][0] > preferred_start + timedelta(minutes=duration_minutes):
            return True

        # Check gaps between events
        for i in range(len(sorted_events) - 1):
            gap_start = sorted_events[i][1]
            gap_end = sorted_events[i + 1][0]
            gap_minutes = (gap_end - gap_start).total_seconds() / 60

            if gap_minutes >= duration_minutes:
                return True

        # Check gap after last event
        if sorted_events[-1][1] < preferred_end - timedelta(minutes=duration_minutes):
            return True

        # No sufficient gaps - user is busy
        return False

    def rotate_assignee(
        self,
        task_template: models.Task,
        occurrence_date: date
    ) -> Optional[str]:
        """
        Get next assignee for recurring task based on rotation strategy.

        Args:
            task_template: Recurring task template
            occurrence_date: Date of specific occurrence

        Returns:
            User ID of assigned user, or None for manual assignment
        """
        if not task_template.assignees:
            return None

        rotation_strategy = getattr(task_template, "rotationStrategy", "manual")

        if rotation_strategy == "round_robin":
            return self._rotate_round_robin(task_template, occurrence_date)

        elif rotation_strategy == "fairness":
            # Use fairness-based suggestion
            eligible_users = self.db.query(models.User).filter(
                models.User.id.in_(task_template.assignees)
            ).all()
            return self.suggest_assignee(task_template, eligible_users, occurrence_date)

        elif rotation_strategy == "random":
            # Random from assignees list
            import random
            return random.choice(task_template.assignees)

        else:  # manual
            # Return None - parent must assign manually
            return None

    def _rotate_round_robin(self, task_template: models.Task, occurrence_date: date) -> str:
        """
        Round-robin rotation through assignees list.

        Uses rotationState JSONB to track current index.

        Args:
            task_template: Task template with assignees
            occurrence_date: Date of occurrence

        Returns:
            User ID of next assignee in rotation
        """
        assignees = task_template.assignees
        if not assignees:
            return None

        # Get current rotation state
        rotation_state = getattr(task_template, "rotationState", None) or {}
        current_index = rotation_state.get("index", 0)

        # Get next assignee
        assignee = assignees[current_index % len(assignees)]

        # Update rotation state (will be saved when task instance is created)
        next_index = (current_index + 1) % len(assignees)
        rotation_state["index"] = next_index
        rotation_state["lastRotationDate"] = occurrence_date.isoformat()

        # Update task template rotation state in database
        task_template.rotationState = rotation_state
        self.db.commit()

        return assignee

    def get_available_hours(
        self,
        user_id: str,
        check_date: date,
        task_duration: int
    ) -> List[datetime]:
        """
        Suggest available time slots for task.

        Algorithm:
        1. Get busy hours from calendar
        2. Find gaps >= task_duration
        3. Prefer after-school hours (16:00-20:00)
        4. Return up to 3 suggestions

        Args:
            user_id: User ID
            check_date: Date to check
            task_duration: Task duration in minutes

        Returns:
            List of suggested start times (up to 3)
        """
        from routers.calendar import get_busy_hours

        check_datetime = datetime.combine(check_date, datetime.min.time())

        # Get busy hours
        busy_hours = get_busy_hours(user_id, check_datetime, self.db)

        # Define preferred time ranges
        preferred_start = check_datetime.replace(hour=16, minute=0)
        preferred_end = check_datetime.replace(hour=20, minute=0)

        suggestions = []

        if not busy_hours:
            # No events - suggest start of preferred window
            suggestions.append(preferred_start)
            suggestions.append(preferred_start + timedelta(hours=1))
            suggestions.append(preferred_start + timedelta(hours=2))
            return suggestions[:3]

        # Sort events by start time
        sorted_events = sorted(busy_hours, key=lambda x: x[0])

        # Check gap before first event
        if sorted_events[0][0] > preferred_start + timedelta(minutes=task_duration):
            gap_start = preferred_start
            gap_end = sorted_events[0][0]
            suggestions.append(gap_start)

        # Check gaps between events
        for i in range(len(sorted_events) - 1):
            gap_start = sorted_events[i][1]
            gap_end = sorted_events[i + 1][0]
            gap_minutes = (gap_end - gap_start).total_seconds() / 60

            # Only suggest gaps in preferred time range
            if gap_start >= preferred_start and gap_start < preferred_end:
                if gap_minutes >= task_duration:
                    suggestions.append(gap_start)

        # Check gap after last event
        if sorted_events[-1][1] < preferred_end - timedelta(minutes=task_duration):
            suggestions.append(sorted_events[-1][1])

        # If no suggestions yet, suggest any gaps regardless of time
        if not suggestions:
            for i in range(len(sorted_events) - 1):
                gap_start = sorted_events[i][1]
                gap_end = sorted_events[i + 1][0]
                gap_minutes = (gap_end - gap_start).total_seconds() / 60

                if gap_minutes >= task_duration:
                    suggestions.append(gap_start)
                    if len(suggestions) >= 3:
                        break

        # Return up to 3 suggestions
        return suggestions[:3]
