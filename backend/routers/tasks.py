"""
Tasks API Router with Recurrence, Rotation, and Fairness Engine

Features:
- CRUD operations for tasks
- Recurring task support (RRULE)
- Rotation strategies (round-robin, fairness, manual, random)
- Fairness engine for workload balancing
- Task generation from recurring templates
- Occurrence management (skip, complete series)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_
from uuid import uuid4
from datetime import datetime, date, timedelta
from typing import List, Optional
from dateutil.rrule import rrulestr

from core.db import SessionLocal
from core import models
from core.deps import get_current_user, require_role
from core.schemas import (
    TaskIn, TaskOut, TaskUpdate, FairnessReportOut, TaskOccurrenceOut
)
from core.fairness import FairnessEngine
from services.task_generator import TaskGenerator
from services.gamification_service import GamificationService
from services.notification_service import NotificationService
from routers.util import audit

router = APIRouter()

# Initialize gamification service
gamification_service = GamificationService()


def db():
    """Database session dependency"""
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


def validate_rrule(rrule_str: str) -> bool:
    """
    Validate RRULE string format.

    Returns: True if valid, False otherwise
    """
    if not rrule_str:
        return True
    try:
        rrulestr(rrule_str, dtstart=datetime.utcnow())
        return True
    except Exception:
        return False


@router.get("", response_model=List[TaskOut])
def list_tasks(
    d: Session = Depends(db),
    payload=Depends(get_current_user),
    status: Optional[str] = Query(None, description="Filter by status"),
    assignee_id: Optional[str] = Query(None, description="Filter by assignee"),
    claimable_only: bool = Query(False, description="Show only claimable tasks"),
    include_recurring: bool = Query(True, description="Include recurring templates"),
):
    """
    List all tasks for user's family with filtering.

    Query parameters:
    - status: Filter by task status (open|pendingApproval|done)
    - assignee_id: Filter by assignee user ID
    - claimable_only: Show only claimable tasks
    - include_recurring: Include recurring task templates
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    familyId = user.familyId

    # Build query
    query = d.query(models.Task).filter_by(familyId=familyId)

    # Apply filters
    if status:
        query = query.filter_by(status=status)

    if assignee_id:
        query = query.filter(models.Task.assignees.contains([assignee_id]))

    if claimable_only:
        query = query.filter_by(claimable=True, status="open")

    if not include_recurring:
        # Exclude recurring templates (those with rrule)
        query = query.filter(models.Task.rrule.is_(None))

    tasks = query.order_by(models.Task.due.asc().nullslast()).all()

    return tasks


@router.get("/recurring", response_model=List[TaskOut])
def list_recurring_tasks(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    List all recurring task templates for user's family.

    Returns only tasks with rrule defined.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    generator = TaskGenerator(d)
    recurring_tasks = generator.get_recurring_templates(user.familyId)

    return recurring_tasks


@router.get("/occurrences", response_model=List[TaskOccurrenceOut])
def get_task_occurrences(
    start: date = Query(..., description="Start date (YYYY-MM-DD)"),
    end: date = Query(..., description="End date (YYYY-MM-DD)"),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get all task occurrences (generated and pending) for date range.

    Expands recurring tasks and shows their occurrences.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    generator = TaskGenerator(d)
    recurring_tasks = generator.get_recurring_templates(user.familyId)

    all_occurrences = []
    for task in recurring_tasks:
        occurrences = generator.get_task_occurrences(task.id, start, end)
        all_occurrences.extend(occurrences)

    return all_occurrences


@router.post("", response_model=TaskOut)
def create_task(
    body: TaskIn,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Create new task (single or recurring template).

    For recurring tasks:
    - Provide rrule (e.g., "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,WE,FR")
    - Specify rotationStrategy (round_robin|fairness|manual|random)
    - Provide list of eligible assignees

    For single tasks:
    - Leave rrule as None
    - Provide single assignee
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Validate RRULE if provided
    if body.rrule and not validate_rrule(body.rrule):
        raise HTTPException(400, "Invalid RRULE format")

    # Validate assignees exist in family
    if body.assignees:
        assignee_users = d.query(models.User).filter(
            models.User.id.in_(body.assignees),
            models.User.familyId == user.familyId
        ).all()

        if len(assignee_users) != len(body.assignees):
            raise HTTPException(400, "One or more assignees not found in family")

    # Create task
    task = models.Task(
        id=str(uuid4()),
        familyId=user.familyId,
        title=body.title,
        desc=body.desc,
        category=body.category,
        due=body.due,
        frequency=body.frequency,
        rrule=body.rrule,
        rotationStrategy=body.rotationStrategy,
        rotationState={},
        assignees=body.assignees,
        claimable=body.claimable,
        status="open",
        points=body.points,
        photoRequired=body.photoRequired,
        parentApproval=body.parentApproval,
        proofPhotos=[],
        priority=body.priority,
        estDuration=body.estDuration,
        createdBy=user.id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )

    d.add(task)
    d.commit()
    d.refresh(task)

    # Audit log
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="task.create", meta=task.title)

    return task


@router.put("/{task_id}", response_model=TaskOut)
def update_task(
    task_id: str,
    body: TaskUpdate,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Update existing task.

    For recurring templates, updates all future occurrences.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    task = d.query(models.Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    # Verify family access
    if task.familyId != user.familyId:
        raise HTTPException(403, "Cannot access other families' tasks")

    # Validate RRULE if provided
    if body.rrule and not validate_rrule(body.rrule):
        raise HTTPException(400, "Invalid RRULE format")

    # Update fields (only if provided)
    if body.title is not None:
        task.title = body.title
    if body.desc is not None:
        task.desc = body.desc
    if body.due is not None:
        task.due = body.due
    if body.assignees is not None:
        task.assignees = body.assignees
    if body.points is not None:
        task.points = body.points
    if body.category is not None:
        task.category = body.category
    if body.frequency is not None:
        task.frequency = body.frequency
    if body.rrule is not None:
        task.rrule = body.rrule
    if body.rotationStrategy is not None:
        task.rotationStrategy = body.rotationStrategy
    if body.estDuration is not None:
        task.estDuration = body.estDuration
    if body.priority is not None:
        task.priority = body.priority
    if body.photoRequired is not None:
        task.photoRequired = body.photoRequired
    if body.parentApproval is not None:
        task.parentApproval = body.parentApproval
    if body.claimable is not None:
        task.claimable = body.claimable
    if body.status is not None:
        task.status = body.status

    task.updatedAt = datetime.utcnow()
    task.version += 1

    d.commit()
    d.refresh(task)

    # Audit log
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="task.update", meta=task.title)

    return task


@router.post("/{task_id}/complete")
async def complete_task(
    task_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Mark task as completed with gamification rewards.

    For recurring task instances, marks single occurrence as done.
    For recurring templates, use /complete-series instead.

    Returns:
        - task: Updated task object
        - gamification: Points, badges, streak, and achievements earned
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    task = d.query(models.Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    # Verify family access
    if task.familyId != user.familyId:
        raise HTTPException(403, "Cannot access other families' tasks")

    # Update task status
    completion_time = datetime.utcnow()
    task.status = "pendingApproval" if task.parentApproval else "done"
    task.completedBy = user.id
    task.completedAt = completion_time
    task.updatedAt = completion_time
    task.version += 1

    # Create task completion log for badge tracking
    task_log = models.TaskLog(
        id=str(uuid4()),
        taskId=task_id,
        userId=user.id,
        action="completed",
        metadata={},
        createdAt=completion_time
    )
    d.add(task_log)
    d.flush()

    # Trigger gamification system
    gamification_result = gamification_service.on_task_completed(
        task=task,
        user=user,
        completion_time=completion_time,
        db=d,
        approval_rating=None  # Will be updated on parent approval
    )

    # Send notifications
    notification_service = NotificationService(d)

    if task.parentApproval:
        # Notify parent: approval requested
        parent = d.query(models.User).filter(
            models.User.familyId == task.familyId,
            models.User.role == 'parent'
        ).first()

        if parent:
            await notification_service.send_notification(
                user_id=parent.id,
                notification_type='task_approval_requested',
                title=f'{user.displayName} completed a task',
                body=f'Task "{task.title}" needs your approval',
                data={'task_id': task_id, 'completed_by': user.id},
                action_url=f'/tasks/{task_id}/approve'
            )
    else:
        # Notify parent: task completed (FYI)
        parent = d.query(models.User).filter(
            models.User.familyId == task.familyId,
            models.User.role == 'parent'
        ).first()

        if parent:
            await notification_service.send_notification(
                user_id=parent.id,
                notification_type='task_completed',
                title=f'{user.displayName} completed a task',
                body=f'Task "{task.title}" is done',
                data={'task_id': task_id, 'completed_by': user.id}
            )

    # Audit log
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="task.complete", meta=task.title)

    d.commit()
    d.refresh(task)

    return {
        "task": task,
        "gamification": gamification_result
    }


@router.post("/{task_id}/skip-occurrence")
def skip_task_occurrence(
    task_id: str,
    occurrence_date: date = Query(..., description="Date to skip (YYYY-MM-DD)"),
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Skip specific occurrence of recurring task.

    Prevents generation of task instance for this date.
    Parent-only operation.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    task = d.query(models.Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    # Verify family access
    if task.familyId != user.familyId:
        raise HTTPException(403, "Cannot access other families' tasks")

    # Verify task is recurring
    if not task.rrule:
        raise HTTPException(400, "Task is not recurring")

    # Skip occurrence
    generator = TaskGenerator(d)
    success = generator.skip_task_occurrence(task_id, occurrence_date, user.id)

    if not success:
        raise HTTPException(400, "Cannot skip occurrence (already generated or skipped)")

    # Audit log
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="task.skip_occurrence", meta=f"{task.title} on {occurrence_date}")

    return {"status": "skipped", "task_id": task_id, "occurrence_date": occurrence_date.isoformat()}


@router.post("/{task_id}/complete-series")
def complete_task_series(
    task_id: str,
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Complete entire recurring task series.

    Marks template as done, stopping future occurrence generation.
    Parent-only operation.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    task = d.query(models.Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    # Verify family access
    if task.familyId != user.familyId:
        raise HTTPException(403, "Cannot access other families' tasks")

    # Verify task is recurring
    if not task.rrule:
        raise HTTPException(400, "Task is not recurring")

    # Complete series
    generator = TaskGenerator(d)
    success = generator.complete_series(task_id, user.id)

    if not success:
        raise HTTPException(500, "Failed to complete series")

    # Audit log
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="task.complete_series", meta=task.title)

    return {"status": "completed", "task_id": task_id}


@router.post("/generate-week")
def generate_week_tasks(
    week_start: date = Query(..., description="Start of week (Monday, YYYY-MM-DD)"),
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Generate all recurring tasks for specified week.

    Expands RRULE for all recurring templates and creates task instances
    with rotation applied.

    Parent-only operation.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Calculate week end (7 days after start)
    week_end = week_start + timedelta(days=7)

    # Generate tasks
    generator = TaskGenerator(d)
    generated_tasks = generator.generate_recurring_tasks(
        user.familyId,
        week_start,
        week_end
    )

    # Audit log
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="tasks.generate_week",
          meta=f"Generated {len(generated_tasks)} tasks for week {week_start}")

    return {
        "status": "generated",
        "week_start": week_start.isoformat(),
        "week_end": week_end.isoformat(),
        "count": len(generated_tasks),
        "task_ids": [t.id for t in generated_tasks]
    }


@router.post("/{task_id}/rotate-assignee")
def rotate_task_assignee(
    task_id: str,
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Manually trigger rotation for next occurrence.

    Applies rotation strategy to determine next assignee.
    Parent-only operation.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    task = d.query(models.Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    # Verify family access
    if task.familyId != user.familyId:
        raise HTTPException(403, "Cannot access other families' tasks")

    # Verify task is recurring
    if not task.rrule:
        raise HTTPException(400, "Task is not recurring")

    # Get next occurrence date (tomorrow for testing)
    next_occurrence = date.today() + timedelta(days=1)

    # Apply rotation
    fairness_engine = FairnessEngine(d)
    next_assignee = fairness_engine.rotate_assignee(task, next_occurrence)

    if not next_assignee:
        return {
            "status": "manual_assignment_required",
            "task_id": task_id,
            "strategy": task.rotationStrategy
        }

    return {
        "status": "rotated",
        "task_id": task_id,
        "next_assignee": next_assignee,
        "occurrence_date": next_occurrence.isoformat(),
        "strategy": task.rotationStrategy
    }


@router.get("/fairness", response_model=FairnessReportOut)
def get_fairness_report(
    week_start: Optional[date] = Query(None, description="Start of week (defaults to current week)"),
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Get fairness distribution report for parent dashboard.

    Shows:
    - Workload percentage per user
    - Users at/over capacity
    - Users under-utilized
    - Recommendations for balancing
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Default to current week if not specified
    if not week_start:
        today = date.today()
        week_start = today - timedelta(days=today.weekday())

    week_end = week_start + timedelta(days=7)

    # Calculate fairness scores
    fairness_engine = FairnessEngine(d)
    fairness_scores = fairness_engine.calculate_fairness_score(user.familyId, week_start)

    # Identify over/under capacity users
    over_capacity = []
    under_capacity = []

    for user_id, workload in fairness_scores.items():
        if workload >= 0.9:
            over_capacity.append(user_id)
        elif workload < 0.5:
            under_capacity.append(user_id)

    # Generate recommendations
    recommendations = []

    if over_capacity:
        recommendations.append({
            "type": "warning",
            "message": f"{len(over_capacity)} user(s) at/over capacity",
            "action": "Consider reassigning some tasks or adjusting rotation strategy"
        })

    if under_capacity and over_capacity:
        recommendations.append({
            "type": "suggestion",
            "message": "Workload imbalance detected",
            "action": "Use fairness rotation strategy to auto-balance"
        })

    if not over_capacity and not under_capacity:
        recommendations.append({
            "type": "success",
            "message": "Workload is well-balanced across family",
            "action": "Continue current rotation strategy"
        })

    return FairnessReportOut(
        fairness_scores=fairness_scores,
        week_start=week_start,
        week_end=week_end,
        recommendations=recommendations,
        over_capacity=over_capacity,
        under_capacity=under_capacity
    )


@router.delete("/{task_id}")
def delete_task(
    task_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Delete task.

    For recurring templates, deletes the template (stops future generation).
    For task instances, deletes the single occurrence.
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    task = d.query(models.Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    # Verify family access
    if task.familyId != user.familyId:
        raise HTTPException(403, "Cannot access other families' tasks")

    # Only parents can delete tasks
    if user.role not in ["parent"]:
        raise HTTPException(403, "Only parents can delete tasks")

    # Audit log before deletion
    audit(d, actorUserId=user.id, familyId=user.familyId,
          action="task.delete", meta=task.title)

    # Delete task
    d.delete(task)
    d.commit()

    return {"status": "deleted", "id": task_id}
