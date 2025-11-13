"""
Fairness API Router

Endpoints for workload analysis and fairness insights:
- Family workload distribution
- Fairness score calculation (Gini coefficient)
- AI-generated insights and recommendations
- User capacity tracking
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from core.db import SessionLocal
from core.deps import get_current_user, require_role
from core.models import User, Task, TaskLog
from core.fairness import FairnessEngine
from services.streak_service import StreakService
from pydantic import BaseModel
from typing import Dict, List, Optional
from datetime import datetime, timedelta, date

router = APIRouter()


def db():
    """Database session dependency"""
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


class WorkloadOut(BaseModel):
    """Workload data for single user"""
    user_id: str
    display_name: str
    role: str
    used_hours: float
    total_capacity: float
    tasks_completed: int
    percentage: float
    is_overloaded: bool
    is_underutilized: bool


class FairnessDataOut(BaseModel):
    """Fairness data for entire family"""
    fairness_score: float
    workloads: Dict[str, WorkloadOut]
    task_distribution: Dict[str, int]
    start_date: str
    end_date: str
    total_tasks: int
    average_workload: float


@router.get("/family/{family_id}")
async def get_fairness_data(
    family_id: str,
    range: str = Query("this_week", description="Time range: this_week, this_month, all_time"),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get fairness data for family.

    Shows:
    - Fairness score (0.0-1.0, higher = more fair)
    - Workload per user (hours used vs capacity)
    - Task distribution
    - Over/under capacity indicators

    Query parameters:
    - range: Time range to analyze (this_week, this_month, all_time)

    Returns:
        Fairness analysis with workloads and distribution
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    if user.familyId != family_id:
        raise HTTPException(403, "Access denied")

    # Calculate date range
    if range == "this_week":
        start_date = datetime.utcnow() - timedelta(days=7)
        days = 7
    elif range == "this_month":
        start_date = datetime.utcnow() - timedelta(days=30)
        days = 30
    else:  # all_time
        start_date = datetime(2020, 1, 1)
        days = 365

    end_date = datetime.utcnow()

    # Get all family members (exclude helpers from fairness calculations)
    users = d.query(User).filter(
        User.familyId == family_id,
        User.role != 'helper'
    ).all()

    if not users:
        raise HTTPException(404, "No users found in family")

    # Calculate workload for each user
    fairness_engine = FairnessEngine(d)
    workloads = {}
    task_distribution = {}
    total_tasks = 0

    for family_user in users:
        # Calculate workload percentage
        week_start = start_date.date() if range == "this_week" else date.today() - timedelta(days=7)
        workload_pct = fairness_engine.calculate_workload(family_user.id, week_start)

        # Get user capacity
        capacity_per_week = fairness_engine.get_user_capacity(family_user)
        total_capacity = capacity_per_week * (days / 7)

        # Get completed tasks in range
        completed_tasks = d.query(TaskLog).filter(
            TaskLog.userId == family_user.id,
            TaskLog.action == 'completed',
            TaskLog.createdAt >= start_date,
            TaskLog.createdAt <= end_date
        ).count()

        # Calculate used hours (estimate based on tasks)
        used_hours = workload_pct * (capacity_per_week / 60)  # Convert to hours

        # Build workload data
        workloads[family_user.id] = WorkloadOut(
            user_id=family_user.id,
            display_name=family_user.displayName,
            role=family_user.role,
            used_hours=round(used_hours, 1),
            total_capacity=round(total_capacity / 60, 1),  # Convert to hours
            tasks_completed=completed_tasks,
            percentage=round(workload_pct * 100, 1),
            is_overloaded=workload_pct >= 0.9,
            is_underutilized=workload_pct < 0.5
        )

        task_distribution[family_user.id] = completed_tasks
        total_tasks += completed_tasks

    # Calculate fairness score (Gini coefficient)
    fairness_score = _calculate_gini_coefficient(workloads)

    # Calculate average workload
    workload_values = [w.percentage for w in workloads.values()]
    average_workload = sum(workload_values) / len(workload_values) if workload_values else 0

    return FairnessDataOut(
        fairness_score=round(fairness_score, 2),
        workloads=workloads,
        task_distribution=task_distribution,
        start_date=start_date.isoformat(),
        end_date=end_date.isoformat(),
        total_tasks=total_tasks,
        average_workload=round(average_workload, 1)
    )


@router.get("/insights/{family_id}")
async def get_fairness_insights(
    family_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get AI-generated fairness insights.

    Analyzes:
    - Workload imbalances
    - Streak performance
    - Task completion patterns
    - Recommendations for improvement

    Returns:
        List of actionable insights
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    if user.familyId != family_id:
        raise HTTPException(403, "Access denied")

    # Get fairness data
    fairness_data = await get_fairness_data(family_id, "this_week", d, payload)

    # Generate insights
    insights = []
    workloads = fairness_data.workloads

    # Calculate average percentage
    percentages = [w.percentage for w in workloads.values()]
    avg_percentage = sum(percentages) / len(percentages) if percentages else 0

    # Analyze each user
    for user_id, workload in workloads.items():
        family_user = d.query(User).filter(User.id == user_id).first()

        # Workload insights
        if workload.percentage > avg_percentage + 15:
            insights.append({
                "type": "warning",
                "user_id": user_id,
                "message": f"{workload.display_name} is {int(workload.percentage - avg_percentage)}% above average this week",
                "recommendation": "Consider reassigning some tasks or reducing workload"
            })
        elif workload.percentage < avg_percentage - 15:
            insights.append({
                "type": "info",
                "user_id": user_id,
                "message": f"{workload.display_name} has lightest load - consider assigning more tasks",
                "recommendation": "Assign additional tasks to balance workload"
            })

        # Streak insights
        streak_service = StreakService()
        streak_stats = streak_service.get_streak_stats(user_id, d)

        if streak_stats["current"] >= 7:
            insights.append({
                "type": "success",
                "user_id": user_id,
                "message": f"{workload.display_name} has a {streak_stats['current']}-day streak! 🔥",
                "recommendation": "Encourage to maintain momentum"
            })
        elif streak_stats["is_at_risk"]:
            insights.append({
                "type": "warning",
                "user_id": user_id,
                "message": f"{workload.display_name}'s streak is at risk",
                "recommendation": "Remind to complete at least one task today"
            })

        # Task completion rate
        if workload.tasks_completed == 0:
            insights.append({
                "type": "alert",
                "user_id": user_id,
                "message": f"{workload.display_name} hasn't completed any tasks this week",
                "recommendation": "Check in and see if they need help or motivation"
            })
        elif workload.is_overloaded:
            insights.append({
                "type": "warning",
                "user_id": user_id,
                "message": f"{workload.display_name} is at {workload.percentage}% capacity",
                "recommendation": "Consider reducing workload or adjusting deadlines"
            })

    # Overall fairness insights
    if fairness_data.fairness_score >= 0.8:
        insights.append({
            "type": "success",
            "user_id": None,
            "message": f"Excellent workload balance (fairness score: {fairness_data.fairness_score})",
            "recommendation": "Continue current distribution strategy"
        })
    elif fairness_data.fairness_score < 0.5:
        insights.append({
            "type": "alert",
            "user_id": None,
            "message": f"Workload imbalance detected (fairness score: {fairness_data.fairness_score})",
            "recommendation": "Use fairness rotation strategy for recurring tasks"
        })

    return {
        "insights": insights,
        "fairness_score": fairness_data.fairness_score,
        "total_insights": len(insights)
    }


@router.get("/recommendations/{family_id}")
async def get_recommendations(
    family_id: str,
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Get actionable recommendations for improving fairness.

    Parent-only endpoint.

    Returns:
        List of specific actions parents can take
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    if user.familyId != family_id:
        raise HTTPException(403, "Access denied")

    # Get fairness data
    fairness_data = await get_fairness_data(family_id, "this_week", d, payload)

    recommendations = []

    # Identify overloaded users
    overloaded_users = [w for w in fairness_data.workloads.values() if w.is_overloaded]
    underutilized_users = [w for w in fairness_data.workloads.values() if w.is_underutilized]

    if overloaded_users and underutilized_users:
        recommendations.append({
            "priority": "high",
            "action": "rebalance_tasks",
            "title": "Rebalance Task Distribution",
            "description": f"Move tasks from {', '.join([u.display_name for u in overloaded_users])} to {', '.join([u.display_name for u in underutilized_users])}",
            "users_affected": [u.user_id for u in overloaded_users + underutilized_users]
        })

    # Check recurring task rotation strategies
    tasks_with_manual_rotation = d.query(Task).filter(
        Task.familyId == family_id,
        Task.rrule.isnot(None),
        Task.rotationStrategy == 'manual'
    ).count()

    if tasks_with_manual_rotation > 0 and fairness_data.fairness_score < 0.7:
        recommendations.append({
            "priority": "medium",
            "action": "enable_fairness_rotation",
            "title": "Enable Automatic Fairness Rotation",
            "description": f"Switch {tasks_with_manual_rotation} recurring tasks from manual to fairness rotation strategy",
            "tasks_affected": tasks_with_manual_rotation
        })

    # Check for unassigned tasks
    unassigned_tasks = d.query(Task).filter(
        Task.familyId == family_id,
        Task.status == 'open',
        Task.assignees == []
    ).count()

    if unassigned_tasks > 0:
        recommendations.append({
            "priority": "low",
            "action": "assign_tasks",
            "title": "Assign Pending Tasks",
            "description": f"You have {unassigned_tasks} unassigned tasks that need an owner",
            "tasks_count": unassigned_tasks
        })

    return {
        "recommendations": recommendations,
        "total_count": len(recommendations)
    }


def _calculate_gini_coefficient(workloads: Dict[str, WorkloadOut]) -> float:
    """
    Calculate Gini coefficient for workload distribution.

    Gini coefficient ranges from 0 (perfect equality) to 1 (maximum inequality).
    We invert it to create a fairness score where 1.0 = perfectly fair.

    Args:
        workloads: Dictionary of user workloads

    Returns:
        Fairness score (0.0-1.0, higher = more fair)
    """
    if not workloads:
        return 1.0

    # Get workload percentages
    values = [w.percentage for w in workloads.values()]

    if len(values) < 2:
        return 1.0  # Single user, perfect fairness

    # Sort values
    values.sort()
    n = len(values)

    # Calculate Gini coefficient
    # Formula: G = (2 * sum(i * x[i])) / (n * sum(x)) - (n + 1) / n
    cumsum = sum((i + 1) * val for i, val in enumerate(values))
    total = sum(values)

    if total == 0:
        return 1.0

    gini = (2 * cumsum) / (n * total) - (n + 1) / n

    # Convert to fairness score (invert Gini, higher = more fair)
    fairness_score = 1.0 - abs(gini)

    return max(0.0, min(1.0, fairness_score))
