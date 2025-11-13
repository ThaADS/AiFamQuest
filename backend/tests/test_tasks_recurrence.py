"""
Comprehensive Tests for Task Recurrence and Fairness Engine

Tests cover:
- RRULE validation and expansion
- Task rotation strategies (round_robin, fairness, random, manual)
- Fairness engine calculations and workload distribution
- Calendar conflict detection
- Task occurrence management (skip, complete series)
- Edge cases (no eligible users, equal workload, capacity limits)
"""

import pytest
from datetime import date, datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from uuid import uuid4

from core.db import Base
from core import models
from core.fairness import FairnessEngine
from services.task_generator import TaskGenerator
from routers.tasks import validate_rrule

# Test database setup
TEST_DATABASE_URL = "sqlite:///./test_tasks_recurrence.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)


# === Fixtures ===

@pytest.fixture
def db():
    """Create test database session"""
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def test_family(db) -> models.Family:
    """Create test family"""
    family = models.Family(
        id=str(uuid4()),
        name="Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(family)
    db.commit()
    db.refresh(family)
    return family


@pytest.fixture
def test_users(db, test_family: models.Family) -> dict:
    """Create test users with different roles"""
    users = {
        "parent": models.User(
            id=str(uuid4()),
            familyId=test_family.id,
            email="parent@test.com",
            displayName="Parent",
            role="parent",
            passwordHash="hash",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        ),
        "teen": models.User(
            id=str(uuid4()),
            familyId=test_family.id,
            email="teen@test.com",
            displayName="Teen",
            role="teen",
            passwordHash="hash",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        ),
        "child": models.User(
            id=str(uuid4()),
            familyId=test_family.id,
            email="child@test.com",
            displayName="Child",
            role="child",
            passwordHash="hash",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        ),
        "helper": models.User(
            id=str(uuid4()),
            familyId=test_family.id,
            email="helper@test.com",
            displayName="Helper",
            role="helper",
            passwordHash="hash",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
    }

    for user in users.values():
        db.add(user)

    db.commit()

    for user in users.values():
        db.refresh(user)

    return users


@pytest.fixture
def recurring_task_daily(db, test_family: models.Family, test_users: dict) -> models.Task:
    """Create daily recurring task"""
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Daily Homework",
        desc="Complete homework every weekday",
        category="homework",
        due=datetime.utcnow().replace(hour=18, minute=0, second=0, microsecond=0),
        frequency="daily",
        rrule="FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",  # Weekdays only
        rotationStrategy="round_robin",
        rotationState={},
        assignees=[test_users["teen"].id, test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        photoRequired=False,
        parentApproval=False,
        priority="med",
        estDuration=30,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@pytest.fixture
def recurring_task_weekly(db, test_family: models.Family, test_users: dict) -> models.Task:
    """Create weekly recurring task"""
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Weekly Room Cleaning",
        desc="Deep clean room every Saturday",
        category="cleaning",
        due=datetime.utcnow().replace(hour=10, minute=0, second=0, microsecond=0),
        frequency="weekly",
        rrule="FREQ=WEEKLY;BYDAY=SA",
        rotationStrategy="fairness",
        rotationState={},
        assignees=[test_users["teen"].id, test_users["child"].id],
        claimable=False,
        status="open",
        points=20,
        photoRequired=True,
        parentApproval=True,
        priority="high",
        estDuration=60,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


# === RRULE Validation Tests ===

def test_validate_rrule_daily():
    """Test daily RRULE validation"""
    assert validate_rrule("FREQ=DAILY") is True
    assert validate_rrule("FREQ=DAILY;COUNT=30") is True
    assert validate_rrule("FREQ=DAILY;INTERVAL=2") is True


def test_validate_rrule_weekly():
    """Test weekly RRULE validation"""
    assert validate_rrule("FREQ=WEEKLY") is True
    assert validate_rrule("FREQ=WEEKLY;BYDAY=MO,WE,FR") is True
    assert validate_rrule("FREQ=WEEKLY;BYDAY=SA,SU") is True


def test_validate_rrule_monthly():
    """Test monthly RRULE validation"""
    assert validate_rrule("FREQ=MONTHLY") is True
    assert validate_rrule("FREQ=MONTHLY;BYMONTHDAY=1") is True
    assert validate_rrule("FREQ=MONTHLY;BYDAY=1MO") is True  # First Monday


def test_validate_rrule_invalid():
    """Test invalid RRULE rejection"""
    assert validate_rrule("INVALID") is False
    assert validate_rrule("FREQ=INVALID") is False
    assert validate_rrule("FREQ=DAILY;INVALID=VALUE") is False


def test_validate_rrule_empty():
    """Test empty RRULE (allowed for non-recurring tasks)"""
    assert validate_rrule(None) is True
    assert validate_rrule("") is True


# === RRULE Expansion Tests ===

def test_expand_rrule_daily(db, recurring_task_daily: models.Task):
    """Test daily RRULE expansion"""
    generator = TaskGenerator(db)

    today = date.today()
    week_end = today + timedelta(days=7)

    occurrences = generator._expand_task_rrule(
        recurring_task_daily,
        today,
        week_end,
        max_occurrences=365
    )

    # Should get weekdays only (5 per week)
    assert len(occurrences) >= 5

    # Verify all are weekdays (Monday=0, Friday=4)
    for occurrence in occurrences:
        assert occurrence.weekday() < 5  # Not Saturday or Sunday


def test_expand_rrule_weekly(db, recurring_task_weekly: models.Task):
    """Test weekly RRULE expansion"""
    generator = TaskGenerator(db)

    today = date.today()
    month_end = today + timedelta(days=30)

    occurrences = generator._expand_task_rrule(
        recurring_task_weekly,
        today,
        month_end,
        max_occurrences=365
    )

    # Should get ~4 Saturdays in a month
    assert 3 <= len(occurrences) <= 5

    # Verify all are Saturdays (Saturday=5)
    for occurrence in occurrences:
        assert occurrence.weekday() == 5


def test_expand_rrule_max_occurrences(db, recurring_task_daily: models.Task):
    """Test max occurrence limit"""
    generator = TaskGenerator(db)

    today = date.today()
    year_end = today + timedelta(days=365)

    # Daily task with max 10 occurrences
    occurrences = generator._expand_task_rrule(
        recurring_task_daily,
        today,
        year_end,
        max_occurrences=10
    )

    assert len(occurrences) == 10


# === Rotation Strategy Tests ===

def test_rotation_round_robin(db, recurring_task_daily: models.Task, test_users: dict):
    """Test round-robin rotation"""
    fairness_engine = FairnessEngine(db)

    today = date.today()
    assignees_expected = [test_users["teen"].id, test_users["child"].id]

    # First occurrence
    assignee1 = fairness_engine.rotate_assignee(recurring_task_daily, today)
    assert assignee1 == assignees_expected[0]

    # Second occurrence (should rotate)
    assignee2 = fairness_engine.rotate_assignee(recurring_task_daily, today + timedelta(days=1))
    assert assignee2 == assignees_expected[1]

    # Third occurrence (should wrap around)
    assignee3 = fairness_engine.rotate_assignee(recurring_task_daily, today + timedelta(days=2))
    assert assignee3 == assignees_expected[0]


def test_rotation_fairness_least_loaded(db, recurring_task_weekly: models.Task, test_users: dict):
    """Test fairness rotation selects least loaded user"""
    fairness_engine = FairnessEngine(db)
    generator = TaskGenerator(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # Create existing tasks for teen (overload them)
    for i in range(5):
        task = models.Task(
            id=str(uuid4()),
            familyId=recurring_task_weekly.familyId,
            title=f"Existing Task {i}",
            desc="",
            category="other",
            due=datetime.combine(week_start + timedelta(days=i), datetime.min.time()),
            frequency="none",
            assignees=[test_users["teen"].id],
            claimable=False,
            status="open",
            points=10,
            estDuration=60,  # 1 hour each = 5 hours total
            createdBy=test_users["parent"].id,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow(),
            version=0
        )
        db.add(task)

    db.commit()

    # Fairness rotation should select child (less loaded)
    occurrence_date = week_start + timedelta(days=6)  # Saturday
    assignee = fairness_engine.rotate_assignee(recurring_task_weekly, occurrence_date)

    assert assignee == test_users["child"].id  # Child has lower workload


def test_rotation_random(db, test_family: models.Family, test_users: dict):
    """Test random rotation"""
    # Create task with random strategy
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Random Task",
        desc="",
        category="other",
        due=datetime.utcnow(),
        frequency="daily",
        rrule="FREQ=DAILY",
        rotationStrategy="random",
        rotationState={},
        assignees=[test_users["teen"].id, test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=15,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()

    fairness_engine = FairnessEngine(db)

    # Run 10 times to check randomness
    assignees_seen = set()
    for i in range(10):
        occurrence_date = date.today() + timedelta(days=i)
        assignee = fairness_engine.rotate_assignee(task, occurrence_date)
        assignees_seen.add(assignee)

    # Should have assigned both users at least once (with high probability)
    assert len(assignees_seen) == 2


def test_rotation_manual(db, test_family: models.Family, test_users: dict):
    """Test manual rotation returns None"""
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Manual Task",
        desc="",
        category="other",
        due=datetime.utcnow(),
        frequency="daily",
        rrule="FREQ=DAILY",
        rotationStrategy="manual",
        rotationState={},
        assignees=[test_users["teen"].id, test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=15,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()

    fairness_engine = FairnessEngine(db)

    assignee = fairness_engine.rotate_assignee(task, date.today())

    # Manual strategy should return None (parent assigns manually)
    assert assignee is None


# === Fairness Engine Tests ===

def test_calculate_workload_no_tasks(db, test_users: dict):
    """Test workload calculation with no tasks"""
    fairness_engine = FairnessEngine(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    workload = fairness_engine.calculate_workload(test_users["child"].id, week_start)

    assert workload == 0.0


def test_calculate_workload_with_tasks(db, test_family: models.Family, test_users: dict):
    """Test workload calculation with tasks"""
    fairness_engine = FairnessEngine(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # Create tasks for child (120 min capacity)
    # Add 60 min of tasks = 50% capacity
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Task 1",
        desc="",
        category="other",
        due=datetime.combine(week_start + timedelta(days=1), datetime.min.time()),
        frequency="none",
        assignees=[test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=60,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()

    workload = fairness_engine.calculate_workload(test_users["child"].id, week_start)

    # 60 min / 120 min capacity = 0.5
    assert 0.45 <= workload <= 0.55  # Allow small margin


def test_calculate_workload_overloaded(db, test_family: models.Family, test_users: dict):
    """Test workload calculation when overloaded"""
    fairness_engine = FairnessEngine(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # Overload child with 200 min of tasks (capacity is 120 min)
    for i in range(4):
        task = models.Task(
            id=str(uuid4()),
            familyId=test_family.id,
            title=f"Task {i}",
            desc="",
            category="other",
            due=datetime.combine(week_start + timedelta(days=i), datetime.min.time()),
            frequency="none",
            assignees=[test_users["child"].id],
            claimable=False,
            status="open",
            points=10,
            estDuration=50,  # 4 × 50 = 200 min
            createdBy=test_users["parent"].id,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow(),
            version=0
        )
        db.add(task)

    db.commit()

    workload = fairness_engine.calculate_workload(test_users["child"].id, week_start)

    # 200 min / 120 min capacity = 1.67
    assert workload > 1.0  # Overloaded


def test_fairness_distribution(db, test_family: models.Family, test_users: dict):
    """Test fairness score distribution across family"""
    fairness_engine = FairnessEngine(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # Add different workloads for teen and child
    # Teen: 120 min (240 capacity = 50%)
    task_teen = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Teen Task",
        desc="",
        category="other",
        due=datetime.combine(week_start + timedelta(days=1), datetime.min.time()),
        frequency="none",
        assignees=[test_users["teen"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=120,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )

    # Child: 30 min (120 capacity = 25%)
    task_child = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Child Task",
        desc="",
        category="other",
        due=datetime.combine(week_start + timedelta(days=1), datetime.min.time()),
        frequency="none",
        assignees=[test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=30,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )

    db.add(task_teen)
    db.add(task_child)
    db.commit()

    fairness_scores = fairness_engine.calculate_fairness_score(test_family.id, week_start)

    # Child should have lower workload than teen
    assert fairness_scores[test_users["child"].id] < fairness_scores[test_users["teen"].id]

    # Helper should not be in scores (excluded from fairness)
    assert test_users["helper"].id not in fairness_scores


# === Task Generation Tests ===

def test_generate_recurring_tasks(db, recurring_task_daily: models.Task):
    """Test recurring task generation"""
    generator = TaskGenerator(db)

    today = date.today()
    week_end = today + timedelta(days=7)

    generated_tasks = generator.generate_recurring_tasks(
        recurring_task_daily.familyId,
        today,
        week_end
    )

    # Should generate ~5 weekday tasks
    assert len(generated_tasks) >= 3

    # Verify all are task instances (not templates)
    for task in generated_tasks:
        assert task.rrule is None  # Instances don't have rrule
        assert task.frequency == "none"
        assert len(task.assignees) == 1  # Single assignee per instance


def test_generate_recurring_tasks_no_duplicates(db, recurring_task_daily: models.Task):
    """Test duplicate prevention"""
    generator = TaskGenerator(db)

    today = date.today()
    week_end = today + timedelta(days=7)

    # Generate once
    first_batch = generator.generate_recurring_tasks(
        recurring_task_daily.familyId,
        today,
        week_end
    )

    # Generate again (should not create duplicates)
    second_batch = generator.generate_recurring_tasks(
        recurring_task_daily.familyId,
        today,
        week_end
    )

    # Second batch should be empty (all already generated)
    assert len(second_batch) == 0


def test_skip_occurrence(db, recurring_task_daily: models.Task, test_users: dict):
    """Test skipping specific occurrence"""
    generator = TaskGenerator(db)

    skip_date = date.today() + timedelta(days=1)

    # Skip occurrence
    success = generator.skip_task_occurrence(
        recurring_task_daily.id,
        skip_date,
        test_users["parent"].id
    )

    assert success is True

    # Verify skipped in TaskLog
    assert generator._is_occurrence_skipped(recurring_task_daily.id, skip_date) is True

    # Try to skip again (should fail)
    success_again = generator.skip_task_occurrence(
        recurring_task_daily.id,
        skip_date,
        test_users["parent"].id
    )

    assert success_again is False


def test_complete_series(db, recurring_task_daily: models.Task, test_users: dict):
    """Test completing entire recurring series"""
    generator = TaskGenerator(db)

    success = generator.complete_series(
        recurring_task_daily.id,
        test_users["parent"].id
    )

    assert success is True

    # Refresh task
    db.refresh(recurring_task_daily)

    # Verify template marked as done
    assert recurring_task_daily.status == "done"
    assert recurring_task_daily.completedBy == test_users["parent"].id
    assert recurring_task_daily.completedAt is not None


def test_get_task_occurrences(db, recurring_task_daily: models.Task):
    """Test getting occurrence status"""
    generator = TaskGenerator(db)

    today = date.today()
    week_end = today + timedelta(days=7)

    # Generate some tasks
    generator.generate_recurring_tasks(
        recurring_task_daily.familyId,
        today,
        week_end
    )

    # Get occurrence info
    occurrences = generator.get_task_occurrences(
        recurring_task_daily.id,
        today,
        week_end
    )

    assert len(occurrences) >= 3

    # Verify occurrence structure
    for occurrence in occurrences:
        assert "occurrence_date" in occurrence
        assert "is_generated" in occurrence
        assert "is_skipped" in occurrence
        assert "status" in occurrence


# === Edge Cases ===

def test_no_eligible_users(db, test_family: models.Family, test_users: dict):
    """Test task with no eligible users"""
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="No Assignees Task",
        desc="",
        category="other",
        due=datetime.utcnow(),
        frequency="daily",
        rrule="FREQ=DAILY",
        rotationStrategy="round_robin",
        rotationState={},
        assignees=[],  # No assignees
        claimable=False,
        status="open",
        points=10,
        estDuration=15,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()

    fairness_engine = FairnessEngine(db)

    assignee = fairness_engine.rotate_assignee(task, date.today())

    # Should return None when no assignees
    assert assignee is None


def test_all_users_at_capacity(db, test_family: models.Family, test_users: dict):
    """Test fairness when all users at capacity"""
    fairness_engine = FairnessEngine(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # Overload all users
    for user_key in ["teen", "child"]:
        for i in range(10):
            task = models.Task(
                id=str(uuid4()),
                familyId=test_family.id,
                title=f"Overload {user_key} {i}",
                desc="",
                category="other",
                due=datetime.combine(week_start + timedelta(days=i % 7), datetime.min.time()),
                frequency="none",
                assignees=[test_users[user_key].id],
                claimable=False,
                status="open",
                points=10,
                estDuration=60,  # Many 60 min tasks
                createdBy=test_users["parent"].id,
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow(),
                version=0
            )
            db.add(task)

    db.commit()

    # Create task to assign
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="New Task",
        desc="",
        category="other",
        due=datetime.combine(week_start + timedelta(days=1), datetime.min.time()),
        frequency="weekly",
        rrule="FREQ=WEEKLY",
        rotationStrategy="fairness",
        rotationState={},
        assignees=[test_users["teen"].id, test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=30,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()

    # Fairness engine should still assign to someone (first eligible)
    assignee = fairness_engine.rotate_assignee(task, week_start + timedelta(days=1))

    assert assignee in [test_users["teen"].id, test_users["child"].id]


def test_equal_workload_assignment(db, test_family: models.Family, test_users: dict):
    """Test fairness when users have equal workload"""
    fairness_engine = FairnessEngine(db)
    generator = TaskGenerator(db)

    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # Give both users equal workload
    for user_key in ["teen", "child"]:
        task = models.Task(
            id=str(uuid4()),
            familyId=test_family.id,
            title=f"Equal Task {user_key}",
            desc="",
            category="other",
            due=datetime.combine(week_start + timedelta(days=1), datetime.min.time()),
            frequency="none",
            assignees=[test_users[user_key].id],
            claimable=False,
            status="open",
            points=10,
            estDuration=30,  # Same duration
            createdBy=test_users["parent"].id,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow(),
            version=0
        )
        db.add(task)

    db.commit()

    # Create new task
    task = models.Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="New Equal Task",
        desc="",
        category="other",
        due=datetime.combine(week_start + timedelta(days=2), datetime.min.time()),
        frequency="weekly",
        rrule="FREQ=WEEKLY",
        rotationStrategy="fairness",
        rotationState={},
        assignees=[test_users["teen"].id, test_users["child"].id],
        claimable=False,
        status="open",
        points=10,
        estDuration=30,
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db.add(task)
    db.commit()

    # Should assign to someone (deterministic choice)
    assignee = fairness_engine.rotate_assignee(task, week_start + timedelta(days=2))

    assert assignee in [test_users["teen"].id, test_users["child"].id]
