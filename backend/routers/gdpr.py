"""
GDPR Compliance Router

Endpoints for data privacy compliance (AVG/GDPR):
- POST /gdpr/export: Export all user data (JSON)
- POST /gdpr/delete: Request account deletion (30-day grace period)
- GET /gdpr/deletion-status: Check deletion request status
- POST /gdpr/cancel-deletion: Cancel pending deletion
- GET /gdpr/data-summary: Get summary of stored data

Features:
- Complete data export in machine-readable format
- 30-day grace period for deletion
- Right to be forgotten
- Data portability
- Transparency reporting
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.deps import get_current_user, get_db
from core import models
from pydantic import BaseModel
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
import logging
import json

logger = logging.getLogger(__name__)

router = APIRouter()


class DataExportResponse(BaseModel):
    """Data export response"""
    user_data: Dict[str, Any]
    export_date: str
    format_version: str
    data_types: List[str]


class DeletionRequest(BaseModel):
    """Account deletion request"""
    confirm: bool
    reason: Optional[str] = None


@router.post("/export", response_model=DataExportResponse)
async def export_user_data(
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Export all user data in JSON format (GDPR Article 20 - Right to Data Portability).

    Returns comprehensive JSON containing:
    - Profile information
    - Tasks completed
    - Calendar events
    - Gamification data (points, badges, streaks)
    - Study items and sessions
    - Notification history
    - Audit logs

    Data is provided in machine-readable format for portability.

    Returns:
    {
        "user_data": {
            "profile": {...},
            "tasks": [...],
            "events": [...],
            "gamification": {...},
            "study": [...],
            "notifications": [...],
            "audit_logs": [...]
        },
        "export_date": "2025-11-19T20:00:00Z",
        "format_version": "1.0",
        "data_types": ["profile", "tasks", "events", "gamification", "study", "notifications", "audit"]
    }
    """
    user_id = current_user.get("sub")

    try:
        # Get user profile
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise HTTPException(404, "User not found")

        # Build comprehensive data export
        export_data = {}

        # 1. Profile Data
        export_data["profile"] = {
            "id": user.id,
            "email": user.email,
            "display_name": user.displayName,
            "role": user.role,
            "locale": user.locale,
            "theme": user.theme,
            "email_verified": user.emailVerified,
            "two_fa_enabled": user.twoFAEnabled,
            "permissions": user.permissions,
            "premium_until": user.premiumUntil.isoformat() if user.premiumUntil else None,
            "premium_plan": user.premiumPlan,
            "created_at": user.createdAt.isoformat(),
            "updated_at": user.updatedAt.isoformat()
        }

        # 2. Family Data
        family = db.query(models.Family).filter(models.Family.id == user.familyId).first()
        if family:
            export_data["family"] = {
                "id": family.id,
                "name": family.name,
                "family_unlock": family.familyUnlock,
                "created_at": family.createdAt.isoformat()
            }

        # 3. Tasks (created and completed)
        tasks_created = db.query(models.Task).filter(
            models.Task.createdBy == user_id
        ).all()

        tasks_completed = db.query(models.Task).filter(
            models.Task.completedBy == user_id
        ).all()

        export_data["tasks"] = {
            "created": [
                {
                    "id": task.id,
                    "title": task.title,
                    "desc": task.desc,
                    "category": task.category,
                    "status": task.status,
                    "points": task.points,
                    "created_at": task.createdAt.isoformat()
                }
                for task in tasks_created
            ],
            "completed": [
                {
                    "id": task.id,
                    "title": task.title,
                    "category": task.category,
                    "points": task.points,
                    "completed_at": task.completedAt.isoformat() if task.completedAt else None
                }
                for task in tasks_completed
            ]
        }

        # 4. Calendar Events
        events = db.query(models.Event).filter(
            models.Event.createdBy == user_id
        ).all()

        export_data["calendar_events"] = [
            {
                "id": event.id,
                "title": event.title,
                "description": event.description,
                "start": event.start.isoformat(),
                "end": event.end.isoformat() if event.end else None,
                "all_day": event.allDay,
                "category": event.category,
                "created_at": event.createdAt.isoformat()
            }
            for event in events
        ]

        # 5. Gamification Data
        # Points ledger
        points_ledger = db.query(models.PointsLedger).filter(
            models.PointsLedger.userId == user_id
        ).all()

        total_points = sum(entry.delta for entry in points_ledger)

        # Badges
        badges = db.query(models.Badge).filter(
            models.Badge.userId == user_id
        ).all()

        # Streaks
        streak = db.query(models.UserStreak).filter(
            models.UserStreak.userId == user_id
        ).first()

        export_data["gamification"] = {
            "total_points": total_points,
            "points_history": [
                {
                    "delta": entry.delta,
                    "reason": entry.reason,
                    "created_at": entry.createdAt.isoformat()
                }
                for entry in points_ledger
            ],
            "badges": [
                {
                    "code": badge.code,
                    "awarded_at": badge.awardedAt.isoformat()
                }
                for badge in badges
            ],
            "streak": {
                "current_streak": streak.currentStreak,
                "longest_streak": streak.longestStreak,
                "last_completion_date": streak.lastCompletionDate.isoformat() if streak and streak.lastCompletionDate else None
            } if streak else None
        }

        # 6. Study Items and Sessions
        study_items = db.query(models.StudyItem).filter(
            models.StudyItem.userId == user_id
        ).all()

        export_data["study_items"] = []
        for item in study_items:
            # Get sessions for this study item
            sessions = db.query(models.StudySession).filter(
                models.StudySession.studyItemId == item.id
            ).all()

            export_data["study_items"].append({
                "id": item.id,
                "subject": item.subject,
                "topic": item.topic,
                "test_date": item.testDate.isoformat() if item.testDate else None,
                "study_plan": item.studyPlan,
                "status": item.status,
                "created_at": item.createdAt.isoformat(),
                "sessions": [
                    {
                        "id": session.id,
                        "scheduled_date": session.scheduledDate.isoformat(),
                        "completed_at": session.completedAt.isoformat() if session.completedAt else None,
                        "score": session.score
                    }
                    for session in sessions
                ]
            })

        # 7. Notifications
        notifications = db.query(models.Notification).filter(
            models.Notification.userId == user_id
        ).order_by(models.Notification.createdAt.desc()).limit(100).all()

        export_data["notifications"] = [
            {
                "type": notif.type,
                "title": notif.title,
                "body": notif.body,
                "status": notif.status,
                "sent_at": notif.sentAt.isoformat() if notif.sentAt else None,
                "read_at": notif.readAt.isoformat() if notif.readAt else None,
                "created_at": notif.createdAt.isoformat()
            }
            for notif in notifications
        ]

        # 8. Audit Logs (user's actions)
        audit_logs = db.query(models.AuditLog).filter(
            models.AuditLog.actorUserId == user_id
        ).order_by(models.AuditLog.createdAt.desc()).limit(100).all()

        export_data["audit_logs"] = [
            {
                "action": log.action,
                "meta": log.meta,
                "created_at": log.createdAt.isoformat()
            }
            for log in audit_logs
        ]

        # Log export request
        logger.info(f"Data export completed for user {user_id}")

        # Audit log
        from routers.util import audit
        audit(db, actorUserId=user_id, familyId=user.familyId,
              action="gdpr.export", meta={"export_date": datetime.utcnow().isoformat()})

        return DataExportResponse(
            user_data=export_data,
            export_date=datetime.utcnow().isoformat(),
            format_version="1.0",
            data_types=list(export_data.keys())
        )

    except Exception as e:
        logger.error(f"Data export failed for user {user_id}: {e}")
        raise HTTPException(500, f"Failed to export data: {str(e)}")


@router.post("/delete")
async def request_account_deletion(
    request: DeletionRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Request account deletion with 30-day grace period (GDPR Article 17 - Right to be Forgotten).

    Account will be marked for deletion but remains active for 30 days.
    During this period, user can cancel the request.

    After 30 days, account is permanently deleted along with all associated data.

    Note: If user is the only parent in a family, deletion will fail.
          Family ownership must be transferred first.

    Returns:
    {
        "success": true,
        "deletion_scheduled_for": "2025-12-19T20:00:00Z",
        "days_until_deletion": 30,
        "cancel_before": "2025-12-19T20:00:00Z",
        "message": "Account will be deleted on 2025-12-19. Cancel anytime before then."
    }
    """
    if not request.confirm:
        raise HTTPException(400, "Confirmation required for account deletion")

    user_id = current_user.get("sub")

    try:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise HTTPException(404, "User not found")

        # Check if user is the only parent in family
        if user.role == "parent":
            family_parents = db.query(models.User).filter(
                models.User.familyId == user.familyId,
                models.User.role == "parent",
                models.User.id != user_id
            ).count()

            if family_parents == 0:
                raise HTTPException(
                    400,
                    "Cannot delete account: You are the only parent in the family. "
                    "Transfer family ownership or delete the family first."
                )

        # Set deletion date (30 days from now)
        deletion_date = datetime.utcnow() + timedelta(days=30)

        # Store deletion request in permissions (using existing field)
        if not user.permissions:
            user.permissions = {}

        user.permissions["deletion_requested"] = True
        user.permissions["deletion_date"] = deletion_date.isoformat()
        user.permissions["deletion_reason"] = request.reason
        user.permissions["deletion_requested_at"] = datetime.utcnow().isoformat()

        user.updatedAt = datetime.utcnow()

        db.commit()

        # Log deletion request
        logger.warning(f"Account deletion requested for user {user_id}, scheduled for {deletion_date}")

        # Audit log
        from routers.util import audit
        audit(db, actorUserId=user_id, familyId=user.familyId,
              action="gdpr.deletion_requested", meta={
                  "deletion_date": deletion_date.isoformat(),
                  "reason": request.reason
              })

        return {
            "success": True,
            "deletion_scheduled_for": deletion_date.isoformat(),
            "days_until_deletion": 30,
            "cancel_before": deletion_date.isoformat(),
            "message": f"Account deletion scheduled for {deletion_date.strftime('%Y-%m-%d')}. "
                       f"You can cancel this request anytime before then."
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Deletion request failed for user {user_id}: {e}")
        raise HTTPException(500, f"Failed to process deletion request: {str(e)}")


@router.get("/deletion-status")
async def get_deletion_status(
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Check account deletion status.

    Returns:
    {
        "deletion_requested": false,
        "deletion_date": null,
        "days_remaining": null,
        "can_cancel": false
    }

    OR (if deletion requested):
    {
        "deletion_requested": true,
        "deletion_date": "2025-12-19T20:00:00Z",
        "days_remaining": 27,
        "can_cancel": true,
        "reason": "User provided reason"
    }
    """
    user_id = current_user.get("sub")

    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(404, "User not found")

    deletion_requested = user.permissions.get("deletion_requested", False) if user.permissions else False

    if not deletion_requested:
        return {
            "deletion_requested": False,
            "deletion_date": None,
            "days_remaining": None,
            "can_cancel": False
        }

    deletion_date_str = user.permissions.get("deletion_date")
    if not deletion_date_str:
        return {
            "deletion_requested": False,
            "deletion_date": None,
            "days_remaining": None,
            "can_cancel": False
        }

    deletion_date = datetime.fromisoformat(deletion_date_str.replace("Z", "+00:00"))
    days_remaining = (deletion_date - datetime.utcnow()).days

    return {
        "deletion_requested": True,
        "deletion_date": deletion_date.isoformat(),
        "days_remaining": max(0, days_remaining),
        "can_cancel": days_remaining > 0,
        "reason": user.permissions.get("deletion_reason"),
        "requested_at": user.permissions.get("deletion_requested_at")
    }


@router.post("/cancel-deletion")
async def cancel_account_deletion(
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Cancel pending account deletion request.

    Can only be done before the 30-day grace period expires.

    Returns:
        Success confirmation
    """
    user_id = current_user.get("sub")

    try:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise HTTPException(404, "User not found")

        if not user.permissions or not user.permissions.get("deletion_requested"):
            raise HTTPException(400, "No pending deletion request")

        # Check if grace period has expired
        deletion_date_str = user.permissions.get("deletion_date")
        if deletion_date_str:
            deletion_date = datetime.fromisoformat(deletion_date_str.replace("Z", "+00:00"))
            if datetime.utcnow() >= deletion_date:
                raise HTTPException(400, "Deletion grace period has expired. Account is being deleted.")

        # Cancel deletion
        user.permissions["deletion_requested"] = False
        user.permissions["deletion_cancelled_at"] = datetime.utcnow().isoformat()
        user.updatedAt = datetime.utcnow()

        db.commit()

        # Log cancellation
        logger.info(f"Account deletion cancelled for user {user_id}")

        # Audit log
        from routers.util import audit
        audit(db, actorUserId=user_id, familyId=user.familyId,
              action="gdpr.deletion_cancelled", meta={})

        return {
            "success": True,
            "message": "Account deletion request cancelled. Your account remains active."
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Deletion cancellation failed for user {user_id}: {e}")
        raise HTTPException(500, f"Failed to cancel deletion: {str(e)}")


@router.get("/data-summary")
async def get_data_summary(
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get summary of stored user data (transparency reporting).

    Shows what data FamQuest stores about the user.

    Returns:
    {
        "profile": {"fields": 10, "size_kb": 2},
        "tasks": {"count": 45, "size_kb": 15},
        "events": {"count": 12, "size_kb": 5},
        "gamification": {"badges": 3, "points_entries": 45, "size_kb": 8},
        "study_items": {"count": 2, "sessions": 8, "size_kb": 12},
        "notifications": {"count": 23, "size_kb": 7},
        "audit_logs": {"count": 67, "size_kb": 10},
        "total_size_kb": 59
    }
    """
    user_id = current_user.get("sub")

    try:
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise HTTPException(404, "User not found")

        # Count data entries
        tasks_count = db.query(models.Task).filter(
            (models.Task.createdBy == user_id) | (models.Task.completedBy == user_id)
        ).count()

        events_count = db.query(models.Event).filter(
            models.Event.createdBy == user_id
        ).count()

        points_count = db.query(models.PointsLedger).filter(
            models.PointsLedger.userId == user_id
        ).count()

        badges_count = db.query(models.Badge).filter(
            models.Badge.userId == user_id
        ).count()

        study_items_count = db.query(models.StudyItem).filter(
            models.StudyItem.userId == user_id
        ).count()

        study_sessions_count = db.query(models.StudySession).join(
            models.StudyItem
        ).filter(models.StudyItem.userId == user_id).count()

        notifications_count = db.query(models.Notification).filter(
            models.Notification.userId == user_id
        ).count()

        audit_logs_count = db.query(models.AuditLog).filter(
            models.AuditLog.actorUserId == user_id
        ).count()

        # Rough size estimates (very approximate)
        summary = {
            "profile": {
                "fields": 10,
                "size_kb": 2
            },
            "tasks": {
                "count": tasks_count,
                "size_kb": tasks_count * 0.3  # ~300 bytes per task
            },
            "events": {
                "count": events_count,
                "size_kb": events_count * 0.4
            },
            "gamification": {
                "badges": badges_count,
                "points_entries": points_count,
                "size_kb": (badges_count + points_count) * 0.2
            },
            "study_items": {
                "count": study_items_count,
                "sessions": study_sessions_count,
                "size_kb": (study_items_count * 5) + (study_sessions_count * 0.3)
            },
            "notifications": {
                "count": notifications_count,
                "size_kb": notifications_count * 0.3
            },
            "audit_logs": {
                "count": audit_logs_count,
                "size_kb": audit_logs_count * 0.15
            }
        }

        # Calculate total
        total_kb = sum(
            item.get("size_kb", 0) if isinstance(item, dict) else 0
            for item in summary.values()
        )
        summary["total_size_kb"] = round(total_kb, 2)
        summary["total_size_mb"] = round(total_kb / 1024, 2)

        return summary

    except Exception as e:
        logger.error(f"Data summary failed for user {user_id}: {e}")
        raise HTTPException(500, f"Failed to generate data summary: {str(e)}")
