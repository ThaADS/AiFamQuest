"""
AI Router - Endpoints for AI services
Implements planner, vision tips, voice NLU, and AI-powered weekly planning
"""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session
from core.deps import get_current_user, get_db
from core.schemas import PlanReq
from core.ai_client import planner_plan, vision_tips, voice_intent
from core.monitoring import get_cost_metrics, get_fallback_stats
from core.cache import get_cache_stats
from services.ai_planner import AIPlanner
from services.premium_service import PremiumService
from core import models
from datetime import datetime, timedelta
from pydantic import BaseModel
import os
import shutil
import uuid
from typing import Dict, Any, Optional

router = APIRouter()


class WeekPlanRequest(BaseModel):
    """Request for weekly AI plan generation"""
    start_date: str  # ISO format: "2025-11-17"
    preferences: Optional[Dict[str, Any]] = None


class ApplyPlanRequest(BaseModel):
    """Request to apply generated plan"""
    week_plan: list
    fairness: Optional[Dict[str, Any]] = None

@router.post("/plan")
async def ai_plan(
    req: PlanReq,
    payload=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    AI Planner endpoint
    Generates weekly task distribution with fairness

    Request body:
    {
      "weekContext": {
        "familyMembers": [...],
        "tasks": [...],
        "calendar": [...],
        "constraints": {...}
      }
    }

    Returns: Weekly plan with fairness distribution
    """
    family_id = payload.get("familyId", "unknown")

    try:
        plan = await planner_plan(
            week_context=req.weekContext,
            db_session=db,
            family_id=family_id
        )
        return plan
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI planner error: {str(e)}")

@router.post("/vision-tips")
async def ai_vision_tips(
    file: UploadFile = File(...),
    description: str = Form(""),
    payload=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Vision tips endpoint
    Analyzes photo and provides cleaning advice

    Multipart form:
    - file: Image file
    - description: Optional text description

    Returns: Cleaning tips with steps, warnings, estimated time
    """
    family_id = payload.get("familyId", "unknown")

    # Save uploaded file
    media_dir = os.getenv("MEDIA_DIR", "./uploads")
    os.makedirs(media_dir, exist_ok=True)

    fname = f"{uuid.uuid4()}_{file.filename}"
    path = os.path.join(media_dir, fname)

    try:
        with open(path, "wb") as f:
            shutil.copyfileobj(file.file, f)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"File upload error: {str(e)}")

    # Generate public URL
    public_base = os.getenv("PUBLIC_BASE", "http://localhost:8000")
    public_url = f"{public_base}/uploads/{fname}"

    # Get AI vision tips
    try:
        tips = await vision_tips(
            photo_url=public_url,
            user_description=description,
            db_session=db,
            family_id=family_id
        )

        return {
            "url": public_url,
            "tips": tips
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vision tips error: {str(e)}")

@router.post("/voice-intent")
async def ai_voice_intent(
    transcript: str,
    payload=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    Voice NLU endpoint (Phase 2 - stub)
    Parses voice transcript into structured intent

    Request body: {"transcript": "Maak taak stofzuigen morgen 17:00"}

    Returns: Intent and slots
    """
    family_id = payload.get("familyId", "unknown")

    try:
        intent = await voice_intent(
            transcript=transcript,
            db_session=db,
            family_id=family_id
        )
        return intent
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Voice intent error: {str(e)}")

@router.get("/costs")
async def ai_costs(
    days: int = 7,
    payload=Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> Dict[str, Any]:
    """
    AI cost monitoring dashboard
    Shows AI usage metrics and costs

    Query params:
    - days: Number of days to analyze (default 7)

    Returns: Cost metrics with daily breakdown
    """
    # Only allow parent role to view costs
    if payload.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Only parents can view cost metrics")

    try:
        cost_metrics = await get_cost_metrics(db, days)
        fallback_stats = await get_fallback_stats(db, days)
        cache_stats = await get_cache_stats()

        return {
            **cost_metrics,
            "fallback_stats": fallback_stats,
            "cache_stats": cache_stats
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Cost metrics error: {str(e)}")

@router.get("/health")
async def ai_health() -> Dict[str, Any]:
    """
    AI service health check
    Verifies configuration and connectivity

    Returns: Health status
    """
    openrouter_configured = bool(os.getenv("OPENROUTER_API_KEY"))
    redis_configured = bool(os.getenv("REDIS_URL"))

    return {
        "status": "healthy",
        "services": {
            "openrouter": "configured" if openrouter_configured else "not_configured",
            "redis": "configured" if redis_configured else "not_configured"
        },
        "fallback_tiers": {
            "tier_1": "OpenRouter Claude Sonnet (primary)",
            "tier_2": "OpenRouter Claude Haiku (fallback)",
            "tier_3": "Rule-based planner (deterministic)",
            "tier_4": "Cached responses (Redis)"
        }
    }


# New AI Planner Endpoints

@router.post("/plan-week")
async def plan_week(
    request: WeekPlanRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Generate AI-powered weekly task plan.

    Only parents can generate plans.

    Request body:
    {
        "start_date": "2025-11-17",  # Monday (ISO format)
        "preferences": {}  # Optional preferences
    }

    Returns:
    {
        "week_plan": [
            {
                "date": "2025-11-17",
                "tasks": [
                    {
                        "task_id": "uuid",
                        "title": "Vaatwasser",
                        "assignee_id": "uuid-noah",
                        "assignee_name": "Noah",
                        "due_time": "19:00",
                        "points": 20,
                        "est_duration": 15
                    }
                ]
            }
        ],
        "fairness": {
            "distribution": {
                "Noah": 0.28,
                "Luna": 0.24
            },
            "notes": "Balanced on age/agenda"
        },
        "conflicts": [],
        "total_tasks": 28,
        "cost": 0.003
    }
    """
    # Check authorization
    if current_user.get("role") not in ["parent"]:
        raise HTTPException(403, "Only parents can generate plans")

    family_id = current_user.get("familyId")
    if not family_id:
        raise HTTPException(400, "User family not found")

    # Get user object from database for premium check
    user = db.query(models.User).filter(models.User.id == current_user.get("id")).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Check premium limits
    premium_service = PremiumService(db)
    ai_limits = premium_service.can_use_ai_planning(user)

    if not ai_limits["allowed"]:
        raise HTTPException(
            403,
            f"Daily AI planning limit reached ({ai_limits['limit']} per day). "
            f"Resets at {ai_limits['resets_at']}. "
            "Upgrade to Premium for unlimited AI planning."
        )

    try:
        # Parse start date
        start_date = datetime.fromisoformat(request.start_date)

        # Validate start date is Monday
        if start_date.weekday() != 0:
            # Adjust to previous Monday
            start_date = start_date - timedelta(days=start_date.weekday())

        # Generate plan
        planner = AIPlanner(db, family_id)
        plan = await planner.generate_week_plan(start_date, request.preferences)

        # Log AI usage for rate limiting
        premium_service.log_ai_usage(
            user,
            action='plan_week',
            metadata={
                'start_date': request.start_date,
                'total_tasks': plan.get('total_tasks', 0),
                'cost': plan.get('cost', 0)
            }
        )

        return plan

    except Exception as e:
        raise HTTPException(500, f"AI planner error: {str(e)}")


@router.post("/apply-plan")
async def apply_plan(
    request: ApplyPlanRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Apply AI-generated plan (create task assignments).

    Parent reviews plan, optionally edits, then applies.

    Request body:
    {
        "week_plan": [
            {
                "date": "2025-11-17",
                "tasks": [
                    {
                        "task_id": "uuid",
                        "assignee_id": "uuid-noah",
                        "due_time": "19:00"
                    }
                ]
            }
        ],
        "fairness": {}  # Optional fairness metadata
    }

    Returns:
    {
        "success": true,
        "tasks_created": 15,
        "message": "Created 15 task assignments"
    }
    """
    # Check authorization
    if current_user.get("role") not in ["parent"]:
        raise HTTPException(403, "Only parents can apply plans")

    family_id = current_user.get("familyId")
    user_id = current_user.get("sub")

    if not family_id:
        raise HTTPException(400, "User family not found")

    try:
        created_tasks = []
        updated_tasks = []

        # Process each day in plan
        for day in request.week_plan:
            date_str = day.get("date")

            for task_spec in day.get("tasks", []):
                task_id = task_spec.get("task_id")
                assignee_id = task_spec.get("assignee_id")
                due_time = task_spec.get("due_time", "19:00")

                # Look up task template
                task_template = db.query(models.Task).filter(
                    models.Task.id == task_id
                ).first()

                if not task_template:
                    continue

                # Construct full due datetime
                due_datetime = datetime.fromisoformat(f"{date_str}T{due_time}:00")

                # Check if this is a recurring task or one-time task
                if task_template.rrule:
                    # Recurring task: Create new instance for this occurrence
                    new_task = models.Task(
                        familyId=family_id,
                        title=task_template.title,
                        desc=task_template.desc,
                        category=task_template.category,
                        due=due_datetime,
                        assignees=[assignee_id],
                        points=task_template.points,
                        estDuration=task_template.estDuration,
                        photoRequired=task_template.photoRequired,
                        parentApproval=task_template.parentApproval,
                        priority=task_template.priority,
                        status="open",
                        createdBy=user_id,
                        createdAt=datetime.utcnow(),
                        updatedAt=datetime.utcnow(),
                        version=1
                    )
                    db.add(new_task)
                    created_tasks.append(new_task)
                else:
                    # One-time task: Update existing task
                    task_template.assignees = [assignee_id]
                    task_template.due = due_datetime
                    task_template.updatedAt = datetime.utcnow()
                    task_template.version += 1
                    updated_tasks.append(task_template)

        # Commit all changes
        db.commit()

        return {
            "success": True,
            "tasks_created": len(created_tasks),
            "tasks_updated": len(updated_tasks),
            "message": f"Created {len(created_tasks)} task assignments, updated {len(updated_tasks)} existing tasks"
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(500, f"Failed to apply plan: {str(e)}")
