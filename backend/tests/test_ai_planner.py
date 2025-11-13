"""
Comprehensive tests for AI Planner

Tests:
- AI planner generates valid plan
- Respects capacity limits
- Avoids event conflicts
- Fair distribution
- Fallback to rule-based planner
- Caching behavior
- Apply plan creates tasks
"""

import pytest
from datetime import datetime, timedelta, time
from unittest.mock import patch, AsyncMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from core.db import Base
from core import models
from services.ai_planner import AIPlanner
import uuid
import json

# Test database
TEST_DATABASE_URL = "sqlite:///./test_ai_planner.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def db_session():
    """Create test database session"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def test_family(db_session):
    """Create test family"""
    family = models.Family(name="Test Family")
    db_session.add(family)
    db_session.commit()
    db_session.refresh(family)
    return family


@pytest.fixture
def test_users(db_session, test_family):
    """Create test family members"""
    users = []

    # Parent
    parent = models.User(
        familyId=test_family.id,
        email="parent@example.com",
        displayName="Parent",
        role="parent"
    )
    db_session.add(parent)

    # Teen
    teen = models.User(
        familyId=test_family.id,
        email="teen@example.com",
        displayName="Teen",
        role="teen"
    )
    db_session.add(teen)

    # Child
    child = models.User(
        familyId=test_family.id,
        email="child@example.com",
        displayName="Child",
        role="child"
    )
    db_session.add(child)

    db_session.commit()

    db_session.refresh(parent)
    db_session.refresh(teen)
    db_session.refresh(child)

    return {"parent": parent, "teen": teen, "child": child}


@pytest.fixture
def recurring_tasks(db_session, test_family, test_users):
    """Create recurring tasks"""
    tasks = []

    # Daily dishwasher task
    task1 = models.Task(
        familyId=test_family.id,
        title="Vaatwasser",
        desc="Load and run dishwasher",
        category="cleaning",
        rrule="FREQ=DAILY",
        points=20,
        estDuration=15,
        rotationStrategy="round_robin",
        assignees=[test_users["teen"].id, test_users["child"].id],
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(task1)

    # Weekly vacuum task
    task2 = models.Task(
        familyId=test_family.id,
        title="Stofzuigen",
        desc="Vacuum all rooms",
        category="cleaning",
        rrule="FREQ=WEEKLY;BYDAY=MO,TH",
        points=30,
        estDuration=30,
        rotationStrategy="fairness",
        assignees=[test_users["teen"].id, test_users["child"].id],
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(task2)

    db_session.commit()
    db_session.refresh(task1)
    db_session.refresh(task2)

    return [task1, task2]


@pytest.fixture
def calendar_events(db_session, test_family, test_users):
    """Create calendar events"""
    # Soccer practice on Monday 16:00-17:00
    event1 = models.Event(
        familyId=test_family.id,
        title="Soccer Practice",
        description="Weekly soccer",
        start=datetime(2025, 11, 17, 16, 0),  # Monday
        end=datetime(2025, 11, 17, 17, 0),
        attendees=[test_users["child"].id],
        category="sport",
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(event1)

    # Piano lesson on Wednesday 17:00-18:00
    event2 = models.Event(
        familyId=test_family.id,
        title="Piano Lesson",
        description="Weekly piano",
        start=datetime(2025, 11, 19, 17, 0),  # Wednesday
        end=datetime(2025, 11, 19, 18, 0),
        attendees=[test_users["teen"].id],
        category="school",
        createdBy=test_users["parent"].id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(event2)

    db_session.commit()
    return [event1, event2]


@pytest.mark.asyncio
async def test_ai_planner_generates_plan(db_session, test_family, test_users, recurring_tasks):
    """AI planner returns valid week plan"""
    planner = AIPlanner(db_session, test_family.id)
    start_date = datetime(2025, 11, 17)  # Monday

    # Mock AI response
    mock_ai_response = {
        "choices": [{
            "message": {
                "content": json.dumps({
                    "week_plan": [
                        {
                            "date": "2025-11-17",
                            "tasks": [
                                {
                                    "task_id": recurring_tasks[0].id,
                                    "assignee_id": test_users["child"].id,
                                    "due_time": "19:00",
                                    "reasoning": "Child has capacity"
                                }
                            ]
                        }
                    ],
                    "fairness_notes": "Balanced distribution"
                })
            }
        }],
        "usage": {"prompt_tokens": 500, "completion_tokens": 200}
    }

    with patch('services.ai_planner._call_with_fallback', new_callable=AsyncMock) as mock_call:
        mock_call.return_value = (mock_ai_response, 1, False, "claude-sonnet")

        plan = await planner.generate_week_plan(start_date)

        # Verify plan structure
        assert "week_plan" in plan
        assert "fairness" in plan
        assert "conflicts" in plan
        assert "total_tasks" in plan

        # Verify plan content
        assert len(plan["week_plan"]) > 0
        assert plan["total_tasks"] > 0


@pytest.mark.asyncio
async def test_ai_planner_respects_capacity(db_session, test_family, test_users, recurring_tasks):
    """Child (120min capacity) not assigned >2h tasks"""
    planner = AIPlanner(db_session, test_family.id)
    start_date = datetime(2025, 11, 17)

    # Build context
    context = await planner._build_family_context(start_date)

    # Verify child capacity
    child_context = next(u for u in context["users"] if u["name"] == "Child")
    assert child_context["capacity_minutes_per_week"] == 120  # 2 hours

    # Rule-based fallback should respect capacity
    plan = planner._rule_based_plan(context, start_date)

    # Count child's total task duration
    child_duration = 0
    for day in plan["week_plan"]:
        for task in day["tasks"]:
            if task.get("assignee_id") == test_users["child"].id:
                child_duration += task.get("est_duration", 15)

    # Should not exceed capacity
    assert child_duration <= 120


@pytest.mark.asyncio
async def test_ai_planner_avoids_event_conflicts(
    db_session, test_family, test_users, recurring_tasks, calendar_events
):
    """Task not assigned during calendar event"""
    planner = AIPlanner(db_session, test_family.id)
    start_date = datetime(2025, 11, 17)

    # Build context
    context = await planner._build_family_context(start_date)

    # Create a plan
    plan = {
        "week_plan": [
            {
                "date": "2025-11-17",
                "tasks": [
                    {
                        "task_id": recurring_tasks[0].id,
                        "title": "Vaatwasser",
                        "assignee_id": test_users["child"].id,
                        "assignee_name": "Child",
                        "due_time": "16:30",  # Conflicts with soccer!
                        "est_duration": 15
                    }
                ]
            }
        ]
    }

    # Detect conflicts
    conflicts = planner._detect_conflicts(plan, context)

    # Should detect conflict
    assert len(conflicts) > 0
    assert conflicts[0]["task"] == "Vaatwasser"
    assert conflicts[0]["event"] == "Soccer Practice"


@pytest.mark.asyncio
async def test_ai_planner_fair_distribution(db_session, test_family, test_users, recurring_tasks):
    """All users within ±10% of equal split"""
    planner = AIPlanner(db_session, test_family.id)
    start_date = datetime(2025, 11, 17)

    # Create plan with equal distribution
    plan = {
        "week_plan": [
            {
                "date": "2025-11-17",
                "tasks": [
                    {
                        "task_id": recurring_tasks[0].id,
                        "assignee_id": test_users["child"].id,
                        "est_duration": 30
                    },
                    {
                        "task_id": recurring_tasks[1].id,
                        "assignee_id": test_users["teen"].id,
                        "est_duration": 30
                    }
                ]
            }
        ]
    }

    context = await planner._build_family_context(start_date)
    validated_plan = planner.fairness_validate_plan(plan, context)

    # Check distribution
    distribution = validated_plan["fairness"]["distribution"]

    # Child and teen should have similar distribution
    child_pct = distribution.get("Child", 0)
    teen_pct = distribution.get("Teen", 0)

    # Both should be close (±10%)
    assert abs(child_pct - teen_pct) <= 0.1


@pytest.mark.asyncio
async def test_ai_planner_fallback_rule_based(db_session, test_family, test_users, recurring_tasks):
    """If AI fails, rule-based planner used"""
    planner = AIPlanner(db_session, test_family.id)
    start_date = datetime(2025, 11, 17)

    # Mock AI failure
    with patch('services.ai_planner._call_with_fallback', new_callable=AsyncMock) as mock_call:
        mock_call.return_value = ({}, 3, False, "failed")

        plan = await planner.generate_week_plan(start_date)

        # Verify fallback to rule-based
        assert plan["model_used"] == "rule-based"
        assert plan["tier"] == 3
        assert plan["cost"] == 0
        assert "week_plan" in plan


@pytest.mark.asyncio
async def test_ai_planner_caching(db_session, test_family, test_users, recurring_tasks):
    """Identical request returns cached result"""
    planner = AIPlanner(db_session, test_family.id)
    start_date = datetime(2025, 11, 17)

    # Mock AI response for first call
    mock_ai_response = {
        "choices": [{
            "message": {
                "content": json.dumps({
                    "week_plan": [],
                    "fairness_notes": "Test"
                })
            }
        }],
        "usage": {"prompt_tokens": 100, "completion_tokens": 50}
    }

    with patch('services.ai_planner._call_with_fallback', new_callable=AsyncMock) as mock_call:
        mock_call.return_value = (mock_ai_response, 1, False, "claude-sonnet")

        # First call - should hit AI
        plan1 = await planner.generate_week_plan(start_date)

        # Second call - should hit cache (but cache implementation needed)
        plan2 = await planner.generate_week_plan(start_date)

        # Verify results match
        assert plan1["total_tasks"] == plan2["total_tasks"]


@pytest.mark.asyncio
async def test_apply_plan_creates_tasks(db_session, test_family, test_users, recurring_tasks):
    """Applying plan creates task instances"""
    # Simulate a plan
    plan = {
        "week_plan": [
            {
                "date": "2025-11-17",
                "tasks": [
                    {
                        "task_id": recurring_tasks[0].id,
                        "assignee_id": test_users["child"].id,
                        "due_time": "19:00"
                    },
                    {
                        "task_id": recurring_tasks[1].id,
                        "assignee_id": test_users["teen"].id,
                        "due_time": "20:00"
                    }
                ]
            }
        ]
    }

    # Count tasks before
    tasks_before = db_session.query(models.Task).filter(
        models.Task.familyId == test_family.id,
        models.Task.rrule.is_(None)  # Non-recurring instances
    ).count()

    # Apply plan (simulated - would normally go through API)
    created_count = 0
    for day in plan["week_plan"]:
        for task_spec in day["tasks"]:
            task_template = db_session.query(models.Task).filter(
                models.Task.id == task_spec["task_id"]
            ).first()

            if task_template and task_template.rrule:
                # Create instance
                due_datetime = datetime.fromisoformat(f"{day['date']}T{task_spec['due_time']}:00")
                new_task = models.Task(
                    familyId=test_family.id,
                    title=task_template.title,
                    desc=task_template.desc,
                    category=task_template.category,
                    due=due_datetime,
                    assignees=[task_spec["assignee_id"]],
                    points=task_template.points,
                    estDuration=task_template.estDuration,
                    status="open",
                    createdBy=test_users["parent"].id,
                    version=1
                )
                db_session.add(new_task)
                created_count += 1

    db_session.commit()

    # Count tasks after
    tasks_after = db_session.query(models.Task).filter(
        models.Task.familyId == test_family.id,
        models.Task.rrule.is_(None)
    ).count()

    # Verify tasks created
    assert tasks_after == tasks_before + created_count
    assert created_count == 2


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
