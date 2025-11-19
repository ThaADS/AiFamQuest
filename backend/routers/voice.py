"""
Voice Commands Router

Endpoints for voice-powered task management:
- POST /voice/parse-intent: Parse voice transcript into structured intent (NLU)
- POST /voice/execute: Execute parsed voice command
- GET /voice/commands: List supported voice commands

Uses OpenRouter Claude Haiku for fast, cheap intent parsing.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.deps import get_current_user, get_db
from core import models
from services.openrouter_client import OpenRouterClient
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
import logging
import uuid

logger = logging.getLogger(__name__)

router = APIRouter()


class VoiceParseRequest(BaseModel):
    """Request to parse voice transcript"""
    transcript: str = Field(..., min_length=1, max_length=500, description="Voice transcript text")
    locale: str = Field(default="nl", description="User locale (nl|en|de|fr)")

    class Config:
        json_schema_extra = {
            "example": {
                "transcript": "Maak taak stofzuigen morgen 17:00",
                "locale": "nl"
            }
        }


class VoiceExecuteRequest(BaseModel):
    """Request to execute parsed voice command"""
    intent: str = Field(..., description="Intent name (create_task, mark_done, etc.)")
    slots: Dict[str, Any] = Field(..., description="Intent slots (parameters)")
    locale: str = Field(default="nl", description="User locale")

    class Config:
        json_schema_extra = {
            "example": {
                "intent": "create_task",
                "slots": {
                    "title": "stofzuigen",
                    "datetime": "2025-11-18T17:00:00Z"
                },
                "locale": "nl"
            }
        }


@router.post("/parse-intent")
async def parse_voice_intent(
    request: VoiceParseRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Parse voice transcript into structured intent using Claude Haiku.

    NLU (Natural Language Understanding) endpoint for voice commands.

    Examples:
        NL: "Maak taak stofzuigen morgen 17:00" → create_task
        EN: "Mark vaatwasser as done" → mark_done
        NL: "Wat moet ik vandaag doen?" → show_tasks

    Returns:
    {
        "intent": "create_task",
        "confidence": 0.95,
        "slots": {
            "title": "stofzuigen",
            "datetime": "2025-11-18T17:00:00Z"
        },
        "response": "Ik maak de taak 'stofzuigen' aan voor morgen 17:00",
        "executable": true
    }
    """
    try:
        # Initialize OpenRouter client
        openrouter = OpenRouterClient()

        # Parse intent
        intent_data = await openrouter.parse_voice_intent(
            transcript=request.transcript,
            user_locale=request.locale
        )

        # Check if intent is executable
        executable_intents = ["create_task", "mark_done", "show_tasks", "show_points", "add_event"]
        intent_data["executable"] = intent_data.get("intent") in executable_intents

        # Log voice command for analytics
        logger.info(
            f"Voice command parsed: user={current_user.get('sub')}, "
            f"intent={intent_data.get('intent')}, "
            f"confidence={intent_data.get('confidence')}"
        )

        return intent_data

    except Exception as e:
        logger.error(f"Voice intent parsing error: {e}")
        raise HTTPException(500, f"Failed to parse voice command: {str(e)}")


@router.post("/execute")
async def execute_voice_command(
    request: VoiceExecuteRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Execute parsed voice command.

    Converts intent + slots into actual API operations.

    Supported Intents:
    - create_task: Create new task
    - mark_done: Mark task as completed
    - show_tasks: Get user's tasks
    - show_points: Get user's points
    - add_event: Add calendar event

    Returns:
    {
        "success": true,
        "action": "task_created",
        "data": {...},
        "message": "Taak 'stofzuigen' aangemaakt voor morgen 17:00"
    }
    """
    user_id = current_user.get("sub")
    family_id = current_user.get("familyId")
    locale = request.locale

    try:
        # Route intent to appropriate handler
        if request.intent == "create_task":
            return await _handle_create_task(db, user_id, family_id, request.slots, locale)

        elif request.intent == "mark_done":
            return await _handle_mark_done(db, user_id, family_id, request.slots, locale)

        elif request.intent == "show_tasks":
            return await _handle_show_tasks(db, user_id, family_id, request.slots, locale)

        elif request.intent == "show_points":
            return await _handle_show_points(db, user_id, locale)

        elif request.intent == "add_event":
            return await _handle_add_event(db, user_id, family_id, request.slots, locale)

        elif request.intent == "help":
            return _handle_help(locale)

        else:
            # Unknown intent
            error_msg = "Onbekend commando" if locale == "nl" else "Unknown command"
            return {
                "success": False,
                "action": "unknown_intent",
                "message": error_msg,
                "intent": request.intent
            }

    except Exception as e:
        logger.error(f"Voice command execution error: {e}")
        error_msg = "Er ging iets mis" if locale == "nl" else "Something went wrong"
        raise HTTPException(500, f"{error_msg}: {str(e)}")


@router.get("/commands")
async def list_voice_commands(
    locale: str = "nl",
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get list of supported voice commands with examples.

    Returns:
    {
        "commands": [
            {
                "intent": "create_task",
                "description": "Create new task",
                "examples": ["Maak taak stofzuigen morgen 17:00", "Create task walk dog at 18:00"]
            }
        ],
        "locale": "nl"
    }
    """
    commands_nl = [
        {
            "intent": "create_task",
            "description": "Maak nieuwe taak aan",
            "examples": [
                "Maak taak stofzuigen morgen 17:00",
                "Voeg taak toe vaatwasser leegruimen",
                "Nieuwe taak kamer opruimen voor Noah"
            ]
        },
        {
            "intent": "mark_done",
            "description": "Markeer taak als voltooid",
            "examples": [
                "Markeer vaatwasser als klaar",
                "Taak stofzuigen is gedaan",
                "Klaar met de was"
            ]
        },
        {
            "intent": "show_tasks",
            "description": "Toon mijn taken",
            "examples": [
                "Wat moet ik vandaag doen?",
                "Laat mijn taken zien",
                "Welke taken heb ik?"
            ]
        },
        {
            "intent": "show_points",
            "description": "Toon mijn punten",
            "examples": [
                "Hoeveel punten heb ik?",
                "Laat mijn score zien",
                "Wat is mijn puntentotaal?"
            ]
        },
        {
            "intent": "add_event",
            "description": "Voeg agenda-item toe",
            "examples": [
                "Voeg event toe training morgen 18:00",
                "Nieuwe afspraak tandarts dinsdag 14:00"
            ]
        }
    ]

    commands_en = [
        {
            "intent": "create_task",
            "description": "Create new task",
            "examples": [
                "Create task vacuum tomorrow at 17:00",
                "Add task empty dishwasher",
                "New task clean room for Noah"
            ]
        },
        {
            "intent": "mark_done",
            "description": "Mark task as completed",
            "examples": [
                "Mark dishwasher as done",
                "Task vacuum is finished",
                "Done with laundry"
            ]
        },
        {
            "intent": "show_tasks",
            "description": "Show my tasks",
            "examples": [
                "What do I need to do today?",
                "Show my tasks",
                "What tasks do I have?"
            ]
        },
        {
            "intent": "show_points",
            "description": "Show my points",
            "examples": [
                "How many points do I have?",
                "Show my score",
                "What's my total points?"
            ]
        },
        {
            "intent": "add_event",
            "description": "Add calendar event",
            "examples": [
                "Add event training tomorrow at 18:00",
                "New appointment dentist Tuesday 14:00"
            ]
        }
    ]

    commands = commands_nl if locale == "nl" else commands_en

    return {
        "commands": commands,
        "locale": locale,
        "total_commands": len(commands)
    }


# Internal Intent Handlers

async def _handle_create_task(
    db: Session,
    user_id: str,
    family_id: str,
    slots: Dict[str, Any],
    locale: str
) -> Dict[str, Any]:
    """Handle create_task intent"""
    title = slots.get("title")
    datetime_str = slots.get("datetime")
    assignee = slots.get("assignee")

    if not title:
        return {
            "success": False,
            "action": "create_task",
            "message": "Taaknaam ontbreekt" if locale == "nl" else "Task title missing"
        }

    # Parse datetime
    due = None
    if datetime_str:
        try:
            # Handle various datetime formats
            if "tomorrow" in datetime_str.lower() or "morgen" in datetime_str.lower():
                due = datetime.utcnow() + timedelta(days=1)
                if ":" in datetime_str:
                    time_part = datetime_str.split()[-1]
                    hour, minute = map(int, time_part.split(":"))
                    due = due.replace(hour=hour, minute=minute, second=0, microsecond=0)
            else:
                due = datetime.fromisoformat(datetime_str.replace("Z", "+00:00"))
        except:
            logger.warning(f"Failed to parse datetime: {datetime_str}")

    # Create task
    task = models.Task(
        id=str(uuid.uuid4()),
        familyId=family_id,
        title=title,
        desc="",
        category="other",
        due=due,
        assignees=[user_id],
        points=10,
        estDuration=15,
        status="open",
        createdBy=user_id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=1
    )

    db.add(task)
    db.commit()
    db.refresh(task)

    # Build success message
    if due:
        due_str = due.strftime("%d-%m om %H:%M") if locale == "nl" else due.strftime("%m-%d at %H:%M")
        message = f"Taak '{title}' aangemaakt voor {due_str}" if locale == "nl" else f"Task '{title}' created for {due_str}"
    else:
        message = f"Taak '{title}' aangemaakt" if locale == "nl" else f"Task '{title}' created"

    return {
        "success": True,
        "action": "task_created",
        "data": {
            "task_id": task.id,
            "title": task.title,
            "due": task.due.isoformat() if task.due else None
        },
        "message": message
    }


async def _handle_mark_done(
    db: Session,
    user_id: str,
    family_id: str,
    slots: Dict[str, Any],
    locale: str
) -> Dict[str, Any]:
    """Handle mark_done intent"""
    title = slots.get("title") or slots.get("action")

    if not title:
        return {
            "success": False,
            "action": "mark_done",
            "message": "Taaknaam ontbreekt" if locale == "nl" else "Task title missing"
        }

    # Find task (fuzzy match)
    task = db.query(models.Task).filter(
        models.Task.familyId == family_id,
        models.Task.status == "open",
        models.Task.title.ilike(f"%{title}%")
    ).order_by(models.Task.createdAt.desc()).first()

    if not task:
        return {
            "success": False,
            "action": "mark_done",
            "message": f"Taak '{title}' niet gevonden" if locale == "nl" else f"Task '{title}' not found"
        }

    # Mark as done
    task.status = "done"
    task.completedBy = user_id
    task.completedAt = datetime.utcnow()
    task.updatedAt = datetime.utcnow()

    db.commit()

    # Award points
    from services.points_service import PointsService
    points_service = PointsService(db)
    points_service.award_points(user_id, task.points, f"Completed task: {task.title}", task_id=task.id)

    message = f"Taak '{task.title}' voltooid! Je verdient {task.points} punten." if locale == "nl" else f"Task '{task.title}' completed! You earned {task.points} points."

    return {
        "success": True,
        "action": "task_completed",
        "data": {
            "task_id": task.id,
            "title": task.title,
            "points_earned": task.points
        },
        "message": message
    }


async def _handle_show_tasks(
    db: Session,
    user_id: str,
    family_id: str,
    slots: Dict[str, Any],
    locale: str
) -> Dict[str, Any]:
    """Handle show_tasks intent"""
    filter_date = slots.get("filter", "all")

    # Query tasks
    query = db.query(models.Task).filter(
        models.Task.familyId == family_id,
        models.Task.status == "open"
    ).filter(
        (models.Task.assignees.contains([user_id])) | (models.Task.claimable == True)
    )

    # Apply date filter
    if filter_date == "today":
        today = datetime.utcnow().date()
        query = query.filter(
            models.Task.due >= datetime.combine(today, datetime.min.time()),
            models.Task.due < datetime.combine(today + timedelta(days=1), datetime.min.time())
        )

    tasks = query.order_by(models.Task.due.asc()).limit(10).all()

    task_list = [
        {
            "id": task.id,
            "title": task.title,
            "due": task.due.isoformat() if task.due else None,
            "points": task.points
        }
        for task in tasks
    ]

    if not tasks:
        message = "Je hebt geen taken voor vandaag" if locale == "nl" else "You have no tasks for today"
    else:
        message = f"Je hebt {len(tasks)} taken" if locale == "nl" else f"You have {len(tasks)} tasks"

    return {
        "success": True,
        "action": "tasks_listed",
        "data": {
            "tasks": task_list,
            "count": len(tasks)
        },
        "message": message
    }


async def _handle_show_points(
    db: Session,
    user_id: str,
    locale: str
) -> Dict[str, Any]:
    """Handle show_points intent"""
    from services.points_service import PointsService
    points_service = PointsService(db)
    total_points = points_service.get_user_points(user_id)

    message = f"Je hebt {total_points} punten" if locale == "nl" else f"You have {total_points} points"

    return {
        "success": True,
        "action": "points_shown",
        "data": {
            "total_points": total_points
        },
        "message": message
    }


async def _handle_add_event(
    db: Session,
    user_id: str,
    family_id: str,
    slots: Dict[str, Any],
    locale: str
) -> Dict[str, Any]:
    """Handle add_event intent"""
    title = slots.get("title")
    datetime_str = slots.get("datetime")

    if not title:
        return {
            "success": False,
            "action": "add_event",
            "message": "Event naam ontbreekt" if locale == "nl" else "Event title missing"
        }

    # Parse datetime
    start = None
    if datetime_str:
        try:
            if "tomorrow" in datetime_str.lower() or "morgen" in datetime_str.lower():
                start = datetime.utcnow() + timedelta(days=1)
                if ":" in datetime_str:
                    time_part = datetime_str.split()[-1]
                    hour, minute = map(int, time_part.split(":"))
                    start = start.replace(hour=hour, minute=minute, second=0, microsecond=0)
            else:
                start = datetime.fromisoformat(datetime_str.replace("Z", "+00:00"))
        except:
            start = datetime.utcnow()

    # Create event
    event = models.Event(
        id=str(uuid.uuid4()),
        familyId=family_id,
        title=title,
        description="",
        start=start or datetime.utcnow(),
        end=(start + timedelta(hours=1)) if start else (datetime.utcnow() + timedelta(hours=1)),
        allDay=False,
        attendees=[user_id],
        category="other",
        createdBy=user_id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )

    db.add(event)
    db.commit()
    db.refresh(event)

    start_str = event.start.strftime("%d-%m om %H:%M") if locale == "nl" else event.start.strftime("%m-%d at %H:%M")
    message = f"Event '{title}' toegevoegd voor {start_str}" if locale == "nl" else f"Event '{title}' added for {start_str}"

    return {
        "success": True,
        "action": "event_created",
        "data": {
            "event_id": event.id,
            "title": event.title,
            "start": event.start.isoformat()
        },
        "message": message
    }


def _handle_help(locale: str) -> Dict[str, Any]:
    """Handle help intent"""
    help_text_nl = """Je kunt de volgende commando's gebruiken:
- "Maak taak [naam] morgen [tijd]"
- "Markeer [taak] als klaar"
- "Wat moet ik vandaag doen?"
- "Hoeveel punten heb ik?"
- "Voeg event toe [naam] [datum/tijd]"
"""

    help_text_en = """You can use the following commands:
- "Create task [name] tomorrow [time]"
- "Mark [task] as done"
- "What do I need to do today?"
- "How many points do I have?"
- "Add event [name] [date/time]"
"""

    message = help_text_nl if locale == "nl" else help_text_en

    return {
        "success": True,
        "action": "help_shown",
        "message": message
    }
