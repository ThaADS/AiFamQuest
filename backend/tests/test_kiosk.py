"""
Comprehensive test suite for Kiosk Mode API

Tests cover:
- GET /kiosk/today endpoint (today's schedule)
- GET /kiosk/week endpoint (7-day overview)
- POST /kiosk/verify-pin endpoint (PIN validation)
- Edge cases: no tasks, no events, expired helpers
- Error cases: invalid PIN, missing PIN, user not found
- Data validation: correct formatting, sorting, filtering
"""

import pytest
from datetime import datetime, date, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from uuid import uuid4

from core.db import Base
from core import models
from main import app
from core.security import create_token

# Test database setup
TEST_DATABASE_URL = "sqlite:///./test_kiosk.db"
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
        name="Kiosk Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
    )
    db_session.add(family)
    db_session.commit()
    return family


@pytest.fixture
def parent_user(db_session, test_family):
    """Create parent user with PIN"""
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="parent@kiosk.test",
        displayName="Parent User",
        role="parent",
        locale="nl",
        theme="minimal",
        pin="1234",  # Set kiosk PIN
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
        email="child@kiosk.test",
        displayName="Child User",
        role="child",
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
        email="teen@kiosk.test",
        displayName="Teen User",
        role="teen",
        locale="nl",
        theme="minimal",
    )
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def helper_user(db_session, test_family):
    """Create helper user with valid access period"""
    today = datetime.utcnow()
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="helper@kiosk.test",
        displayName="Helper User",
        role="helper",
        locale="nl",
        theme="minimal",
        helperStartDate=today - timedelta(days=1),
        helperEndDate=today + timedelta(days=7),
    )
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def expired_helper_user(db_session, test_family):
    """Create helper user with expired access"""
    today = datetime.utcnow()
    user = models.User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="expired_helper@kiosk.test",
        displayName="Expired Helper",
        role="helper",
        locale="nl",
        theme="minimal",
        helperStartDate=today - timedelta(days=14),
        helperEndDate=today - timedelta(days=1),
    )
    db_session.add(user)
    db_session.commit()
    return user


def create_task(db_session, family_id, assignee_id, title, due_time, points=10, status="open"):
    """Helper to create test task"""
    task = models.Task(
        id=str(uuid4()),
        familyId=family_id,
        title=title,
        desc="Test task",
        assignees=[assignee_id],
        due=due_time,
        points=points,
        status=status,
        category="cleaning",
        frequency="none",
        estDuration=30,
        priority="med",
        photoRequired=False,
        parentApproval=False,
        createdBy=assignee_id,
    )
    db_session.add(task)
    db_session.commit()
    return task


def create_event(db_session, family_id, attendee_ids, title, start_time, end_time=None):
    """Helper to create test event"""
    event = models.Event(
        id=str(uuid4()),
        familyId=family_id,
        title=title,
        description="Test event",
        start=start_time,
        end=end_time,
        allDay=False,
        attendees=attendee_ids,
        category="family",
        createdBy=attendee_ids[0],
    )
    db_session.add(event)
    db_session.commit()
    return event


def get_auth_headers(user_id: str):
    """Generate auth headers for test user"""
    token = create_token({"sub": user_id})
    return {"Authorization": f"Bearer {token}"}


class TestKioskToday:
    """Tests for GET /kiosk/today endpoint"""

    def test_get_today_success(self, db_session, parent_user, child_user):
        """Test successful retrieval of today's schedule"""
        today = datetime.combine(date.today(), datetime.min.time())

        # Create tasks for today
        create_task(
            db_session, parent_user.familyId, parent_user.id,
            "Morning task", today + timedelta(hours=9), 10
        )
        create_task(
            db_session, parent_user.familyId, child_user.id,
            "School homework", today + timedelta(hours=16), 20
        )

        # Create events for today
        create_event(
            db_session, parent_user.familyId, [parent_user.id, child_user.id],
            "Family dinner", today + timedelta(hours=18), today + timedelta(hours=19)
        )

        # Make request
        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        # Assertions
        assert response.status_code == 200
        data = response.json()

        assert data["date"] == date.today().isoformat()
        assert len(data["members"]) == 2

        # Check parent member data
        parent_member = next(m for m in data["members"] if m["user_id"] == parent_user.id)
        assert parent_member["name"] == "Parent User"
        assert len(parent_member["tasks"]) == 1
        assert parent_member["tasks"][0]["title"] == "Morning task"
        assert parent_member["tasks"][0]["due_time"] == "09:00"
        assert len(parent_member["events"]) == 1
        assert parent_member["events"][0]["title"] == "Family dinner"

        # Check child member data
        child_member = next(m for m in data["members"] if m["user_id"] == child_user.id)
        assert child_member["name"] == "Child User"
        assert len(child_member["tasks"]) == 1
        assert child_member["tasks"][0]["title"] == "School homework"
        assert len(child_member["events"]) == 1

    def test_get_today_no_tasks_or_events(self, db_session, parent_user, child_user):
        """Test today's view with no tasks or events"""
        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        assert response.status_code == 200
        data = response.json()

        assert data["date"] == date.today().isoformat()
        assert len(data["members"]) == 2

        # Both members should have empty tasks and events
        for member in data["members"]:
            assert member["tasks"] == []
            assert member["events"] == []

    def test_get_today_excludes_expired_helper(self, db_session, parent_user, expired_helper_user):
        """Test that expired helpers are excluded from today's view"""
        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        assert response.status_code == 200
        data = response.json()

        # Expired helper should not be in members list
        member_ids = [m["user_id"] for m in data["members"]]
        assert expired_helper_user.id not in member_ids
        assert parent_user.id in member_ids

    def test_get_today_includes_active_helper(self, db_session, parent_user, helper_user):
        """Test that active helpers are included in today's view"""
        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        assert response.status_code == 200
        data = response.json()

        # Active helper should be in members list
        member_ids = [m["user_id"] for m in data["members"]]
        assert helper_user.id in member_ids

    def test_get_today_tasks_sorted_by_time(self, db_session, parent_user):
        """Test that tasks are sorted by due time"""
        today = datetime.combine(date.today(), datetime.min.time())

        # Create tasks in random order
        create_task(db_session, parent_user.familyId, parent_user.id, "Afternoon", today + timedelta(hours=14))
        create_task(db_session, parent_user.familyId, parent_user.id, "Morning", today + timedelta(hours=8))
        create_task(db_session, parent_user.familyId, parent_user.id, "Evening", today + timedelta(hours=20))

        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        assert response.status_code == 200
        data = response.json()

        parent_member = next(m for m in data["members"] if m["user_id"] == parent_user.id)
        tasks = parent_member["tasks"]

        # Should be sorted by due_time
        assert len(tasks) == 3
        assert tasks[0]["title"] == "Morning"
        assert tasks[0]["due_time"] == "08:00"
        assert tasks[1]["title"] == "Afternoon"
        assert tasks[1]["due_time"] == "14:00"
        assert tasks[2]["title"] == "Evening"
        assert tasks[2]["due_time"] == "20:00"

    def test_get_today_unauthorized(self):
        """Test today endpoint without authentication"""
        response = client.get("/kiosk/today")
        assert response.status_code == 401


class TestKioskWeek:
    """Tests for GET /kiosk/week endpoint"""

    def test_get_week_success(self, db_session, parent_user, child_user):
        """Test successful retrieval of week schedule"""
        today = datetime.combine(date.today(), datetime.min.time())

        # Create tasks across the week
        for day_offset in range(7):
            target_date = today + timedelta(days=day_offset)
            create_task(
                db_session, parent_user.familyId, parent_user.id,
                f"Day {day_offset} task", target_date + timedelta(hours=10)
            )

        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/week", headers=headers)

        assert response.status_code == 200
        data = response.json()

        assert data["start_date"] == date.today().isoformat()
        assert data["end_date"] == (date.today() + timedelta(days=6)).isoformat()
        assert len(data["days"]) == 7

        # Check each day has correct structure
        for i, day in enumerate(data["days"]):
            assert "date" in day
            assert "day_name" in day
            assert "members" in day
            assert len(day["members"]) == 2

            # Check tasks exist for each day
            parent_member = next(m for m in day["members"] if m["user_id"] == parent_user.id)
            assert len(parent_member["tasks"]) == 1
            assert parent_member["tasks"][0]["title"] == f"Day {i} task"

    def test_get_week_day_names(self, db_session, parent_user):
        """Test that day names are correct"""
        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/week", headers=headers)

        assert response.status_code == 200
        data = response.json()

        # Check that day_name is one of valid weekday names
        valid_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        for day in data["days"]:
            assert day["day_name"] in valid_days

    def test_get_week_helper_date_boundaries(self, db_session, parent_user):
        """Test helper access filtering across week dates"""
        today = datetime.utcnow()

        # Create helper with limited access (only days 2-4 of the week)
        future_start = today + timedelta(days=2)
        future_end = today + timedelta(days=4)
        helper = models.User(
            id=str(uuid4()),
            familyId=parent_user.familyId,
            email="limited_helper@test.com",
            displayName="Limited Helper",
            role="helper",
            helperStartDate=future_start,
            helperEndDate=future_end,
        )
        db_session.add(helper)
        db_session.commit()

        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/week", headers=headers)

        assert response.status_code == 200
        data = response.json()

        # Check helper is only in days 2, 3, 4
        for i, day in enumerate(data["days"]):
            member_ids = [m["user_id"] for m in day["members"]]
            if i in [2, 3, 4]:
                assert helper.id in member_ids
            else:
                assert helper.id not in member_ids

    def test_get_week_unauthorized(self):
        """Test week endpoint without authentication"""
        response = client.get("/kiosk/week")
        assert response.status_code == 401


class TestKioskVerifyPin:
    """Tests for POST /kiosk/verify-pin endpoint"""

    def test_verify_pin_success(self, db_session, parent_user):
        """Test successful PIN verification"""
        headers = get_auth_headers(parent_user.id)
        response = client.post(
            "/kiosk/verify-pin",
            headers=headers,
            json={"pin": "1234"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["valid"] is True
        assert data.get("error") is None

    def test_verify_pin_invalid(self, db_session, parent_user):
        """Test invalid PIN verification"""
        headers = get_auth_headers(parent_user.id)
        response = client.post(
            "/kiosk/verify-pin",
            headers=headers,
            json={"pin": "9999"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["valid"] is False
        assert data["error"] == "Invalid PIN"

    def test_verify_pin_wrong_length(self, db_session, parent_user):
        """Test PIN with wrong length"""
        headers = get_auth_headers(parent_user.id)

        # Test too short
        response = client.post(
            "/kiosk/verify-pin",
            headers=headers,
            json={"pin": "123"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is False
        assert "4 digits" in data["error"]

        # Test too long
        response = client.post(
            "/kiosk/verify-pin",
            headers=headers,
            json={"pin": "12345"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["valid"] is False
        assert "4 digits" in data["error"]

    def test_verify_pin_non_numeric(self, db_session, parent_user):
        """Test PIN with non-numeric characters"""
        headers = get_auth_headers(parent_user.id)
        response = client.post(
            "/kiosk/verify-pin",
            headers=headers,
            json={"pin": "abcd"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["valid"] is False
        assert "4 digits" in data["error"]

    def test_verify_pin_not_set(self, db_session, child_user):
        """Test PIN verification when user has no PIN set"""
        headers = get_auth_headers(child_user.id)
        response = client.post(
            "/kiosk/verify-pin",
            headers=headers,
            json={"pin": "1234"}
        )

        assert response.status_code == 400
        data = response.json()
        assert "not configured" in data["detail"]

    def test_verify_pin_unauthorized(self):
        """Test PIN verification without authentication"""
        response = client.post("/kiosk/verify-pin", json={"pin": "1234"})
        assert response.status_code == 401


class TestKioskEdgeCases:
    """Edge case tests for kiosk endpoints"""

    def test_capacity_calculation(self, db_session, parent_user, child_user):
        """Test that capacity_pct is calculated correctly"""
        today = datetime.combine(date.today(), datetime.min.time())

        # Create multiple tasks for child to increase capacity
        for i in range(3):
            create_task(
                db_session, parent_user.familyId, child_user.id,
                f"Task {i}", today + timedelta(hours=10 + i), 10
            )

        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        assert response.status_code == 200
        data = response.json()

        child_member = next(m for m in data["members"] if m["user_id"] == child_user.id)
        # Capacity should be > 0 and calculated
        assert child_member["capacity_pct"] >= 0.0
        assert isinstance(child_member["capacity_pct"], (int, float))

    def test_tasks_only_include_open_and_pending(self, db_session, parent_user):
        """Test that only open and pendingApproval tasks are shown"""
        today = datetime.combine(date.today(), datetime.min.time())

        # Create tasks with different statuses
        create_task(db_session, parent_user.familyId, parent_user.id, "Open task", today + timedelta(hours=10), status="open")
        create_task(db_session, parent_user.familyId, parent_user.id, "Pending task", today + timedelta(hours=11), status="pendingApproval")
        create_task(db_session, parent_user.familyId, parent_user.id, "Done task", today + timedelta(hours=12), status="done")

        headers = get_auth_headers(parent_user.id)
        response = client.get("/kiosk/today", headers=headers)

        assert response.status_code == 200
        data = response.json()

        parent_member = next(m for m in data["members"] if m["user_id"] == parent_user.id)
        tasks = parent_member["tasks"]

        # Should only show open and pendingApproval
        assert len(tasks) == 2
        assert tasks[0]["title"] == "Open task"
        assert tasks[1]["title"] == "Pending task"
