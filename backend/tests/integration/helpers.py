"""
Integration test helper functions.

Provides utility functions for common test operations:
- Family and user creation
- Event and task generation
- Task completion simulation
- Gamification state verification
"""

from datetime import datetime, timedelta
from typing import Dict, List, Optional
from sqlalchemy.orm import Session

from core.models import (
    Family, User, Event, Task, PointsLedger, Badge, UserStreak
)
from core.security import hash_password


def create_test_family(
    db: Session,
    family_name: str = "Test Family",
    num_children: int = 2
) -> Dict:
    """
    Create a test family with configurable number of children.

    Args:
        db: Database session
        family_name: Name of the family
        num_children: Number of child users to create (default: 2)

    Returns:
        Dict containing family and user objects
    """
    # Create family
    family = Family(name=family_name)
    db.add(family)
    db.flush()

    # Create parent
    parent = User(
        familyId=family.id,
        email=f"parent-{family.id}@test.com",
        displayName="Test Parent",
        role="parent",
        passwordHash=hash_password("password123"),
        emailVerified=True
    )
    db.add(parent)

    # Create children
    children = []
    for i in range(num_children):
        child = User(
            familyId=family.id,
            email=f"child{i+1}-{family.id}@test.com",
            displayName=f"Test Child {i+1}",
            role="child",
            pin=hash_password(f"{1234 + i}")
        )
        db.add(child)
        children.append(child)

    db.commit()

    result = {
        "family": family,
        "parent": parent,
        "children": children
    }

    # Add individual child references for convenience
    for i, child in enumerate(children):
        result[f"child{i+1}"] = child

    return result


def generate_test_events(
    db: Session,
    family_id: str,
    created_by: str,
    num_events: int = 10,
    start_date: Optional[datetime] = None
) -> List[Event]:
    """
    Generate realistic test events.

    Args:
        db: Database session
        family_id: Family ID
        created_by: User ID who creates the events
        num_events: Number of events to create
        start_date: Base date for events (default: now)

    Returns:
        List of Event objects
    """
    if start_date is None:
        start_date = datetime.utcnow()

    events = []
    categories = ["school", "sport", "appointment", "family", "other"]

    for i in range(num_events):
        day_offset = i % 7
        hour = 8 + (i % 12)

        event = Event(
            familyId=family_id,
            title=f"Event {i+1}",
            description=f"Test event {i+1}",
            start=(start_date + timedelta(days=day_offset)).replace(hour=hour, minute=0),
            end=(start_date + timedelta(days=day_offset)).replace(hour=hour+1, minute=0),
            category=categories[i % len(categories)],
            createdBy=created_by,
            attendees=[]
        )

        # Add recurrence for some events
        if i % 3 == 0:
            event.rrule = "FREQ=WEEKLY;BYDAY=MO"

        db.add(event)
        events.append(event)

    db.commit()
    return events


def generate_test_tasks(
    db: Session,
    family_id: str,
    assignees: List[str],
    num_tasks: int = 10,
    with_rotation: bool = False
) -> List[Task]:
    """
    Generate realistic test tasks.

    Args:
        db: Database session
        family_id: Family ID
        assignees: List of user IDs who can be assigned
        num_tasks: Number of tasks to create
        with_rotation: Whether to add rotation strategy

    Returns:
        List of Task objects
    """
    tasks = []
    categories = ["cleaning", "care", "pet", "homework", "other"]
    base_date = datetime.utcnow()

    for i in range(num_tasks):
        day_offset = i % 7
        rotation_strategy = "round_robin" if with_rotation else "manual"

        task = Task(
            familyId=family_id,
            title=f"Task {i+1}",
            desc=f"Test task {i+1}",
            category=categories[i % len(categories)],
            due=(base_date + timedelta(days=day_offset)).replace(hour=12, minute=0),
            frequency="daily" if with_rotation else "none",
            rrule="FREQ=DAILY" if with_rotation else None,
            rotationStrategy=rotation_strategy,
            rotationState={"currentIndex": 0} if with_rotation else {},
            assignees=assignees if with_rotation else [assignees[i % len(assignees)]],
            points=10 + (i % 5) * 5,
            status="open"
        )

        # Add special requirements for some tasks
        if i % 4 == 0:
            task.photoRequired = True
        if i % 5 == 0:
            task.parentApproval = True

        db.add(task)
        tasks.append(task)

    db.commit()
    return tasks


def complete_task_as_user(
    db: Session,
    task_id: str,
    user_id: str,
    with_photo: bool = False,
    rating: Optional[int] = None
) -> Task:
    """
    Simulate task completion by a user.

    Args:
        db: Database session
        task_id: Task ID to complete
        user_id: User ID completing the task
        with_photo: Whether to include photo proof
        rating: Parent rating (1-5 stars)

    Returns:
        Updated Task object
    """
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise ValueError(f"Task {task_id} not found")

    # Update task status
    if task.parentApproval:
        task.status = "pendingApproval"
    else:
        task.status = "done"

    task.claimedBy = user_id
    task.claimedAt = datetime.utcnow()

    # Simulate photo upload
    if with_photo and task.photoRequired:
        # In real implementation, this would store photo URL
        task.desc += " [Photo uploaded]"

    db.commit()
    db.refresh(task)
    return task


def verify_gamification_state(
    db: Session,
    user_id: str,
    expected_points: Optional[int] = None,
    expected_streak: Optional[int] = None,
    expected_badges: Optional[List[str]] = None
) -> Dict:
    """
    Verify gamification state for a user.

    Args:
        db: Database session
        user_id: User ID to check
        expected_points: Expected total points
        expected_streak: Expected current streak
        expected_badges: List of expected badge IDs

    Returns:
        Dict with actual gamification state

    Raises:
        AssertionError if expectations don't match
    """
    # Calculate total points
    total_points = db.query(
        db.func.sum(PointsLedger.points)
    ).filter(
        PointsLedger.userId == user_id
    ).scalar() or 0

    # Get current streak
    streak = db.query(UserStreak).filter(
        UserStreak.userId == user_id
    ).first()
    current_streak = streak.currentStreak if streak else 0

    # Get badges
    badges = db.query(Badge).filter(
        Badge.userId == user_id
    ).all()
    badge_ids = [badge.badgeType for badge in badges]

    # Verify expectations
    if expected_points is not None:
        assert total_points == expected_points, \
            f"Expected {expected_points} points, got {total_points}"

    if expected_streak is not None:
        assert current_streak == expected_streak, \
            f"Expected {expected_streak} streak, got {current_streak}"

    if expected_badges is not None:
        for badge_id in expected_badges:
            assert badge_id in badge_ids, \
                f"Expected badge {badge_id} not found. Got: {badge_ids}"

    return {
        "total_points": total_points,
        "current_streak": current_streak,
        "badge_ids": badge_ids
    }


def create_recurring_task_with_occurrences(
    db: Session,
    family_id: str,
    assignees: List[str],
    title: str = "Recurring Task",
    rrule: str = "FREQ=DAILY",
    num_days: int = 7
) -> Task:
    """
    Create a recurring task and generate occurrences.

    Args:
        db: Database session
        family_id: Family ID
        assignees: List of user IDs for rotation
        title: Task title
        rrule: Recurrence rule (RRULE format)
        num_days: Number of days to expand

    Returns:
        Created Task object
    """
    task = Task(
        familyId=family_id,
        title=title,
        desc=f"Recurring task with rule: {rrule}",
        category="cleaning",
        due=datetime.utcnow().replace(hour=8, minute=0),
        frequency="custom",
        rrule=rrule,
        rotationStrategy="round_robin",
        rotationState={"currentIndex": 0, "lastRotation": datetime.utcnow().isoformat()},
        assignees=assignees,
        points=10,
        status="open"
    )

    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def simulate_offline_sync(
    db: Session,
    operations: List[Dict]
) -> Dict:
    """
    Simulate offline operations and sync.

    Args:
        db: Database session
        operations: List of operation dicts with keys:
            - type: "create", "update", "delete"
            - entity: "task", "event"
            - data: Entity data

    Returns:
        Dict with sync results
    """
    results = {
        "created": 0,
        "updated": 0,
        "deleted": 0,
        "conflicts": []
    }

    for op in operations:
        op_type = op["type"]
        entity_type = op["entity"]
        data = op["data"]

        try:
            if op_type == "create":
                if entity_type == "task":
                    task = Task(**data)
                    db.add(task)
                    results["created"] += 1
                elif entity_type == "event":
                    event = Event(**data)
                    db.add(event)
                    results["created"] += 1

            elif op_type == "update":
                # Simulate optimistic locking check
                if entity_type == "task":
                    task = db.query(Task).filter(Task.id == data["id"]).first()
                    if task:
                        for key, value in data.items():
                            if key != "id":
                                setattr(task, key, value)
                        results["updated"] += 1

            elif op_type == "delete":
                if entity_type == "task":
                    task = db.query(Task).filter(Task.id == data["id"]).first()
                    if task:
                        db.delete(task)
                        results["deleted"] += 1

            db.commit()

        except Exception as e:
            results["conflicts"].append({
                "operation": op,
                "error": str(e)
            })
            db.rollback()

    return results


def create_performance_test_data(
    db: Session,
    family_id: str,
    created_by: str,
    num_events: int = 100,
    num_tasks: int = 1000
) -> Dict:
    """
    Create large dataset for performance testing.

    Args:
        db: Database session
        family_id: Family ID
        created_by: User ID
        num_events: Number of events to create
        num_tasks: Number of tasks to create

    Returns:
        Dict with creation summary
    """
    start_time = datetime.utcnow()

    # Create events in batches
    events = []
    for i in range(num_events):
        event = Event(
            familyId=family_id,
            title=f"Perf Event {i+1}",
            description=f"Performance test event {i+1}",
            start=datetime.utcnow() + timedelta(days=i % 365),
            end=datetime.utcnow() + timedelta(days=i % 365, hours=1),
            category=["school", "sport", "appointment", "family", "other"][i % 5],
            createdBy=created_by,
            attendees=[]
        )
        events.append(event)

        # Batch commit every 100 items
        if len(events) >= 100:
            db.bulk_save_objects(events)
            db.commit()
            events = []

    if events:
        db.bulk_save_objects(events)
        db.commit()

    # Create tasks in batches
    tasks = []
    for i in range(num_tasks):
        task = Task(
            familyId=family_id,
            title=f"Perf Task {i+1}",
            desc=f"Performance test task {i+1}",
            category=["cleaning", "care", "pet", "homework", "other"][i % 5],
            due=datetime.utcnow() + timedelta(days=i % 30),
            frequency="none",
            assignees=[created_by],
            points=10,
            status=["open", "done"][i % 2]
        )
        tasks.append(task)

        # Batch commit every 100 items
        if len(tasks) >= 100:
            db.bulk_save_objects(tasks)
            db.commit()
            tasks = []

    if tasks:
        db.bulk_save_objects(tasks)
        db.commit()

    end_time = datetime.utcnow()
    duration = (end_time - start_time).total_seconds()

    return {
        "events_created": num_events,
        "tasks_created": num_tasks,
        "duration_seconds": duration,
        "creation_rate": (num_events + num_tasks) / duration if duration > 0 else 0
    }
