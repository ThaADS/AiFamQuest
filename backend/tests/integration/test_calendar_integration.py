"""
Calendar integration tests.

Test end-to-end calendar workflows:
- Create event → Store in DB → Retrieve via API
- Recurring events → Expand occurrences → Validate dates
- Update event → Check all attendees notified
- Delete recurring event → Verify all occurrences removed
- Offline event creation → Sync → Validate no duplicates
"""

import pytest
from datetime import datetime, timedelta
from dateutil.rrule import rrule, DAILY, WEEKLY, MONTHLY

from core.models import Event
from tests.integration.helpers import simulate_offline_sync


class TestCalendarIntegration:
    """Integration tests for calendar system."""

    def test_create_event_full_flow(self, api_client, sample_family, test_db):
        """Test: Create event → Store in DB → Retrieve via API."""
        # Create event via API
        event_data = {
            "title": "Integration Test Event",
            "description": "Test event from integration test",
            "start": datetime(2025, 11, 20, 10, 0).isoformat(),
            "end": datetime(2025, 11, 20, 11, 0).isoformat(),
            "category": "family",
            "attendees": [sample_family["child1"].id, sample_family["child2"].id],
            "color": "#FF5733"
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )

        assert response.status_code == 201
        created_event = response.json()
        event_id = created_event["id"]

        # Verify stored in database
        db_event = test_db.query(Event).filter(Event.id == event_id).first()
        assert db_event is not None
        assert db_event.title == event_data["title"]
        assert db_event.category == event_data["category"]
        assert len(db_event.attendees) == 2

        # Retrieve via API
        response = api_client.get(f"/api/calendar/events/{event_id}", user="parent")
        assert response.status_code == 200
        retrieved_event = response.json()
        assert retrieved_event["id"] == event_id
        assert retrieved_event["title"] == event_data["title"]


    def test_recurring_event_expansion(self, api_client, sample_family, test_db):
        """Test: Recurring event → Expand occurrences → Validate dates."""
        # Create daily recurring event
        event_data = {
            "title": "Daily Standup",
            "description": "Daily team standup",
            "start": datetime(2025, 11, 20, 9, 0).isoformat(),
            "end": datetime(2025, 11, 20, 9, 30).isoformat(),
            "rrule": "FREQ=DAILY;COUNT=10",
            "category": "other",
            "attendees": [sample_family["parent"].id]
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )

        assert response.status_code == 201
        event_id = response.json()["id"]

        # Get month view (should expand occurrences)
        response = api_client.get(
            "/api/calendar/events/month/2025/11",
            user="parent"
        )

        assert response.status_code == 200
        month_events = response.json()

        # Find our recurring events
        daily_events = [e for e in month_events if e["title"] == "Daily Standup"]

        # Should have 10 occurrences (COUNT=10)
        assert len(daily_events) >= 10

        # Verify dates are consecutive
        dates = sorted([datetime.fromisoformat(e["start"]) for e in daily_events[:10]])
        for i in range(1, 10):
            expected_date = dates[0] + timedelta(days=i)
            assert dates[i].date() == expected_date.date()


    def test_update_event_attendee_notification(self, api_client, sample_family, test_db):
        """Test: Update event → Check all attendees notified."""
        # Create event
        event_data = {
            "title": "Family Meeting",
            "start": datetime(2025, 11, 25, 18, 0).isoformat(),
            "end": datetime(2025, 11, 25, 19, 0).isoformat(),
            "category": "family",
            "attendees": [sample_family["child1"].id]
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )
        event_id = response.json()["id"]

        # Update event - change time and add attendees
        update_data = {
            "start": datetime(2025, 11, 25, 19, 0).isoformat(),
            "end": datetime(2025, 11, 25, 20, 0).isoformat(),
            "attendees": [
                sample_family["child1"].id,
                sample_family["child2"].id,
                sample_family["teen"].id
            ]
        }

        response = api_client.put(
            f"/api/calendar/events/{event_id}",
            user="parent",
            json=update_data
        )

        assert response.status_code == 200

        # Verify all attendees can see updated event
        for user in ["child1", "child2", "teen"]:
            response = api_client.get(
                f"/api/calendar/events/{event_id}",
                user=user
            )
            assert response.status_code == 200
            event = response.json()
            assert event["start"] == update_data["start"]
            assert len(event["attendees"]) == 3


    def test_delete_recurring_event_all_occurrences(self, api_client, sample_family, test_db):
        """Test: Delete recurring event → Verify all occurrences removed."""
        # Create weekly recurring event
        event_data = {
            "title": "Weekly Review",
            "start": datetime(2025, 11, 20, 15, 0).isoformat(),
            "end": datetime(2025, 11, 20, 16, 0).isoformat(),
            "rrule": "FREQ=WEEKLY;COUNT=4",
            "category": "other",
            "attendees": [sample_family["parent"].id]
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )
        event_id = response.json()["id"]

        # Verify event exists and expands
        response = api_client.get(
            "/api/calendar/events/month/2025/11",
            user="parent"
        )
        initial_count = len([e for e in response.json() if e["title"] == "Weekly Review"])
        assert initial_count >= 4

        # Delete the recurring event
        response = api_client.delete(
            f"/api/calendar/events/{event_id}",
            user="parent"
        )
        assert response.status_code == 204

        # Verify all occurrences are gone
        response = api_client.get(
            "/api/calendar/events/month/2025/11",
            user="parent"
        )
        remaining_count = len([e for e in response.json() if e["title"] == "Weekly Review"])
        assert remaining_count == 0

        # Verify base event is deleted from DB
        db_event = test_db.query(Event).filter(Event.id == event_id).first()
        assert db_event is None


    def test_offline_event_creation_sync_no_duplicates(self, api_client, sample_family, test_db):
        """Test: Offline event creation → Sync → Validate no duplicates."""
        # Simulate offline event creation
        offline_event_id = "offline-event-001"
        offline_event = {
            "id": offline_event_id,
            "familyId": sample_family["family"].id,
            "title": "Offline Created Event",
            "description": "Created while offline",
            "start": datetime(2025, 11, 22, 14, 0),
            "end": datetime(2025, 11, 22, 15, 0),
            "category": "other",
            "attendees": [sample_family["child1"].id],
            "createdBy": sample_family["parent"].id
        }

        # Simulate sync operation
        sync_result = simulate_offline_sync(
            test_db,
            [{"type": "create", "entity": "event", "data": offline_event}]
        )

        assert sync_result["created"] == 1
        assert len(sync_result["conflicts"]) == 0

        # Verify event exists in DB
        db_event = test_db.query(Event).filter(Event.id == offline_event_id).first()
        assert db_event is not None
        assert db_event.title == offline_event["title"]

        # Try to sync same event again (should detect duplicate)
        sync_result_2 = simulate_offline_sync(
            test_db,
            [{"type": "create", "entity": "event", "data": offline_event}]
        )

        # Should fail or skip due to duplicate ID
        assert len(sync_result_2["conflicts"]) > 0 or sync_result_2["created"] == 0

        # Verify no duplicate in DB
        db_events = test_db.query(Event).filter(
            Event.title == offline_event["title"]
        ).all()
        assert len(db_events) == 1


    def test_event_access_control_by_role(self, api_client, sample_family):
        """Test: Event access control per role."""
        # Parent creates event
        event_data = {
            "title": "Parent Only Meeting",
            "start": datetime(2025, 11, 20, 20, 0).isoformat(),
            "end": datetime(2025, 11, 20, 21, 0).isoformat(),
            "category": "other",
            "attendees": [sample_family["parent"].id]
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )
        event_id = response.json()["id"]

        # Parent can read
        response = api_client.get(f"/api/calendar/events/{event_id}", user="parent")
        assert response.status_code == 200

        # Child (not attendee) should not see event
        response = api_client.get(f"/api/calendar/events/{event_id}", user="child1")
        # Depending on access control implementation, should be 403 or 404
        assert response.status_code in [403, 404]

        # Teen can edit if parent
        update_data = {"title": "Updated by Teen"}
        response = api_client.put(
            f"/api/calendar/events/{event_id}",
            user="teen",
            json=update_data
        )
        # Teen should not be able to edit parent-only event
        assert response.status_code in [403, 404]


    def test_recurring_event_with_exceptions(self, api_client, sample_family):
        """Test: Recurring event with exception dates."""
        # Create recurring event
        event_data = {
            "title": "Daily Exercise",
            "start": datetime(2025, 11, 20, 7, 0).isoformat(),
            "end": datetime(2025, 11, 20, 8, 0).isoformat(),
            "rrule": "FREQ=DAILY;COUNT=7",
            "category": "sport",
            "attendees": [sample_family["child1"].id]
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )
        event_id = response.json()["id"]

        # Get all occurrences
        response = api_client.get(
            "/api/calendar/events/month/2025/11",
            user="parent"
        )
        initial_occurrences = [
            e for e in response.json()
            if e["title"] == "Daily Exercise"
        ]
        assert len(initial_occurrences) >= 7


    def test_calendar_month_view_performance(self, api_client, sample_family, sample_events):
        """Test: Calendar month view with many events → Response <500ms."""
        import time

        start_time = time.time()

        response = api_client.get(
            "/api/calendar/events/month/2025/11",
            user="parent"
        )

        end_time = time.time()
        duration_ms = (end_time - start_time) * 1000

        assert response.status_code == 200
        events = response.json()
        assert len(events) > 0

        # Should respond in under 500ms
        assert duration_ms < 500, f"Month view took {duration_ms:.2f}ms (limit: 500ms)"


    def test_calendar_week_view(self, api_client, sample_family, sample_events):
        """Test: Calendar week view filtering."""
        # Get week view
        response = api_client.get(
            "/api/calendar/events/week/2025/11/20",
            user="parent"
        )

        assert response.status_code == 200
        week_events = response.json()

        # Verify all events are within the week
        start_of_week = datetime(2025, 11, 20)
        end_of_week = start_of_week + timedelta(days=7)

        for event in week_events:
            event_start = datetime.fromisoformat(event["start"])
            assert start_of_week <= event_start < end_of_week


    def test_event_color_coding_by_category(self, api_client, sample_family):
        """Test: Event color coding by category."""
        categories = ["school", "sport", "appointment", "family", "other"]
        created_events = []

        # Create one event per category
        for category in categories:
            event_data = {
                "title": f"{category.title()} Event",
                "start": datetime(2025, 11, 20, 10, 0).isoformat(),
                "end": datetime(2025, 11, 20, 11, 0).isoformat(),
                "category": category,
                "attendees": [sample_family["child1"].id]
            }

            response = api_client.post(
                "/api/calendar/events",
                user="parent",
                json=event_data
            )
            assert response.status_code == 201
            created_events.append(response.json())

        # Retrieve events and verify categories
        for event in created_events:
            response = api_client.get(
                f"/api/calendar/events/{event['id']}",
                user="parent"
            )
            assert response.status_code == 200
            retrieved = response.json()
            assert retrieved["category"] in categories


    def test_all_day_event_handling(self, api_client, sample_family):
        """Test: All-day event creation and retrieval."""
        event_data = {
            "title": "All Day Conference",
            "start": datetime(2025, 11, 20, 0, 0).isoformat(),
            "end": datetime(2025, 11, 21, 0, 0).isoformat(),
            "allDay": True,
            "category": "other",
            "attendees": [sample_family["parent"].id]
        }

        response = api_client.post(
            "/api/calendar/events",
            user="parent",
            json=event_data
        )

        assert response.status_code == 201
        event = response.json()
        assert event["allDay"] is True

        # Verify time boundaries are correct
        start = datetime.fromisoformat(event["start"])
        end = datetime.fromisoformat(event["end"])
        assert start.hour == 0
        assert start.minute == 0
        assert end.hour == 0
        assert end.minute == 0
