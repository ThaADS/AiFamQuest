"""
Gamification API Router
Endpoints for points, badges, streaks, leaderboards, and rewards.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel
from datetime import datetime

from core.db import SessionLocal
from core.deps import get_current_user, require_role
from services.gamification_service import GamificationService


router = APIRouter()


def db():
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


# Pydantic models for request/response
class RewardRedemptionRequest(BaseModel):
    reward_id: str
    require_approval: bool = False


# Initialize gamification service
gamification_service = GamificationService()


@router.get("/profile/{user_id}")
async def get_gamification_profile(
    user_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get complete gamification profile for user.

    Returns:
        - Points summary (balance, earned, spent, history)
        - Streak statistics (current, longest, at risk)
        - Badges (earned and progress toward unearned)
        - Leaderboard position (week and all-time)
        - Affordable rewards from shop
    """
    # Verify user can access this profile
    if payload["sub"] != user_id and payload.get("role") not in ["parent"]:
        raise HTTPException(403, "Cannot access other user's profile")

    profile = gamification_service.get_gamification_profile(user_id, d)

    if "error" in profile:
        raise HTTPException(404, profile["error"])

    return profile


@router.get("/leaderboard")
async def get_family_leaderboard(
    family_id: str = Query(...),
    period: str = Query("week", regex="^(week|month|alltime)$"),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get family leaderboard for specified period.

    Privacy-aware: Only shows users who have opted in to leaderboard.

    Args:
        family_id: Family ID
        period: Time period (week, month, alltime)

    Returns:
        List of top users by points with rankings
    """
    leaderboard = gamification_service.points_service.get_leaderboard(
        family_id=family_id,
        db=d,
        period=period,
        limit=10
    )

    return {
        "period": period,
        "family_id": family_id,
        "leaderboard": leaderboard
    }


@router.post("/redeem-reward")
async def redeem_reward(
    body: RewardRedemptionRequest,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Spend points to redeem a reward from the shop.

    Args:
        reward_id: Reward being redeemed
        require_approval: Whether parent approval is needed

    Returns:
        Redemption status with new balance
    """
    user_id = payload["sub"]

    try:
        # Get reward to check cost
        from core.models import Reward
        reward = d.query(Reward).filter_by(id=body.reward_id).first()

        if not reward:
            raise HTTPException(404, "Reward not found")

        # Spend points
        result = gamification_service.points_service.spend_points(
            user_id=user_id,
            reward_id=body.reward_id,
            cost=reward.cost,
            db=d,
            require_approval=body.require_approval
        )

        return result

    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception as e:
        raise HTTPException(500, f"Redemption failed: {str(e)}")


@router.get("/badges/available")
async def get_available_badges(
    user_id: str = Query(...),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get all badges with progress towards unearn ones.

    Returns:
        - earned_badges: List of badges user has earned
        - progress: Progress toward unearn badges (current/target)
    """
    # Verify access
    if payload["sub"] != user_id and payload.get("role") not in ["parent"]:
        raise HTTPException(403, "Cannot access other user's badges")

    earned_badges = gamification_service.badge_service.get_user_badges(user_id, d)
    badge_progress = gamification_service.badge_service.get_badge_progress(user_id, d)

    return {
        "user_id": user_id,
        "earned_badges": earned_badges,
        "total_earned": len(earned_badges),
        "progress": badge_progress,
        "total_available": len(gamification_service.badge_service.badges)
    }


@router.get("/streak/{user_id}")
async def get_streak_stats(
    user_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get streak statistics for user.

    Returns:
        - current: Current streak length
        - longest: Longest streak ever achieved
        - days_since_last: Days since last completion
        - is_at_risk: Whether streak is at risk (no completion today)
        - last_completion_date: Date of last completion
    """
    # Verify access
    if payload["sub"] != user_id and payload.get("role") not in ["parent"]:
        raise HTTPException(403, "Cannot access other user's streak")

    stats = gamification_service.streak_service.get_streak_stats(user_id, d)

    return {
        "user_id": user_id,
        **stats
    }


@router.get("/points/history/{user_id}")
async def get_points_history(
    user_id: str,
    limit: int = Query(50, ge=1, le=200),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get points transaction history for user.

    Args:
        user_id: User ID
        limit: Maximum number of entries (1-200)

    Returns:
        List of points transactions with running balance
    """
    # Verify access
    if payload["sub"] != user_id and payload.get("role") not in ["parent"]:
        raise HTTPException(403, "Cannot access other user's history")

    history = gamification_service.points_service.get_points_history(
        user_id=user_id,
        db=d,
        limit=limit
    )

    return {
        "user_id": user_id,
        "history": history,
        "count": len(history)
    }


@router.get("/rewards/affordable")
async def get_affordable_rewards(
    family_id: str = Query(...),
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Get rewards user can afford with current points.

    Args:
        family_id: Family ID

    Returns:
        List of rewards within user's point budget
    """
    user_id = payload["sub"]

    rewards = gamification_service.points_service.get_affordable_rewards(
        user_id=user_id,
        family_id=family_id,
        db=d
    )

    current_points = gamification_service.points_service.get_user_points(user_id, d)

    return {
        "user_id": user_id,
        "current_points": current_points,
        "affordable_rewards": rewards,
        "count": len(rewards)
    }


@router.get("/task/{task_id}/preview")
async def preview_task_rewards(
    task_id: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Preview points and potential badges for completing a task.

    Useful for showing users what they'll earn before completion.

    Args:
        task_id: Task ID

    Returns:
        - estimated_points: Points with potential multipliers
        - potential_badges: Badges close to unlocking
        - current_streak: User's current streak
    """
    from core.models import Task, User

    user_id = payload["sub"]

    task = d.query(Task).filter_by(id=task_id).first()
    if not task:
        raise HTTPException(404, "Task not found")

    user = d.query(User).filter_by(id=user_id).first()
    if not user:
        raise HTTPException(404, "User not found")

    preview = gamification_service.preview_task_rewards(
        task=task,
        user=user,
        db=d
    )

    return {
        "task_id": task_id,
        "user_id": user_id,
        **preview
    }


# Legacy endpoints (kept for backward compatibility)
@router.post("/award_points", dependencies=[Depends(require_role(["parent"]))])
def award_points_legacy(
    userId: str,
    delta: int,
    reason: str = "",
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Legacy endpoint: Award points manually (parent only).

    Use new gamification service for automatic point awards.
    """
    gamification_service.points_service.award_points(
        user_id=userId,
        task_id=None,
        points=delta,
        reason=reason,
        db=d
    )

    d.commit()

    return {
        "ok": True,
        "user_id": userId,
        "delta": delta,
        "new_balance": gamification_service.points_service.get_user_points(userId, d)
    }


@router.post("/award_badge", dependencies=[Depends(require_role(["parent"]))])
def award_badge_legacy(
    userId: str,
    code: str,
    d: Session = Depends(db),
    payload=Depends(get_current_user)
):
    """
    Legacy endpoint: Award badge manually (parent only).

    Use new gamification service for automatic badge awards.
    """
    from core.models import Badge
    from uuid import uuid4

    # Check if badge already exists
    existing = d.query(Badge).filter_by(userId=userId, code=code).first()
    if existing:
        raise HTTPException(400, "Badge already earned")

    # Award badge
    badge = Badge(
        id=str(uuid4()),
        userId=userId,
        code=code,
        awardedAt=datetime.utcnow()
    )
    d.add(badge)
    d.commit()

    return {
        "ok": True,
        "user_id": userId,
        "badge_code": code
    }
