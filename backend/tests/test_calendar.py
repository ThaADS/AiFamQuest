"""
Comprehensive test suite for Calendar & Events API

Tests cover:
- CRUD operations for events
- Recurring event expansion (daily, weekly, monthly)
- Access control (parent/teen/child/helper)
- Filtering by user, category, date range
- Month and week views
- RRULE validation
- Attendee validation
- Edge cases and error handling
"""

import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from uuid import uuid4

from core.db import Base
from core import models
from main import app
from core.security import create_token

# Test database setup
TEST_DATABASE_URL = "sqlite:///./test_calendar.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)

client = TestClient(app)


@pytest.fixture
def db_session():
    """Create test database session"""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def test_family(db_session):
    """Create test family"""
    family = models.Family(
        id=str(uuid4()),
        name="Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
    )
    db_session.add(family)
    db_session.commit()
    return family


@pytest.fixture
def parent_user(db_session, test_family):
    """Create parent user"""
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="parent@test.com",
        displayName="Parent User",
        role="parent",
        locale="nl",
        theme="minimal",
    )
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def teen_user(db_session, test_family):
    """Create teen user"""
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="teen@test.com",
        displayName="Teen User",
        role="teen",
        locale="nl",
        theme="minimal",
    )
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def child_user(db_session, test_family):
    """Create child user"""
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="child@test.com",
        displayName="Child User",
        role="child",
        locale="nl",
        theme="cartoony",
    )
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def helper_user(db_session, test_family):
    """Create helper user"""
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="helper@test.com",
        displayName="Helper User",
        role="helper",
        locale="nl",
        theme="minimal",
    )
    db_session.add(user)
    db_session.commit()
    return user


def get_auth_header(user):
    """Generate auth header for user"""
    token = create_token(user.id, user.role)
    return {"Authorization": f"Bearer {token}"}


class TestEventCreation:
    """Test event creation operations"""

    def test_create_single_event_as_parent(self, db_session, parent_user, child_user):
        """Parent can create single event"""
        headers = get_auth_header(parent_user)
        event_data = {
            "title": "Soccer Practice",
            "description": "Weekly soccer practice",
            "start": (datetime.utcnow() + timedelta(days=1)).isoformat(),
            "end": (datetime.utcnow() + timedelta(days=1, hours=1)).isoformat(),
            "allDay": False,
            "attendees": [child_user.id],
            "color": "#FF5733",
            "category": "sport",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Soccer Practice"
        assert data["category"] == "sport"
        assert child_user.id in data["attendees"]

    def test_create_recurring_event_daily(self, db_session, parent_user):
        """Create daily recurring event"""
        headers = get_auth_header(parent_user)
        event_data = {
            "title": "Morning Routine",
            "description": "Daily morning tasks",
            "start": datetime.utcnow().replace(hour=7, minute=0).isoformat(),
            "end": datetime.utcnow().replace(hour=8, minute=0).isoformat(),
            "allDay": False,
            "attendees": [parent_user.id],
            "rrule": "FREQ=DAILY",
            "category": "family",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["rrule"] == "FREQ=DAILY"

    def test_create_recurring_event_weekly(self, db_session, parent_user):
        """Create weekly recurring event on specific days"""
        headers = get_auth_header(parent_user)
        event_data = {
            "title": "Swimming Lessons",
            "description": "Monday and Wednesday swimming",
            "start": datetime.utcnow().isoformat(),
            "end": (datetime.utcnow() + timedelta(hours=1)).isoformat(),
            "allDay": False,
            "attendees": [parent_user.id],
            "rrule": "FREQ=WEEKLY;BYDAY=MO,WE",
            "category": "sport",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert "BYDAY=MO,WE" in data["rrule"]

    def test_create_event_as_teen(self, db_session, teen_user):
        """Teen can create own events"""
        headers = get_auth_header(teen_user)
        event_data = {
            "title": "Study Group",
            "description": "Math study session",
            "start": (datetime.utcnow() + timedelta(days=1)).isoformat(),
            "end": (datetime.utcnow() + timedelta(days=1, hours=2)).isoformat(),
            "allDay": False,
            "attendees": [teen_user.id],
            "category": "other",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 200

    def test_create_event_as_child_forbidden(self, db_session, child_user):
        """Child cannot create events"""
        headers = get_auth_header(child_user)
        event_data = {
            "title": "Playdate",
            "start": datetime.utcnow().isoformat(),
            "category": "family",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 403

    def test_create_event_invalid_rrule(self, db_session, parent_user):
        """Invalid RRULE format should fail"""
        headers = get_auth_header(parent_user)
        event_data = {
            "title": "Bad Event",
            "start": datetime.utcnow().isoformat(),
            "rrule": "INVALID_RRULE_FORMAT",
            "category": "other",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 400
        assert "RRULE" in response.json()["detail"]

    def test_create_event_start_after_end(self, db_session, parent_user):
        """Start time after end time should fail"""
        headers = get_auth_header(parent_user)
        event_data = {
            "title": "Bad Timing",
            "start": (datetime.utcnow() + timedelta(hours=2)).isoformat(),
            "end": datetime.utcnow().isoformat(),
            "category": "other",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 400

    def test_create_event_invalid_attendee(self, db_session, parent_user):
        """Invalid attendee ID should fail"""
        headers = get_auth_header(parent_user)
        event_data = {
            "title": "Event",
            "start": datetime.utcnow().isoformat(),
            "attendees": ["invalid-user-id"],
            "category": "other",
        }

        response = client.post("/calendar", json=event_data, headers=headers)
        assert response.status_code == 400


class TestEventRetrieval:
    """Test event retrieval operations"""

    def test_list_events_as_parent(self, db_session, parent_user):
        """Parent can view all family events"""
        # Create test event
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Family Dinner",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.get("/calendar", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) > 0
        assert any(e["title"] == "Family Dinner" for e in data)

    def test_list_events_as_child_filtered(self, db_session, parent_user, child_user):
        """Child can only view events where they are attendees"""
        # Create event for child
        event1 = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Child's Event",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[child_user.id],
            category="family",
        )
        # Create event without child
        event2 = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Parent's Event",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add_all([event1, event2])
        db_session.commit()

        headers = get_auth_header(child_user)
        response = client.get("/calendar", headers=headers)
        assert response.status_code == 200
        data = response.json()
        # Child should only see their event
        assert len(data) == 1
        assert data[0]["title"] == "Child's Event"

    def test_list_events_helper_forbidden(self, db_session, helper_user):
        """Helper cannot access calendar"""
        headers = get_auth_header(helper_user)
        response = client.get("/calendar", headers=headers)
        assert response.status_code == 403

    def test_get_single_event(self, db_session, parent_user):
        """Get single event by ID"""
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Doctor Appointment",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="appointment",
        )
        db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.get(f"/calendar/{event.id}", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Doctor Appointment"

    def test_get_event_not_found(self, db_session, parent_user):
        """Get non-existent event returns 404"""
        headers = get_auth_header(parent_user)
        response = client.get(f"/calendar/{str(uuid4())}", headers=headers)
        assert response.status_code == 404


class TestRecurringEventExpansion:
    """Test recurring event expansion"""

    def test_expand_daily_recurring_event(self, db_session, parent_user):
        """Daily recurring event expands correctly"""
        start_date = datetime.utcnow().replace(hour=10, minute=0, second=0, microsecond=0)
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Daily Meeting",
            start=start_date,
            end=start_date + timedelta(hours=1),
            rrule="FREQ=DAILY",
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add(event)
        db_session.commit()

        # Query for next 7 days
        headers = get_auth_header(parent_user)
        end_date = start_date + timedelta(days=7)
        response = client.get(
            f"/calendar?start_date={start_date.isoformat()}&end_date={end_date.isoformat()}",
            headers=headers
        )
        assert response.status_code == 200
        data = response.json()
        # Should have 7 occurrences (one per day)
        assert len(data) >= 7

    def test_expand_weekly_recurring_event(self, db_session, parent_user):
        """Weekly recurring event expands correctly"""
        start_date = datetime.utcnow().replace(hour=15, minute=0, second=0, microsecond=0)
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Weekly Class",
            start=start_date,
            rrule="FREQ=WEEKLY;BYDAY=MO,FR",
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="other",
        )
        db_session.add(event)
        db_session.commit()

        # Query for next month
        headers = get_auth_header(parent_user)
        end_date = start_date + timedelta(days=30)
        response = client.get(
            f"/calendar?start_date={start_date.isoformat()}&end_date={end_date.isoformat()}",
            headers=headers
        )
        assert response.status_code == 200
        data = response.json()
        # Should have ~8 occurrences (2 per week for 4 weeks)
        assert len(data) >= 6


class TestEventUpdate:
    """Test event update operations"""

    def test_update_event_as_parent(self, db_session, parent_user):
        """Parent can update any event"""
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Original Title",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)
        update_data = {
            "title": "Updated Title",
            "description": "New description",
            "start": event.start.isoformat(),
            "category": "appointment",
        }

        response = client.put(f"/calendar/{event.id}", json=update_data, headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["title"] == "Updated Title"
        assert data["category"] == "appointment"

    def test_update_event_teen_own_only(self, db_session, parent_user, teen_user):
        """Teen can only update own events"""
        # Create event by parent
        parent_event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Parent Event",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[teen_user.id],
            category="family",
        )
        db_session.add(parent_event)
        db_session.commit()

        headers = get_auth_header(teen_user)
        update_data = {
            "title": "Hacked Title",
            "start": parent_event.start.isoformat(),
            "category": "family",
        }

        # Teen cannot update parent's event
        response = client.put(f"/calendar/{parent_event.id}", json=update_data, headers=headers)
        assert response.status_code == 403


class TestEventDeletion:
    """Test event deletion operations"""

    def test_delete_event_as_parent(self, db_session, parent_user):
        """Parent can delete any event"""
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="To Delete",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.delete(f"/calendar/{event.id}", headers=headers)
        assert response.status_code == 200
        assert response.json()["status"] == "deleted"

        # Verify deleted
        check = db_session.query(models.Event).filter_by(id=event.id).first()
        assert check is None

    def test_delete_event_teen_own_only(self, db_session, parent_user, teen_user):
        """Teen can only delete own events"""
        parent_event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Parent Event",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[teen_user.id],
            category="family",
        )
        db_session.add(parent_event)
        db_session.commit()

        headers = get_auth_header(teen_user)
        response = client.delete(f"/calendar/{parent_event.id}", headers=headers)
        assert response.status_code == 403


class TestMonthAndWeekViews:
    """Test month and week view endpoints"""

    def test_month_view(self, db_session, parent_user):
        """Month view returns events for specified month"""
        # Create events in current month
        now = datetime.utcnow()
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Monthly Event",
            start=now,
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.get(f"/calendar/calendar/{now.year}/{now.month}", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) > 0

    def test_week_view(self, db_session, parent_user):
        """Current week view returns this week's events"""
        # Create event in current week
        now = datetime.utcnow()
        event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="This Week",
            start=now,
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.get("/calendar/week/current", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) > 0


class TestFilteringAndPagination:
    """Test event filtering and pagination"""

    def test_filter_by_category(self, db_session, parent_user):
        """Filter events by category"""
        # Create events with different categories
        sport_event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Soccer",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            category="sport",
        )
        school_event = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Parent Meeting",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            category="school",
        )
        db_session.add_all([sport_event, school_event])
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.get("/calendar?category=sport", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert all(e["category"] == "sport" for e in data)

    def test_filter_by_attendee(self, db_session, parent_user, child_user):
        """Filter events by attendee"""
        # Create events with different attendees
        event1 = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Child Event",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[child_user.id],
            category="family",
        )
        event2 = models.Event(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            title="Parent Event",
            start=datetime.utcnow(),
            createdBy=parent_user.id,
            attendees=[parent_user.id],
            category="family",
        )
        db_session.add_all([event1, event2])
        db_session.commit()

        headers = get_auth_header(parent_user)
        response = client.get(f"/calendar?userId={child_user.id}", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert all(child_user.id in e["attendees"] for e in data)

    def test_pagination(self, db_session, parent_user):
        """Test pagination with limit and offset"""
        # Create multiple events
        for i in range(10):
            event = models.Event(
                id=str(uuid4()),
                familyId=parent_user.familyId,
                title=f"Event {i}",
                start=datetime.utcnow() + timedelta(hours=i),
                createdBy=parent_user.id,
                category="family",
            )
            db_session.add(event)
        db_session.commit()

        headers = get_auth_header(parent_user)

        # Get first 5
        response = client.get("/calendar?limit=5&offset=0", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 5

        # Get next 5
        response = client.get("/calendar?limit=5&offset=5", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 5
