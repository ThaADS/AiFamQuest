"""
Calendar & Events API Router

Provides CRUD operations for family calendar events with:
- Recurring events (RRULE support)
- Attendee management
- Access control (parent/teen/child/helper)
- Month/week views
- Filtering by user, category, date range
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from typing import Optional, List
from datetime import datetime, timedelta
from dateutil.rrule import rrulestr, rrule
import pytz

from core.db import SessionLocal
from core import models
from core.deps import get_current_user, require_role
from core.schemas import EventCreate, EventUpdate, EventOut
from routers.util import audit

router = APIRouter()


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

    Examples:
    - "FREQ=DAILY"
    - "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    - "FREQ=MONTHLY;BYMONTHDAY=15"

    Returns: True if valid, False otherwise
    """
    if not rrule_str:
        return True
    try:
        # Try to parse with a dummy start date
        rrulestr(rrule_str, dtstart=datetime.utcnow())
        return True
    except Exception:
        return False


def expand_recurring_event(event: models.Event, start_date: datetime, end_date: datetime, max_occurrences: int = 365) -> List[dict]:
    """
    Expand recurring event based on RRULE.

    Args:
        event: Event model with rrule
        start_date: Start of date range
        end_date: End of date range
        max_occurrences: Maximum occurrences to return (safety limit)

    Returns:
        List of event occurrences with expanded dates
    """
    if not event.rrule:
        # Non-recurring event
        if event.start >= start_date and event.start <= end_date:
            return [{
                "id": event.id,
                "title": event.title,
                "description": event.description,
                "start": event.start,
                "end": event.end,
                "allDay": event.allDay,
                "attendees": event.attendees,
                "color": event.color,
                "category": event.category,
                "familyId": event.familyId,
                "createdBy": event.createdBy,
                "isRecurring": False,
                "originalStart": event.start,
            }]
        return []

    # Recurring event - expand occurrences
    try:
        rule = rrulestr(event.rrule, dtstart=event.start)
        occurrences = []

        # Generate occurrences within date range
        for occurrence_start in rule:
            if len(occurrences) >= max_occurrences:
                break

            if occurrence_start > end_date:
                break

            if occurrence_start >= start_date:
                # Calculate end time if present
                occurrence_end = None
                if event.end:
                    duration = event.end - event.start
                    occurrence_end = occurrence_start + duration

                occurrences.append({
                    "id": f"{event.id}_{occurrence_start.isoformat()}",
                    "title": event.title,
                    "description": event.description,
                    "start": occurrence_start,
                    "end": occurrence_end,
                    "allDay": event.allDay,
                    "attendees": event.attendees,
                    "color": event.color,
                    "category": event.category,
                    "familyId": event.familyId,
                    "createdBy": event.createdBy,
                    "isRecurring": True,
                    "originalEventId": event.id,
                    "originalStart": event.start,
                    "rrule": event.rrule,
                })

        return occurrences
    except Exception as e:
        # If expansion fails, return empty list
        return []


def check_event_access(event: models.Event, user: models.User) -> bool:
    """
    Check if user has access to view/modify event.

    Access rules:
    - Parents: Can view/edit all family events
    - Teens: Can view all, create own events
    - Children: Can view events where they are attendees
    - Helpers: No calendar access

    Returns: True if user has access
    """
    # Parents have full access
    if user.role == "parent":
        return True

    # Helpers have no calendar access
    if user.role == "helper":
        return False

    # Teens can view all family events
    if user.role == "teen":
        return True

    # Children can only view events where they are attendees
    if user.role == "child":
        return user.id in event.attendees or event.createdBy == user.id

    return False


@router.get("", response_model=List[dict])
def list_events(
    d: Session = Depends(db),
    payload = Depends(get_current_user),
    familyId: Optional[str] = Query(None, description="Filter by family ID"),
    userId: Optional[str] = Query(None, description="Filter by attendee user ID"),
    start_date: Optional[datetime] = Query(None, description="Start date filter (ISO format)"),
    end_date: Optional[datetime] = Query(None, description="End date filter (ISO format)"),
    category: Optional[str] = Query(None, description="Filter by category"),
    limit: int = Query(100, ge=1, le=1000, description="Max results"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
):
    """
    List events with filtering and pagination.

    Query parameters:
    - familyId: Filter by family (defaults to user's family)
    - userId: Filter by attendee
    - start_date: Start of date range
    - end_date: End of date range
    - category: Event category (school|sport|appointment|family|other)
    - limit: Max results (default 100)
    - offset: Pagination offset

    Returns expanded recurring events for the specified date range.
    Applies access control based on user role.
    """
    # Get current user
    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    # Helpers have no calendar access
    if current_user.role == "helper":
        raise HTTPException(403, "Helpers do not have calendar access")

    # Default to user's family if not specified
    if not familyId:
        familyId = current_user.familyId

    # Verify user belongs to family
    if current_user.familyId != familyId:
        raise HTTPException(403, "Cannot access other families' events")

    # Build query
    query = d.query(models.Event).filter_by(familyId=familyId)

    # Apply category filter
    if category:
        query = query.filter_by(category=category)

    # Apply date range filter (get events that might have occurrences in range)
    if start_date and end_date:
        # For recurring events, we need to check if they started before end_date
        # For non-recurring, check if they fall in range
        query = query.filter(
            or_(
                and_(models.Event.rrule.isnot(None), models.Event.start <= end_date),
                and_(models.Event.rrule.is_(None), models.Event.start >= start_date, models.Event.start <= end_date)
            )
        )

    events = query.order_by(models.Event.start).all()

    # Expand recurring events and apply access control
    expanded_events = []
    for event in events:
        # Check access
        if not check_event_access(event, current_user):
            continue

        # Apply userId filter (attendee)
        if userId and userId not in event.attendees:
            continue

        # Expand recurring events or add single event
        if start_date and end_date:
            occurrences = expand_recurring_event(event, start_date, end_date)
            expanded_events.extend(occurrences)
        else:
            # No date range - return base event
            expanded_events.append({
                "id": event.id,
                "title": event.title,
                "description": event.description,
                "start": event.start,
                "end": event.end,
                "allDay": event.allDay,
                "attendees": event.attendees,
                "color": event.color,
                "category": event.category,
                "familyId": event.familyId,
                "createdBy": event.createdBy,
                "isRecurring": bool(event.rrule),
                "rrule": event.rrule,
            })

    # Apply pagination
    total = len(expanded_events)
    paginated = expanded_events[offset:offset + limit]

    return paginated


@router.get("/{event_id}", response_model=EventOut)
def get_event(
    event_id: str,
    d: Session = Depends(db),
    payload = Depends(get_current_user)
):
    """
    Get single event by ID.

    Returns base event (not expanded occurrences).
    Applies access control based on user role.
    """
    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    event = d.query(models.Event).filter_by(id=event_id).first()
    if not event:
        raise HTTPException(404, "Event not found")

    # Verify family access
    if event.familyId != current_user.familyId:
        raise HTTPException(403, "Cannot access other families' events")

    # Check event access
    if not check_event_access(event, current_user):
        raise HTTPException(403, "No access to this event")

    return event


@router.post("", response_model=EventOut)
def create_event(
    body: EventCreate,
    d: Session = Depends(db),
    payload = Depends(require_role(["parent", "teen"]))
):
    """
    Create new event.

    Validation:
    - Start < end (if end provided)
    - Attendees exist in family
    - RRULE is valid format

    Access control:
    - Parents: Can create any event
    - Teens: Can create own events
    - Children/Helpers: Cannot create events
    """
    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    # Validate dates
    if body.end and body.start >= body.end:
        raise HTTPException(400, "Start time must be before end time")

    # Validate RRULE
    if body.rrule and not validate_rrule(body.rrule):
        raise HTTPException(400, "Invalid RRULE format")

    # Validate attendees exist in family
    if body.attendees:
        attendee_users = d.query(models.User).filter(
            models.User.id.in_(body.attendees),
            models.User.familyId == current_user.familyId
        ).all()

        if len(attendee_users) != len(body.attendees):
            raise HTTPException(400, "One or more attendees not found in family")

    # Create event
    event = models.Event(
        id=str(__import__("uuid").uuid4()),
        familyId=current_user.familyId,
        title=body.title,
        description=body.description,
        start=body.start,
        end=body.end,
        allDay=body.allDay,
        attendees=body.attendees,
        color=body.color,
        rrule=body.rrule,
        category=body.category,
        createdBy=current_user.id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
    )

    d.add(event)
    d.commit()
    d.refresh(event)

    # Audit log
    audit(d, actorUserId=current_user.id, familyId=current_user.familyId,
          action="event.create", meta=event.title)

    return event


@router.put("/{event_id}", response_model=EventOut)
def update_event(
    event_id: str,
    body: EventUpdate,
    d: Session = Depends(db),
    payload = Depends(require_role(["parent", "teen"]))
):
    """
    Update existing event.

    For recurring events:
    - Updates all future occurrences
    - To update single occurrence, create exception event

    Access control:
    - Parents: Can update any family event
    - Teens: Can update own events only
    """
    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    event = d.query(models.Event).filter_by(id=event_id).first()
    if not event:
        raise HTTPException(404, "Event not found")

    # Verify family access
    if event.familyId != current_user.familyId:
        raise HTTPException(403, "Cannot access other families' events")

    # Teens can only update own events
    if current_user.role == "teen" and event.createdBy != current_user.id:
        raise HTTPException(403, "Can only update own events")

    # Validate dates
    if body.end and body.start >= body.end:
        raise HTTPException(400, "Start time must be before end time")

    # Validate RRULE
    if body.rrule and not validate_rrule(body.rrule):
        raise HTTPException(400, "Invalid RRULE format")

    # Validate attendees
    if body.attendees:
        attendee_users = d.query(models.User).filter(
            models.User.id.in_(body.attendees),
            models.User.familyId == current_user.familyId
        ).all()

        if len(attendee_users) != len(body.attendees):
            raise HTTPException(400, "One or more attendees not found in family")

    # Update fields
    event.title = body.title
    event.description = body.description
    event.start = body.start
    event.end = body.end
    event.allDay = body.allDay
    event.attendees = body.attendees
    event.color = body.color
    event.rrule = body.rrule
    event.category = body.category
    event.updatedAt = datetime.utcnow()

    d.commit()
    d.refresh(event)

    # Audit log
    audit(d, actorUserId=current_user.id, familyId=current_user.familyId,
          action="event.update", meta=event.title)

    return event


@router.delete("/{event_id}")
def delete_event(
    event_id: str,
    d: Session = Depends(db),
    payload = Depends(require_role(["parent", "teen"]))
):
    """
    Delete event.

    For recurring events, deletes the series.
    To delete single occurrence, create exception or modify RRULE.

    Access control:
    - Parents: Can delete any family event
    - Teens: Can delete own events only
    """
    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    event = d.query(models.Event).filter_by(id=event_id).first()
    if not event:
        raise HTTPException(404, "Event not found")

    # Verify family access
    if event.familyId != current_user.familyId:
        raise HTTPException(403, "Cannot access other families' events")

    # Teens can only delete own events
    if current_user.role == "teen" and event.createdBy != current_user.id:
        raise HTTPException(403, "Can only delete own events")

    # Audit log before deletion
    audit(d, actorUserId=current_user.id, familyId=current_user.familyId,
          action="event.delete", meta=event.title)

    # Delete event
    d.delete(event)
    d.commit()

    return {"status": "deleted", "id": event_id}


@router.get("/calendar/{year}/{month}", response_model=List[dict])
def get_month_view(
    year: int,
    month: int,
    d: Session = Depends(db),
    payload = Depends(get_current_user)
):
    """
    Get month view data.

    Returns all events for the specified month with recurring events expanded.

    Args:
        year: Calendar year (e.g., 2025)
        month: Calendar month (1-12)

    Returns:
        List of events (expanded occurrences) for the month
    """
    # Validate month
    if month < 1 or month > 12:
        raise HTTPException(400, "Invalid month (must be 1-12)")

    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    # Helpers have no calendar access
    if current_user.role == "helper":
        raise HTTPException(403, "Helpers do not have calendar access")

    # Calculate month start/end
    start_date = datetime(year, month, 1)
    if month == 12:
        end_date = datetime(year + 1, 1, 1) - timedelta(seconds=1)
    else:
        end_date = datetime(year, month + 1, 1) - timedelta(seconds=1)

    # Get events for family
    events = d.query(models.Event).filter_by(familyId=current_user.familyId).all()

    # Expand recurring events
    expanded_events = []
    for event in events:
        # Check access
        if not check_event_access(event, current_user):
            continue

        occurrences = expand_recurring_event(event, start_date, end_date)
        expanded_events.extend(occurrences)

    # Sort by start time
    expanded_events.sort(key=lambda e: e["start"])

    return expanded_events


@router.get("/week/current", response_model=List[dict])
def get_current_week(
    d: Session = Depends(db),
    payload = Depends(get_current_user)
):
    """
    Get current week events.

    Returns events from Monday to Sunday of current week.
    """
    current_user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not current_user:
        raise HTTPException(404, "User not found")

    # Helpers have no calendar access
    if current_user.role == "helper":
        raise HTTPException(403, "Helpers do not have calendar access")

    # Calculate current week (Monday to Sunday)
    today = datetime.utcnow()
    weekday = today.weekday()
    start_date = today - timedelta(days=weekday)
    start_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_date = start_date + timedelta(days=7) - timedelta(seconds=1)

    # Get events for family
    events = d.query(models.Event).filter_by(familyId=current_user.familyId).all()

    # Expand recurring events
    expanded_events = []
    for event in events:
        # Check access
        if not check_event_access(event, current_user):
            continue

        occurrences = expand_recurring_event(event, start_date, end_date)
        expanded_events.extend(occurrences)

    # Sort by start time
    expanded_events.sort(key=lambda e: e["start"])

    return expanded_events


def get_busy_hours(user_id: str, date: datetime, d: Session) -> List[tuple]:
    """
    Helper function for AI planner integration.

    Returns list of (start_time, end_time) tuples for events where user is attendee.
    Used to avoid scheduling tasks during event times.

    Args:
        user_id: User ID
        date: Date to check
        d: Database session

    Returns:
        List of (start_datetime, end_datetime) tuples
    """
    # Get day boundaries
    start_of_day = date.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day = start_of_day + timedelta(days=1) - timedelta(seconds=1)

    # Get user's family events
    user = d.query(models.User).filter_by(id=user_id).first()
    if not user:
        return []

    events = d.query(models.Event).filter_by(familyId=user.familyId).all()

    busy_hours = []
    for event in events:
        # Check if user is attendee
        if user_id not in event.attendees:
            continue

        # Expand event for this day
        occurrences = expand_recurring_event(event, start_of_day, end_of_day)

        for occurrence in occurrences:
            if occurrence["end"]:
                busy_hours.append((occurrence["start"], occurrence["end"]))
            else:
                # All-day or no end time - block whole day
                busy_hours.append((occurrence["start"], end_of_day))

    return busy_hours
