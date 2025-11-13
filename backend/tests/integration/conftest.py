"""
Integration test fixtures and configuration.

Provides comprehensive test fixtures for integration testing:
- Fresh database for each test
- Sample family with multiple users
- Pre-populated events and tasks
- Authentication helpers
- API client fixtures
"""

import pytest
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from typing import Dict, List

from core.db import Base, get_db
from core.models import Family, User, Event, Task, PointsLedger, Badge, UserStreak
from core.security import hash_password, create_access_token
from main import app


# Test database URL (use in-memory SQLite for speed)
TEST_DATABASE_URL = "sqlite:///:memory:"


@pytest.fixture(scope="function")
def test_db():
    """Create a fresh test database for each test."""
    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False}
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    # Create all tables
    Base.metadata.create_all(bind=engine)

    db = TestingSessionLocal()

    try:
        yield db
    finally:
        db.close()
        # Drop all tables after test
        Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(test_db):
    """Create test client with database override."""
    def override_get_db():
        try:
            yield test_db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def sample_family(test_db) -> Dict:
    """
    Create a sample family with 4 users:
    - 1 parent (admin)
    - 1 teen (14 years old)
    - 2 children (8 and 6 years old)

    Returns dict with family and user objects.
    """
    # Create family
    family = Family(
        name="Test Family",
        id="family-test-001"
    )
    test_db.add(family)
    test_db.flush()

    # Create parent user
    parent = User(
        id="user-parent-001",
        familyId=family.id,
        email="parent@test.com",
        displayName="Test Parent",
        role="parent",
        passwordHash=hash_password("password123"),
        emailVerified=True,
        permissions={"childCanCreateTasks": True}
    )
    test_db.add(parent)

    # Create teen user
    teen = User(
        id="user-teen-001",
        familyId=family.id,
        email="teen@test.com",
        displayName="Test Teen",
        role="teen",
        passwordHash=hash_password("password123"),
        emailVerified=True
    )
    test_db.add(teen)

    # Create child users
    child1 = User(
        id="user-child-001",
        familyId=family.id,
        email="child1@test.com",
        displayName="Test Child 1",
        role="child",
        pin=hash_password("1234")
    )
    test_db.add(child1)

    child2 = User(
        id="user-child-002",
        familyId=family.id,
        email="child2@test.com",
        displayName="Test Child 2",
        role="child",
        pin=hash_password("5678")
    )
    test_db.add(child2)

    test_db.commit()

    return {
        "family": family,
        "parent": parent,
        "teen": teen,
        "child1": child1,
        "child2": child2
    }


@pytest.fixture(scope="function")
def sample_events(test_db, sample_family) -> List[Event]:
    """Create 20 realistic calendar events for testing."""
    family = sample_family["family"]
    parent = sample_family["parent"]

    events = []
    base_date = datetime(2025, 11, 15, 10, 0)  # Start from a Friday

    # Weekly recurring events
    events.append(Event(
        id="event-001",
        familyId=family.id,
        title="Family Dinner",
        description="Weekly family dinner",
        start=base_date.replace(hour=18, minute=0),
        end=base_date.replace(hour=19, minute=0),
        rrule="FREQ=WEEKLY;BYDAY=FR",
        category="family",
        attendees=[parent.id, sample_family["teen"].id, sample_family["child1"].id, sample_family["child2"].id],
        createdBy=parent.id
    ))

    # School events (multiple days)
    for i in range(5):
        day_offset = i
        events.append(Event(
            id=f"event-school-{i+1:03d}",
            familyId=family.id,
            title=f"School Day {i+1}",
            description="Regular school day",
            start=(base_date + timedelta(days=day_offset)).replace(hour=8, minute=30),
            end=(base_date + timedelta(days=day_offset)).replace(hour=15, minute=0),
            category="school",
            attendees=[sample_family["child1"].id, sample_family["child2"].id],
            createdBy=parent.id
        ))

    # Sports activities
    events.append(Event(
        id="event-sport-001",
        familyId=family.id,
        title="Soccer Practice",
        description="Weekly soccer practice",
        start=base_date.replace(hour=16, minute=0),
        end=base_date.replace(hour=17, minute=30),
        rrule="FREQ=WEEKLY;BYDAY=WE",
        category="sport",
        attendees=[sample_family["child1"].id],
        createdBy=parent.id
    ))

    # Medical appointments
    events.append(Event(
        id="event-appt-001",
        familyId=family.id,
        title="Dentist Appointment",
        description="Regular checkup",
        start=(base_date + timedelta(days=7)).replace(hour=14, minute=0),
        end=(base_date + timedelta(days=7)).replace(hour=15, minute=0),
        category="appointment",
        attendees=[sample_family["child2"].id, parent.id],
        createdBy=parent.id
    ))

    # All-day events
    events.append(Event(
        id="event-allday-001",
        familyId=family.id,
        title="Family Vacation",
        description="Beach vacation",
        start=(base_date + timedelta(days=30)).replace(hour=0, minute=0),
        end=(base_date + timedelta(days=37)).replace(hour=0, minute=0),
        allDay=True,
        category="family",
        attendees=[parent.id, sample_family["teen"].id, sample_family["child1"].id, sample_family["child2"].id],
        createdBy=parent.id
    ))

    # Add remaining events to reach 20
    for i in range(10):
        day_offset = i * 2
        events.append(Event(
            id=f"event-misc-{i+1:03d}",
            familyId=family.id,
            title=f"Activity {i+1}",
            description=f"Test activity {i+1}",
            start=(base_date + timedelta(days=day_offset)).replace(hour=10 + (i % 8), minute=0),
            end=(base_date + timedelta(days=day_offset)).replace(hour=11 + (i % 8), minute=0),
            category="other",
            attendees=[sample_family["child1"].id] if i % 2 == 0 else [sample_family["child2"].id],
            createdBy=parent.id
        ))

    for event in events:
        test_db.add(event)

    test_db.commit()
    return events


@pytest.fixture(scope="function")
def sample_tasks(test_db, sample_family) -> List[Task]:
    """Create 30 realistic tasks for testing."""
    family = sample_family["family"]
    parent = sample_family["parent"]

    tasks = []
    base_date = datetime(2025, 11, 15, 10, 0)

    # Daily recurring tasks
    tasks.append(Task(
        id="task-001",
        familyId=family.id,
        title="Morning Chores",
        desc="Make bed, brush teeth, get dressed",
        category="cleaning",
        due=base_date.replace(hour=8, minute=0),
        frequency="daily",
        rrule="FREQ=DAILY",
        rotationStrategy="round_robin",
        rotationState={"currentIndex": 0, "lastRotation": base_date.isoformat()},
        assignees=[sample_family["child1"].id, sample_family["child2"].id],
        points=10,
        status="open"
    ))

    # Weekly recurring tasks
    tasks.append(Task(
        id="task-002",
        familyId=family.id,
        title="Clean Bedroom",
        desc="Vacuum, dust, organize",
        category="cleaning",
        due=base_date.replace(hour=14, minute=0, day=20),  # Saturday
        frequency="weekly",
        rrule="FREQ=WEEKLY;BYDAY=SA",
        rotationStrategy="fairness",
        rotationState={},
        assignees=[sample_family["child1"].id, sample_family["child2"].id],
        points=25,
        status="open",
        photoRequired=True
    ))

    # Homework tasks
    for i in range(5):
        day_offset = i
        tasks.append(Task(
            id=f"task-homework-{i+1:03d}",
            familyId=family.id,
            title=f"Homework Day {i+1}",
            desc=f"Complete daily homework assignments",
            category="homework",
            due=(base_date + timedelta(days=day_offset)).replace(hour=16, minute=0),
            frequency="none",
            assignees=[sample_family["child1"].id] if i % 2 == 0 else [sample_family["child2"].id],
            points=15,
            status="open" if i < 3 else "done"
        ))

    # Pet care tasks
    tasks.append(Task(
        id="task-pet-001",
        familyId=family.id,
        title="Feed Dog",
        desc="Morning and evening feeding",
        category="pet",
        due=base_date.replace(hour=7, minute=0),
        frequency="daily",
        rrule="FREQ=DAILY",
        rotationStrategy="round_robin",
        rotationState={"currentIndex": 1, "lastRotation": base_date.isoformat()},
        assignees=[sample_family["teen"].id, sample_family["child1"].id],
        points=5,
        status="open"
    ))

    # Claimable tasks
    tasks.append(Task(
        id="task-claim-001",
        familyId=family.id,
        title="Wash Car",
        desc="Wash and vacuum family car",
        category="care",
        due=(base_date + timedelta(days=2)).replace(hour=10, minute=0),
        frequency="none",
        claimable=True,
        assignees=[],
        points=50,
        status="open",
        photoRequired=True,
        parentApproval=True
    ))

    # Pending approval tasks
    tasks.append(Task(
        id="task-pending-001",
        familyId=family.id,
        title="Organize Garage",
        desc="Clean and organize garage",
        category="cleaning",
        due=base_date.replace(hour=10, minute=0),
        frequency="none",
        assignees=[sample_family["teen"].id],
        claimedBy=sample_family["teen"].id,
        claimedAt=base_date,
        points=100,
        status="pendingApproval",
        photoRequired=True,
        parentApproval=True
    ))

    # Add remaining tasks to reach 30
    for i in range(20):
        day_offset = i
        category = ["cleaning", "care", "homework", "other"][i % 4]
        tasks.append(Task(
            id=f"task-misc-{i+1:03d}",
            familyId=family.id,
            title=f"Task {i+1}",
            desc=f"Test task {i+1}",
            category=category,
            due=(base_date + timedelta(days=day_offset)).replace(hour=12 + (i % 10), minute=0),
            frequency="none",
            assignees=[sample_family["child1"].id] if i % 2 == 0 else [sample_family["child2"].id],
            points=10 + (i % 5) * 5,
            status="open" if i < 15 else "done"
        ))

    for task in tasks:
        test_db.add(task)

    test_db.commit()
    return tasks


@pytest.fixture(scope="function")
def auth_headers(sample_family) -> Dict[str, Dict[str, str]]:
    """Generate authentication headers for all test users."""
    parent = sample_family["parent"]
    teen = sample_family["teen"]
    child1 = sample_family["child1"]
    child2 = sample_family["child2"]

    return {
        "parent": {
            "Authorization": f"Bearer {create_access_token(data={'sub': parent.id, 'role': parent.role})}"
        },
        "teen": {
            "Authorization": f"Bearer {create_access_token(data={'sub': teen.id, 'role': teen.role})}"
        },
        "child1": {
            "Authorization": f"Bearer {create_access_token(data={'sub': child1.id, 'role': child1.role})}"
        },
        "child2": {
            "Authorization": f"Bearer {create_access_token(data={'sub': child2.id, 'role': child2.role})}"
        }
    }


@pytest.fixture(scope="function")
def api_client(client, auth_headers):
    """Enhanced API client with authentication helper methods."""
    class APIClient:
        def __init__(self, client, auth_headers):
            self.client = client
            self.auth_headers = auth_headers

        def get(self, url, user="parent", **kwargs):
            headers = kwargs.pop("headers", {})
            headers.update(self.auth_headers[user])
            return self.client.get(url, headers=headers, **kwargs)

        def post(self, url, user="parent", **kwargs):
            headers = kwargs.pop("headers", {})
            headers.update(self.auth_headers[user])
            return self.client.post(url, headers=headers, **kwargs)

        def put(self, url, user="parent", **kwargs):
            headers = kwargs.pop("headers", {})
            headers.update(self.auth_headers[user])
            return self.client.put(url, headers=headers, **kwargs)

        def delete(self, url, user="parent", **kwargs):
            headers = kwargs.pop("headers", {})
            headers.update(self.auth_headers[user])
            return self.client.delete(url, headers=headers, **kwargs)

    return APIClient(client, auth_headers)
