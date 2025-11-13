"""
Sync Service Layer

Provides helper functions for delta synchronization operations including
batch processing, conflict resolution, and family-wide change aggregation.
"""

from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from typing import List, Dict, Any
from core import models
import logging

logger = logging.getLogger(__name__)


class SyncService:
    """Service layer for sync operations"""

    @staticmethod
    def get_family_changes_since(
        db: Session,
        family_id: str,
        since: datetime
    ) -> Dict[str, List[Dict]]:
        """
        Get all changes for a family since timestamp.

        Returns:
        {
            "tasks": [...],
            "events": [...],
            "points": [...],
            "streaks": [...],
            "badges": [...]
        }
        """
        changes = {
            "tasks": [],
            "events": [],
            "points": [],
            "streaks": [],
            "badges": []
        }

        # Tasks
        tasks = db.query(models.Task).filter(
            models.Task.familyId == family_id,
            models.Task.updatedAt > since
        ).all()

        for task in tasks:
            changes["tasks"].append({
                "id": str(task.id),
                "title": task.title,
                "status": task.status,
                "assignees": task.assignees,
                "due": task.due.isoformat() if task.due else None,
                "version": task.version,
                "updatedAt": task.updatedAt.isoformat()
            })

        # Events
        events = db.query(models.Event).filter(
            models.Event.familyId == family_id,
            models.Event.updatedAt > since
        ).all()

        for event in events:
            changes["events"].append({
                "id": str(event.id),
                "title": event.title,
                "start": event.start.isoformat(),
                "end": event.end.isoformat() if event.end else None,
                "attendees": event.attendees,
                "updatedAt": event.updatedAt.isoformat()
            })

        # Points ledger
        points = db.query(models.PointsLedger).join(
            models.User, models.PointsLedger.userId == models.User.id
        ).filter(
            models.User.familyId == family_id,
            models.PointsLedger.createdAt > since
        ).all()

        for entry in points:
            changes["points"].append({
                "id": str(entry.id),
                "userId": str(entry.userId),
                "delta": entry.delta,
                "reason": entry.reason,
                "taskId": entry.taskId,
                "createdAt": entry.createdAt.isoformat()
            })

        # User streaks
        streaks = db.query(models.UserStreak).join(
            models.User, models.UserStreak.userId == models.User.id
        ).filter(
            models.User.familyId == family_id,
            models.UserStreak.updatedAt > since
        ).all()

        for streak in streaks:
            changes["streaks"].append({
                "id": str(streak.id),
                "userId": str(streak.userId),
                "currentStreak": streak.currentStreak,
                "longestStreak": streak.longestStreak,
                "updatedAt": streak.updatedAt.isoformat()
            })

        # Badges
        badges = db.query(models.Badge).join(
            models.User, models.Badge.userId == models.User.id
        ).filter(
            models.User.familyId == family_id,
            models.Badge.awardedAt > since
        ).all()

        for badge in badges:
            changes["badges"].append({
                "id": str(badge.id),
                "userId": str(badge.userId),
                "code": badge.code,
                "awardedAt": badge.awardedAt.isoformat()
            })

        return changes

    @staticmethod
    def apply_batch_changes(
        db: Session,
        changes: List[Dict[str, Any]],
        user: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Apply multiple changes in a transaction.
        Rolls back all if any critical error.

        Returns:
        {
            "applied": 15,
            "conflicts": 2,
            "errors": 1,
            "details": [...]
        }
        """
        applied = 0
        conflicts = 0
        errors = 0
        details = []

        try:
            for change in changes:
                try:
                    # Route to appropriate handler based on entity type
                    entity_type = change.get("entity_type")

                    if entity_type == "task":
                        result = SyncService._apply_task_batch(db, change, user)
                    elif entity_type == "event":
                        result = SyncService._apply_event_batch(db, change, user)
                    else:
                        result = {"error": f"Unknown entity type: {entity_type}"}

                    if result.get("success"):
                        applied += 1
                    elif result.get("conflict"):
                        conflicts += 1
                    else:
                        errors += 1

                    details.append({
                        "entity_id": change.get("entity_id"),
                        "entity_type": entity_type,
                        "result": result
                    })

                except Exception as e:
                    logger.error(f"Batch change failed for {change.get('entity_id')}: {e}")
                    errors += 1
                    details.append({
                        "entity_id": change.get("entity_id"),
                        "error": str(e)
                    })

            # Commit all changes if no critical errors
            if errors == 0 or errors < len(changes) * 0.1:  # Allow 10% error rate
                db.commit()
            else:
                db.rollback()
                logger.warning(f"Rolled back batch: {errors} errors out of {len(changes)} changes")

            return {
                "applied": applied,
                "conflicts": conflicts,
                "errors": errors,
                "details": details
            }

        except Exception as e:
            db.rollback()
            logger.error(f"Batch transaction failed: {e}")
            return {
                "applied": 0,
                "conflicts": 0,
                "errors": len(changes),
                "error": str(e)
            }

    @staticmethod
    def _apply_task_batch(
        db: Session,
        change: Dict[str, Any],
        user: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Apply single task change in batch context"""
        from routers.sync import apply_task_change, SyncEntity

        # Convert dict to SyncEntity
        entity = SyncEntity(
            entity_type="task",
            entity_id=change.get("entity_id"),
            action=change.get("action"),
            data=change.get("data", {}),
            version=change.get("version", 0),
            client_timestamp=datetime.fromisoformat(change.get("client_timestamp"))
        )

        return apply_task_change(db, entity, user)

    @staticmethod
    def _apply_event_batch(
        db: Session,
        change: Dict[str, Any],
        user: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Apply single event change in batch context"""
        from routers.sync import apply_event_change, SyncEntity

        entity = SyncEntity(
            entity_type="event",
            entity_id=change.get("entity_id"),
            action=change.get("action"),
            data=change.get("data", {}),
            version=change.get("version", 0),
            client_timestamp=datetime.fromisoformat(change.get("client_timestamp"))
        )

        return apply_event_change(db, entity, user)

    @staticmethod
    def resolve_conflict_auto(
        client_data: Dict,
        server_data: Dict,
        entity_type: str
    ) -> Dict[str, Any]:
        """
        Automatic conflict resolution based on entity type.

        Strategies:
        - Task: done > open, delete wins, LWW on timestamp
        - Event: LWW on timestamp
        - Points: Server always wins (immutable)

        Returns:
        {
            "winner": "client" | "server" | "merge",
            "resolved_data": {...}
        }
        """
        if entity_type == "task":
            # Strategy 1: Task completion wins
            if client_data.get("status") == "done" and server_data.get("status") != "done":
                return {
                    "winner": "client",
                    "resolved_data": client_data,
                    "reason": "done_wins"
                }

            if server_data.get("status") == "done" and client_data.get("status") != "done":
                return {
                    "winner": "server",
                    "resolved_data": server_data,
                    "reason": "done_wins"
                }

            # Strategy 2: LWW on timestamp
            client_ts = datetime.fromisoformat(client_data.get("updatedAt", "2000-01-01T00:00:00"))
            server_ts = datetime.fromisoformat(server_data.get("updatedAt", "2000-01-01T00:00:00"))

            if client_ts > server_ts:
                return {
                    "winner": "client",
                    "resolved_data": client_data,
                    "reason": "last_writer_wins"
                }
            else:
                return {
                    "winner": "server",
                    "resolved_data": server_data,
                    "reason": "last_writer_wins"
                }

        elif entity_type == "event":
            # LWW for events
            client_ts = datetime.fromisoformat(client_data.get("updatedAt", "2000-01-01T00:00:00"))
            server_ts = datetime.fromisoformat(server_data.get("updatedAt", "2000-01-01T00:00:00"))

            return {
                "winner": "client" if client_ts > server_ts else "server",
                "resolved_data": client_data if client_ts > server_ts else server_data,
                "reason": "last_writer_wins"
            }

        elif entity_type == "points_ledger":
            # Points are immutable - server always wins
            return {
                "winner": "server",
                "resolved_data": server_data,
                "reason": "immutable"
            }

        else:
            # Unknown entity type - default to server wins
            return {
                "winner": "server",
                "resolved_data": server_data,
                "reason": "unknown_entity_type"
            }

    @staticmethod
    def get_sync_stats(
        db: Session,
        family_id: str,
        since: datetime
    ) -> Dict[str, Any]:
        """
        Get sync statistics for monitoring and debugging.

        Returns:
        {
            "total_changes": 42,
            "by_entity": {
                "tasks": 15,
                "events": 10,
                "points": 12,
                "streaks": 3,
                "badges": 2
            },
            "time_range": {
                "start": "2025-11-10T00:00:00Z",
                "end": "2025-11-11T12:34:56Z"
            }
        }
        """
        changes = SyncService.get_family_changes_since(db, family_id, since)

        return {
            "total_changes": sum(len(v) for v in changes.values()),
            "by_entity": {k: len(v) for k, v in changes.items()},
            "time_range": {
                "start": since.isoformat(),
                "end": datetime.utcnow().isoformat()
            }
        }

    @staticmethod
    def clean_old_sync_data(
        db: Session,
        older_than_days: int = 90
    ) -> int:
        """
        Clean up old sync-related data for storage optimization.

        Deletes:
        - Old completed tasks (>90 days)
        - Old task logs (>90 days)
        - Old points ledger entries (>90 days, keep badges)

        Returns:
            Number of records deleted
        """
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        deleted = 0

        # Delete old completed tasks
        old_tasks = db.query(models.Task).filter(
            models.Task.status == "done",
            models.Task.completedAt < cutoff_date
        ).delete()
        deleted += old_tasks

        # Delete old task logs
        old_logs = db.query(models.TaskLog).filter(
            models.TaskLog.createdAt < cutoff_date
        ).delete()
        deleted += old_logs

        # Note: Keep points ledger for historical tracking
        # Note: Keep badges forever (achievements)

        db.commit()
        logger.info(f"Cleaned up {deleted} old sync records older than {older_than_days} days")

        return deleted
