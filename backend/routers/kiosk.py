"""
Kiosk Mode API Router

Provides endpoints for kiosk/tablet display mode:
- Today's schedule (tasks + events) for all family members
- Week overview (7-day summary)
- PIN verification for kiosk exit

Kiosk mode is a fullscreen PWA view for wall-mounted tablets showing
family task schedules and calendar events. Requires PIN to exit.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import List
from datetime import datetime, date, timedelta
from dateutil.rrule import rrulestr

from core.db import SessionLocal
from core import models
from core.deps import get_current_user
from core.schemas import (
    KioskTodayOut, KioskWeekOut, KioskMemberOut, KioskTaskOut,
    KioskEventOut, KioskDayOut, KioskPinVerifyReq, KioskPinVerifyRes
)
from core.fairness import FairnessEngine

router = APIRouter()


def db():
    """Database session dependency"""
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


def get_week_start(target_date: date) -> date:
    """
    Get Monday of the week containing target_date.

    Args:
        target_date: Date to find week start for

    Returns:
        Monday of that week
    """
    days_since_monday = target_date.weekday()
    return target_date - timedelta(days=days_since_monday)


def format_time(dt: datetime) -> str:
    """
    Format datetime as HH:MM string.

    Args:
        dt: Datetime to format

    Returns:
        Time string in HH:MM format
    """
    return dt.strftime("%H:%M")


def get_member_data(
    db_session: Session,
    user: models.User,
    target_date: date
) -> KioskMemberOut:
    """
    Get kiosk data for a single family member.

    Args:
        db_session: Database session
        user: User model instance
        target_date: Date to fetch data for

    Returns:
        KioskMemberOut with tasks, events, and capacity
    """
    # Calculate week start for capacity calculation
    week_start = get_week_start(target_date)

    # Calculate capacity percentage using fairness engine
    fairness = FairnessEngine(db_session)
    capacity_pct = fairness.calculate_workload(user.id, week_start) * 100.0

    # Get day boundaries
    day_start = datetime.combine(target_date, datetime.min.time())
    day_end = datetime.combine(target_date, datetime.max.time())

    # Fetch tasks assigned to user for this day
    tasks = db_session.query(models.Task).filter(
        and_(
            models.Task.familyId == user.familyId,
            models.Task.assignees.contains([user.id]),
            models.Task.due >= day_start,
            models.Task.due <= day_end,
            models.Task.status.in_(["open", "pendingApproval"])
        )
    ).order_by(models.Task.due.asc()).all()

    # Convert tasks to kiosk format
    kiosk_tasks = [
        KioskTaskOut(
            id=task.id,
            title=task.title,
            due_time=format_time(task.due) if task.due else None,
            points=task.points,
            status=task.status,
            photo_required=task.photoRequired
        )
        for task in tasks
    ]

    # Fetch events where user is attendee for this day
    events = db_session.query(models.Event).filter(
        and_(
            models.Event.familyId == user.familyId,
            models.Event.attendees.contains([user.id]),
            models.Event.start >= day_start,
            models.Event.start <= day_end
        )
    ).order_by(models.Event.start.asc()).all()

    # Convert events to kiosk format
    kiosk_events = [
        KioskEventOut(
            id=event.id,
            title=event.title,
            start_time=format_time(event.start),
            end_time=format_time(event.end) if event.end else None
        )
        for event in events
    ]

    return KioskMemberOut(
        user_id=user.id,
        name=user.displayName,
        avatar_url=user.avatar,
        capacity_pct=round(capacity_pct, 1),
        tasks=kiosk_tasks,
        events=kiosk_events
    )


@router.get("/today", response_model=KioskTodayOut)
def get_kiosk_today(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get today's schedule for all family members.

    Returns tasks and events for the current day, along with capacity
    percentages for each family member.

    Returns:
        KioskTodayOut with date and member data

    Raises:
        HTTPException 404: User not found
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    family_id = user.familyId
    today = date.today()

    # Get all family members (exclude helpers with expired access)
    family_members = d.query(models.User).filter(
        models.User.familyId == family_id
    ).all()

    # Filter active members (exclude expired helpers)
    active_members = []
    for member in family_members:
        if member.role == "helper":
            # Check if helper access is still valid
            if member.helperEndDate and member.helperEndDate.date() < today:
                continue
        active_members.append(member)

    # Build member data for each active family member
    members_data = [
        get_member_data(d, member, today)
        for member in active_members
    ]

    return KioskTodayOut(
        date=today.isoformat(),
        members=members_data
    )


@router.get("/week", response_model=KioskWeekOut)
def get_kiosk_week(
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get 7-day schedule overview for all family members.

    Returns tasks and events for today plus the next 6 days,
    organized by day with member schedules and capacity percentages.

    Returns:
        KioskWeekOut with 7 days of schedule data

    Raises:
        HTTPException 404: User not found
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    family_id = user.familyId
    today = date.today()

    # Calculate week range (today + 6 days)
    start_date = today
    end_date = today + timedelta(days=6)

    # Get all family members (exclude helpers with expired access)
    family_members = d.query(models.User).filter(
        models.User.familyId == family_id
    ).all()

    # Build day-by-day schedule
    days_data = []

    for day_offset in range(7):
        current_date = today + timedelta(days=day_offset)
        day_name = current_date.strftime("%A")

        # Filter active members for this specific day
        active_members = []
        for member in family_members:
            if member.role == "helper":
                # Check if helper access is valid for this specific day
                if member.helperStartDate and member.helperStartDate.date() > current_date:
                    continue
                if member.helperEndDate and member.helperEndDate.date() < current_date:
                    continue
            active_members.append(member)

        # Get member data for each active member
        members_data = [
            get_member_data(d, member, current_date)
            for member in active_members
        ]

        days_data.append(
            KioskDayOut(
                date=current_date.isoformat(),
                day_name=day_name,
                members=members_data
            )
        )

    return KioskWeekOut(
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        days=days_data
    )


@router.post("/verify-pin", response_model=KioskPinVerifyRes)
def verify_kiosk_pin(
    req: KioskPinVerifyReq,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Verify PIN to exit kiosk mode.

    Validates the provided 4-digit PIN against the current user's stored PIN.
    Required to exit fullscreen kiosk mode on tablets.

    Args:
        req: PIN verification request with 4-digit PIN

    Returns:
        KioskPinVerifyRes with validation result

    Raises:
        HTTPException 404: User not found
        HTTPException 400: PIN not set for user
    """
    user = d.query(models.User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Check if PIN is set for user
    if not user.pin:
        raise HTTPException(
            400,
            "PIN not configured for this user. Please set a PIN in settings."
        )

    # Validate PIN format (must be 4 digits)
    if not req.pin or len(req.pin) != 4 or not req.pin.isdigit():
        return KioskPinVerifyRes(
            valid=False,
            error="PIN must be exactly 4 digits"
        )

    # Compare provided PIN with stored PIN
    if req.pin == user.pin:
        return KioskPinVerifyRes(valid=True)
    else:
        return KioskPinVerifyRes(
            valid=False,
            error="Invalid PIN"
        )
