"""
Delta Sync API Router

Implements bidirectional delta synchronization with conflict resolution for offline-first architecture.

Features:
- Optimistic locking with version field
- Conflict resolution strategies (done wins, delete wins, LWW)
- Batch transaction support
- Comprehensive error handling
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from datetime import datetime
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from core.db import SessionLocal
from core.deps import get_current_user
from core import models
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["sync"])


def get_db():
    """Database dependency"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Pydantic Models

class SyncEntity(BaseModel):
    """Single entity change for sync"""
    entity_type: str = Field(..., description="Entity type: task, event, user, points_ledger")
    entity_id: str = Field(..., description="Unique entity identifier")
    action: str = Field(..., description="Action: create, update, delete")
    data: Dict[str, Any] = Field(default_factory=dict, description="Entity data")
    version: int = Field(default=0, description="Entity version for optimistic locking")
    client_timestamp: datetime = Field(..., description="Client-side timestamp")


class SyncRequest(BaseModel):
    """Client sync request"""
    last_sync_at: datetime = Field(..., description="Last successful sync timestamp")
    changes: List[SyncEntity] = Field(default_factory=list, description="Client changes since last sync")
    device_id: str = Field(..., description="Unique device identifier")


class ConflictInfo(BaseModel):
    """Conflict information for manual resolution"""
    entity_type: str
    entity_id: str
    conflict_reason: str
    resolution: str  # server_wins, client_wins, manual
    client_version: int
    server_version: int
    client_data: Optional[Dict[str, Any]] = None
    server_data: Optional[Dict[str, Any]] = None


class SyncResponse(BaseModel):
    """Server sync response"""
    server_changes: List[SyncEntity] = Field(default_factory=list)
    conflicts: List[ConflictInfo] = Field(default_factory=list)
    last_sync_at: datetime
    success: bool
    applied_count: int = 0
    error_count: int = 0


# Entity-specific handlers

def fetch_server_changes(
    db: Session,
    family_id: str,
    since: datetime
) -> List[SyncEntity]:
    """
    Fetch all server changes since timestamp for this family.

    Returns changes for:
    - Tasks (created, updated, deleted)
    - Events (created, updated, deleted)
    - PointsLedger entries (new awards)
    - UserStreak updates
    - Badge unlocks
    """
    changes = []

    # Tasks
    tasks = db.query(models.Task).filter(
        models.Task.familyId == family_id,
        models.Task.updatedAt > since
    ).all()

    for task in tasks:
        action = "create" if task.createdAt > since else "update"
        changes.append(SyncEntity(
            entity_type="task",
            entity_id=str(task.id),
            action=action,
            data={
                "id": str(task.id),
                "familyId": str(task.familyId),
                "title": task.title,
                "desc": task.desc,
                "category": task.category,
                "due": task.due.isoformat() if task.due else None,
                "frequency": task.frequency,
                "rrule": task.rrule,
                "rotationStrategy": task.rotationStrategy,
                "rotationState": task.rotationState,
                "assignees": task.assignees,
                "claimable": task.claimable,
                "claimedBy": task.claimedBy,
                "claimedAt": task.claimedAt.isoformat() if task.claimedAt else None,
                "status": task.status,
                "points": task.points,
                "photoRequired": task.photoRequired,
                "parentApproval": task.parentApproval,
                "proofPhotos": task.proofPhotos,
                "priority": task.priority,
                "estDuration": task.estDuration,
                "createdBy": str(task.createdBy),
                "completedBy": task.completedBy,
                "completedAt": task.completedAt.isoformat() if task.completedAt else None,
                "version": task.version,
                "createdAt": task.createdAt.isoformat(),
                "updatedAt": task.updatedAt.isoformat()
            },
            version=task.version,
            client_timestamp=task.updatedAt
        ))

    # Events
    events = db.query(models.Event).filter(
        models.Event.familyId == family_id,
        models.Event.updatedAt > since
    ).all()

    for event in events:
        action = "create" if event.createdAt > since else "update"
        changes.append(SyncEntity(
            entity_type="event",
            entity_id=str(event.id),
            action=action,
            data={
                "id": str(event.id),
                "familyId": str(event.familyId),
                "title": event.title,
                "description": event.description,
                "start": event.start.isoformat(),
                "end": event.end.isoformat() if event.end else None,
                "allDay": event.allDay,
                "attendees": event.attendees,
                "color": event.color,
                "rrule": event.rrule,
                "category": event.category,
                "createdBy": str(event.createdBy),
                "createdAt": event.createdAt.isoformat(),
                "updatedAt": event.updatedAt.isoformat()
            },
            version=0,  # Events don't have version field yet
            client_timestamp=event.updatedAt
        ))

    # PointsLedger entries (new awards since last sync)
    points = db.query(models.PointsLedger).join(
        models.User, models.PointsLedger.userId == models.User.id
    ).filter(
        models.User.familyId == family_id,
        models.PointsLedger.createdAt > since
    ).all()

    for entry in points:
        changes.append(SyncEntity(
            entity_type="points_ledger",
            entity_id=str(entry.id),
            action="create",
            data={
                "id": str(entry.id),
                "userId": str(entry.userId),
                "delta": entry.delta,
                "reason": entry.reason,
                "taskId": entry.taskId,
                "rewardId": entry.rewardId,
                "createdAt": entry.createdAt.isoformat()
            },
            version=0,
            client_timestamp=entry.createdAt
        ))

    # UserStreak updates
    streaks = db.query(models.UserStreak).join(
        models.User, models.UserStreak.userId == models.User.id
    ).filter(
        models.User.familyId == family_id,
        models.UserStreak.updatedAt > since
    ).all()

    for streak in streaks:
        changes.append(SyncEntity(
            entity_type="user_streak",
            entity_id=str(streak.id),
            action="update",
            data={
                "id": str(streak.id),
                "userId": str(streak.userId),
                "currentStreak": streak.currentStreak,
                "longestStreak": streak.longestStreak,
                "lastCompletionDate": streak.lastCompletionDate.isoformat() if streak.lastCompletionDate else None,
                "updatedAt": streak.updatedAt.isoformat()
            },
            version=0,
            client_timestamp=streak.updatedAt
        ))

    # Badge unlocks
    badges = db.query(models.Badge).join(
        models.User, models.Badge.userId == models.User.id
    ).filter(
        models.User.familyId == family_id,
        models.Badge.awardedAt > since
    ).all()

    for badge in badges:
        changes.append(SyncEntity(
            entity_type="badge",
            entity_id=str(badge.id),
            action="create",
            data={
                "id": str(badge.id),
                "userId": str(badge.userId),
                "code": badge.code,
                "awardedAt": badge.awardedAt.isoformat()
            },
            version=0,
            client_timestamp=badge.awardedAt
        ))

    return changes


def apply_task_change(
    db: Session,
    change: SyncEntity,
    current_user: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Apply task change with conflict detection.

    Conflict Resolution Strategies:
    1. Task status: done > open (completed takes precedence)
    2. Delete always wins
    3. Version mismatch: Check timestamps for Last-Writer-Wins
    """
    task = db.query(models.Task).filter(models.Task.id == change.entity_id).first()

    # Handle DELETE action
    if change.action == "delete":
        if task:
            db.delete(task)
            logger.info(f"Deleted task {change.entity_id} from client {current_user.get('sub')}")
        return {"success": True, "action": "delete"}

    # Handle CREATE action
    if change.action == "create":
        if task:
            # Client tried to create task that already exists on server
            return {
                "conflict": True,
                "resolution": "server_wins",
                "server_version": task.version,
                "server_data": _task_to_dict(task),
                "reason": "Task already exists on server"
            }

        # Create new task
        try:
            new_task = models.Task(
                id=change.entity_id,
                familyId=change.data.get("familyId"),
                title=change.data.get("title"),
                desc=change.data.get("desc", ""),
                category=change.data.get("category", "other"),
                due=datetime.fromisoformat(change.data["due"]) if change.data.get("due") else None,
                frequency=change.data.get("frequency", "none"),
                rrule=change.data.get("rrule"),
                rotationStrategy=change.data.get("rotationStrategy", "manual"),
                rotationState=change.data.get("rotationState", {}),
                assignees=change.data.get("assignees", []),
                claimable=change.data.get("claimable", False),
                status=change.data.get("status", "open"),
                points=change.data.get("points", 10),
                photoRequired=change.data.get("photoRequired", False),
                parentApproval=change.data.get("parentApproval", False),
                priority=change.data.get("priority", "med"),
                estDuration=change.data.get("estDuration", 15),
                createdBy=current_user.get("sub"),
                version=1,
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow()
            )
            db.add(new_task)
            logger.info(f"Created task {change.entity_id} from client {current_user.get('sub')}")
            return {"success": True, "action": "create"}
        except IntegrityError as e:
            logger.error(f"Failed to create task {change.entity_id}: {e}")
            return {"conflict": True, "resolution": "manual", "error": str(e)}

    # Handle UPDATE action
    if change.action == "update":
        if not task:
            return {
                "conflict": True,
                "resolution": "manual",
                "error": "Task not found on server"
            }

        # Check version (optimistic locking)
        if task.version != change.version:
            # Version mismatch - apply conflict resolution strategy

            # Strategy 1: Task status - done > open
            if change.data.get("status") == "done" and task.status != "done":
                # Client completed task, apply even if version mismatch
                task.status = "done"
                task.completedAt = datetime.fromisoformat(change.data.get("completedAt")) if change.data.get("completedAt") else datetime.utcnow()
                task.completedBy = current_user.get("sub")
                task.version += 1
                task.updatedAt = datetime.utcnow()
                logger.info(f"Applied 'done wins' strategy for task {change.entity_id}")
                return {"success": True, "resolution_applied": "done_wins"}

            # Strategy 2: Last-writer-wins (timestamp comparison)
            client_timestamp = change.client_timestamp
            if client_timestamp > task.updatedAt:
                # Client change is newer, apply it
                _update_task_fields(task, change.data)
                task.version += 1
                task.updatedAt = datetime.utcnow()
                logger.info(f"Applied LWW strategy for task {change.entity_id}")
                return {"success": True, "resolution_applied": "last_writer_wins"}

            # Conflict: Server wins (server data is newer)
            return {
                "conflict": True,
                "resolution": "server_wins",
                "server_version": task.version,
                "server_data": _task_to_dict(task),
                "client_version": change.version,
                "reason": "Server version is newer"
            }

        # No conflict, apply update
        try:
            _update_task_fields(task, change.data)
            task.version += 1
            task.updatedAt = datetime.utcnow()
            logger.info(f"Updated task {change.entity_id} from client {current_user.get('sub')}")
            return {"success": True, "action": "update"}
        except Exception as e:
            logger.error(f"Failed to update task {change.entity_id}: {e}")
            return {"conflict": True, "resolution": "manual", "error": str(e)}

    return {"conflict": True, "resolution": "manual", "error": "Unknown action"}


def _update_task_fields(task: models.Task, data: Dict[str, Any]):
    """Update task fields from data dict"""
    if "title" in data:
        task.title = data["title"]
    if "desc" in data:
        task.desc = data["desc"]
    if "category" in data:
        task.category = data["category"]
    if "due" in data:
        task.due = datetime.fromisoformat(data["due"]) if data["due"] else None
    if "frequency" in data:
        task.frequency = data["frequency"]
    if "rrule" in data:
        task.rrule = data["rrule"]
    if "assignees" in data:
        task.assignees = data["assignees"]
    if "status" in data:
        task.status = data["status"]
    if "points" in data:
        task.points = data["points"]
    if "priority" in data:
        task.priority = data["priority"]
    if "estDuration" in data:
        task.estDuration = data["estDuration"]
    if "proofPhotos" in data:
        task.proofPhotos = data["proofPhotos"]


def _task_to_dict(task: models.Task) -> Dict[str, Any]:
    """Convert task model to dict"""
    return {
        "id": str(task.id),
        "familyId": str(task.familyId),
        "title": task.title,
        "desc": task.desc,
        "category": task.category,
        "due": task.due.isoformat() if task.due else None,
        "status": task.status,
        "points": task.points,
        "assignees": task.assignees,
        "version": task.version,
        "updatedAt": task.updatedAt.isoformat()
    }


def apply_event_change(
    db: Session,
    change: SyncEntity,
    current_user: Dict[str, Any]
) -> Dict[str, Any]:
    """Apply event change (simplified - events don't have version field yet)"""
    event = db.query(models.Event).filter(models.Event.id == change.entity_id).first()

    if change.action == "delete":
        if event:
            db.delete(event)
        return {"success": True}

    if change.action == "create":
        if event:
            return {
                "conflict": True,
                "resolution": "server_wins",
                "server_data": _event_to_dict(event)
            }

        try:
            new_event = models.Event(
                id=change.entity_id,
                familyId=change.data.get("familyId"),
                title=change.data.get("title"),
                description=change.data.get("description", ""),
                start=datetime.fromisoformat(change.data["start"]),
                end=datetime.fromisoformat(change.data["end"]) if change.data.get("end") else None,
                allDay=change.data.get("allDay", False),
                attendees=change.data.get("attendees", []),
                color=change.data.get("color"),
                rrule=change.data.get("rrule"),
                category=change.data.get("category", "other"),
                createdBy=current_user.get("sub"),
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow()
            )
            db.add(new_event)
            return {"success": True}
        except Exception as e:
            return {"conflict": True, "error": str(e)}

    if change.action == "update" and event:
        try:
            if "title" in change.data:
                event.title = change.data["title"]
            if "description" in change.data:
                event.description = change.data["description"]
            if "start" in change.data:
                event.start = datetime.fromisoformat(change.data["start"])
            if "end" in change.data:
                event.end = datetime.fromisoformat(change.data["end"]) if change.data["end"] else None
            if "attendees" in change.data:
                event.attendees = change.data["attendees"]
            event.updatedAt = datetime.utcnow()
            return {"success": True}
        except Exception as e:
            return {"conflict": True, "error": str(e)}

    return {"conflict": True, "error": "Unknown action"}


def _event_to_dict(event: models.Event) -> Dict[str, Any]:
    """Convert event model to dict"""
    return {
        "id": str(event.id),
        "title": event.title,
        "start": event.start.isoformat(),
        "end": event.end.isoformat() if event.end else None,
        "updatedAt": event.updatedAt.isoformat()
    }


def apply_client_change(
    db: Session,
    change: SyncEntity,
    current_user: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Apply a single client change to server database.

    Routes to entity-specific handlers based on entity_type.
    """
    try:
        if change.entity_type == "task":
            return apply_task_change(db, change, current_user)
        elif change.entity_type == "event":
            return apply_event_change(db, change, current_user)
        # Add more entity types as needed
        else:
            return {"conflict": True, "error": f"Unknown entity type: {change.entity_type}"}
    except Exception as e:
        logger.error(f"Failed to apply change for {change.entity_type} {change.entity_id}: {e}")
        return {"conflict": True, "error": str(e)}


# API Endpoint

@router.post("/delta", response_model=SyncResponse)
async def delta_sync(
    request: SyncRequest,
    db: Session = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Bidirectional delta sync endpoint.

    Client sends:
    - last_sync_at: Last successful sync timestamp
    - changes: List of local changes since last sync
    - device_id: Unique device identifier

    Server returns:
    - server_changes: All server changes since last_sync_at
    - conflicts: List of conflicts that need manual resolution
    - last_sync_at: New timestamp for next sync

    Conflict Resolution:
    1. Task status: done > open (completed takes precedence)
    2. Delete always wins (if server deleted, ignore client update)
    3. Version mismatch: Last-writer-wins OR manual resolution
    4. Concurrent updates: Check version field, reject if stale
    """
    user_id = current_user.get("sub")
    family_id = current_user.get("familyId")

    if not family_id:
        raise HTTPException(400, "User family not found")

    conflicts = []
    applied_count = 0
    error_count = 0

    logger.info(f"Sync started for user {user_id}, device {request.device_id}, {len(request.changes)} changes")

    try:
        # 1. Fetch all server changes since last_sync_at
        server_changes = fetch_server_changes(db, family_id, request.last_sync_at)

        # 2. Apply client changes to server (in transaction)
        for change in request.changes:
            try:
                result = apply_client_change(db, change, current_user)

                if result.get("conflict"):
                    conflicts.append(ConflictInfo(
                        entity_type=change.entity_type,
                        entity_id=change.entity_id,
                        conflict_reason=result.get("reason", result.get("error", "Unknown conflict")),
                        resolution=result.get("resolution", "manual"),
                        client_version=change.version,
                        server_version=result.get("server_version", 0),
                        client_data=change.data,
                        server_data=result.get("server_data")
                    ))
                    error_count += 1
                else:
                    applied_count += 1
            except Exception as e:
                logger.error(f"Error applying change for {change.entity_type} {change.entity_id}: {e}")
                conflicts.append(ConflictInfo(
                    entity_type=change.entity_type,
                    entity_id=change.entity_id,
                    conflict_reason=str(e),
                    resolution="manual",
                    client_version=change.version,
                    server_version=0
                ))
                error_count += 1

        # 3. Commit all changes
        db.commit()

        # 4. Return server changes + conflicts
        sync_timestamp = datetime.utcnow()

        logger.info(f"Sync completed for user {user_id}: {applied_count} applied, {error_count} conflicts, {len(server_changes)} server changes")

        return SyncResponse(
            server_changes=server_changes,
            conflicts=conflicts,
            last_sync_at=sync_timestamp,
            success=len(conflicts) == 0,
            applied_count=applied_count,
            error_count=error_count
        )

    except Exception as e:
        db.rollback()
        logger.error(f"Sync failed for user {user_id}: {e}")
        raise HTTPException(500, f"Sync failed: {str(e)}")
