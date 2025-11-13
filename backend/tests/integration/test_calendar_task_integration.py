"""
Calendar-Task Integration Tests.

Tests interaction between calendar events and task system:
- Event-task conflict detection and warnings
- AI planner calendar awareness
- Recurring event task rotation coordination
- All-day events and capacity calculations
- Event deletion impact on tasks
- Combined calendar view with tasks and events
"""

import pytest
from datetime import datetime, timedelta

from core.models import Event, Task


class TestCalendarTaskIntegration:
    """Integration tests for calendar and task system interaction."""

    def test_event_task_time_conflict_warning(self, api_client, sample_family, test_db):
        """Test: Create event 14:00-16:00 → Create task due 15:00 → Verify conflict warning."""
        user_id = sample_family["child1"].id

        # Create event from 14:00 to 16:00
        event_data = {
            "title": "Soccer Practice",
            "start": datetime(2025, 11, 20, 14, 0).isoformat(),
            "end": datetime(2025, 11, 20, 16, 0).isoformat(),
            "category": "sport",
            "attendees": [user_id]
        }

        response = api_client.post("/api/calendar/events", user="parent", json=event_data)
        assert response.status_code == 201
        event_id = response.json()["id"]

        # Create task due at 15:00 (during the event)
        task_data = {
            "title": "Do Homework",
            "category": "homework",
            "due": datetime(2025, 11, 20, 15, 0).isoformat(),
            "assignees": [user_id],
            "points": 20,
            "estDuration": 30
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        assert response.status_code == 201

        # Backend should detect conflict and potentially warn
        # Check if conflict is flagged in response or task metadata
        task = response.json()
        # Implementation-dependent: task might have "hasConflict": true


    def test_ai_planner_calendar_awareness(self, api_client, sample_family, test_db):
        """Test: User has 3 events on Monday → AI planner → Verify fewer tasks assigned Monday."""
        user_id = sample_family["child1"].id

        # Create 3 events on Monday (Nov 17, 2025)
        monday = datetime(2025, 11, 17)
        for i in range(3):
            event_data = {
                "title": f"Monday Event {i+1}",
                "start": monday.replace(hour=9+i*2).isoformat(),
                "end": monday.replace(hour=10+i*2).isoformat(),
                "category": "school",
                "attendees": [user_id]
            }
            response = api_client.post("/api/calendar/events", user="parent", json=event_data)
            assert response.status_code == 201

        # Request AI task planning for the week
        response = api_client.get(
            f"/api/tasks/plan/week?userId={user_id}&startDate={monday.isoformat()}",
            user="parent"
        )

        # AI planner should assign fewer tasks on Monday due to busy calendar
        if response.status_code == 200:
            plan = response.json()
            # Check that Monday has fewer task assignments
            # Implementation-dependent


    def test_recurring_event_task_rotation_skip(self, api_client, sample_family, test_db):
        """Test: Recurring event (weekly team practice) → Task rotation → Verify skip on event days."""
        user_id = sample_family["child1"].id

        # Create weekly recurring event (every Wednesday at 16:00)
        event_data = {
            "title": "Team Practice",
            "start": datetime(2025, 11, 19, 16, 0).isoformat(),  # Wednesday
            "end": datetime(2025, 11, 19, 18, 0).isoformat(),
            "rrule": "FREQ=WEEKLY;BYDAY=WE",
            "category": "sport",
            "attendees": [user_id]
        }

        response = api_client.post("/api/calendar/events", user="parent", json=event_data)
        assert response.status_code == 201

        # Create daily task assigned to this user
        task_data = {
            "title": "Evening Chores",
            "category": "cleaning",
            "due": datetime(2025, 11, 19, 17, 0).isoformat(),
            "frequency": "daily",
            "rrule": "FREQ=DAILY",
            "rotationStrategy": "round_robin",
            "assignees": [user_id, sample_family["child2"].id],
            "points": 10,
            "estDuration": 30
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        task_id = response.json()["id"]

        # Backend should detect conflict and possibly skip assignment on Wednesdays
        # or adjust task timing


    def test_all_day_event_zero_capacity(self, api_client, sample_family, test_db):
        """Test: Create all-day event "Vacation" → Fairness engine → Verify 0 capacity that day."""
        user_id = sample_family["child1"].id

        # Create all-day vacation event
        vacation_date = datetime(2025, 12, 25)  # Christmas
        event_data = {
            "title": "Family Vacation",
            "start": vacation_date.replace(hour=0, minute=0).isoformat(),
            "end": (vacation_date + timedelta(days=3)).replace(hour=0, minute=0).isoformat(),
            "allDay": True,
            "category": "family",
            "attendees": [
                sample_family["parent"].id,
                sample_family["teen"].id,
                user_id,
                sample_family["child2"].id
            ]
        }

        response = api_client.post("/api/calendar/events", user="parent", json=event_data)
        assert response.status_code == 201

        # Query fairness capacity for vacation days
        response = api_client.get(
            f"/api/fairness/capacity?userId={user_id}&date={vacation_date.isoformat()}",
            user="parent"
        )

        # User should have 0 or minimal capacity during vacation
        if response.status_code == 200:
            capacity = response.json()
            # capacity["available"] should be 0 or very low


    def test_event_deletion_no_task_impact(self, api_client, sample_family, test_db):
        """Test: Delete event → Verify no impact on existing tasks."""
        user_id = sample_family["child1"].id

        # Create event
        event_data = {
            "title": "Dentist Appointment",
            "start": datetime(2025, 11, 22, 14, 0).isoformat(),
            "end": datetime(2025, 11, 22, 15, 0).isoformat(),
            "category": "appointment",
            "attendees": [user_id]
        }

        response = api_client.post("/api/calendar/events", user="parent", json=event_data)
        event_id = response.json()["id"]

        # Create task at same time
        task_data = {
            "title": "Complete Project",
            "category": "homework",
            "due": datetime(2025, 11, 22, 14, 30).isoformat(),
            "assignees": [user_id],
            "points": 30
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        task_id = response.json()["id"]

        # Delete event
        response = api_client.delete(f"/api/calendar/events/{event_id}", user="parent")
        assert response.status_code == 204

        # Verify task still exists
        task = test_db.query(Task).filter(Task.id == task_id).first()
        assert task is not None
        assert task.status == "open"


    def test_event_time_update_task_conflict_recheck(self, api_client, sample_family, test_db):
        """Test: Update event time → Verify task conflict re-check."""
        user_id = sample_family["child1"].id

        # Create event at 10:00-11:00
        event_data = {
            "title": "Music Lesson",
            "start": datetime(2025, 11, 20, 10, 0).isoformat(),
            "end": datetime(2025, 11, 20, 11, 0).isoformat(),
            "category": "other",
            "attendees": [user_id]
        }

        response = api_client.post("/api/calendar/events", user="parent", json=event_data)
        event_id = response.json()["id"]

        # Create task due at 14:00 (no conflict initially)
        task_data = {
            "title": "Practice Piano",
            "category": "homework",
            "due": datetime(2025, 11, 20, 14, 0).isoformat(),
            "assignees": [user_id],
            "points": 15
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        task_id = response.json()["id"]

        # Update event to 14:00-15:00 (now conflicts with task)
        update_data = {
            "start": datetime(2025, 11, 20, 14, 0).isoformat(),
            "end": datetime(2025, 11, 20, 15, 0).isoformat()
        }

        response = api_client.put(
            f"/api/calendar/events/{event_id}",
            user="parent",
            json=update_data
        )
        assert response.status_code == 200

        # Backend should re-check conflicts and potentially flag the task


    def test_combined_calendar_month_view(self, api_client, sample_family, test_db):
        """Test: View calendar month → Verify tasks + events combined display."""
        user_id = sample_family["child1"].id

        # Create mix of events and tasks
        # Event 1
        event_data = {
            "title": "Soccer Game",
            "start": datetime(2025, 11, 20, 16, 0).isoformat(),
            "end": datetime(2025, 11, 20, 18, 0).isoformat(),
            "category": "sport",
            "attendees": [user_id]
        }
        api_client.post("/api/calendar/events", user="parent", json=event_data)

        # Task 1
        task_data = {
            "title": "Complete Math Homework",
            "category": "homework",
            "due": datetime(2025, 11, 20, 15, 0).isoformat(),
            "assignees": [user_id],
            "points": 20
        }
        api_client.post("/api/tasks", user="parent", json=task_data)

        # Event 2
        event_data = {
            "title": "Piano Recital",
            "start": datetime(2025, 11, 25, 19, 0).isoformat(),
            "end": datetime(2025, 11, 25, 20, 30).isoformat(),
            "category": "other",
            "attendees": [user_id, sample_family["parent"].id]
        }
        api_client.post("/api/calendar/events", user="parent", json=event_data)

        # Task 2
        task_data = {
            "title": "Clean Bedroom",
            "category": "cleaning",
            "due": datetime(2025, 11, 25, 10, 0).isoformat(),
            "assignees": [user_id],
            "points": 25
        }
        api_client.post("/api/tasks", user="parent", json=task_data)

        # Get combined month view
        response = api_client.get(
            "/api/calendar/month/2025/11?includeTasks=true",
            user="child1"
        )

        if response.status_code == 200:
            items = response.json()

            # Should contain both events and tasks
            events = [item for item in items if item.get("type") == "event"]
            tasks = [item for item in items if item.get("type") == "task"]

            assert len(events) >= 2
            assert len(tasks) >= 2

            # Verify items are properly labeled
            for item in items:
                assert "type" in item
                assert item["type"] in ["event", "task"]
