"""
Streak Tracking Service
Manages daily completion streaks for gamification.
"""

from datetime import date, datetime, timedelta
from typing import Optional, Dict
from sqlalchemy.orm import Session
from core.models import UserStreak, User, AuditLog
from uuid import uuid4


class StreakService:
    """Service for tracking user completion streaks."""

    def update_streak(
        self,
        user_id: str,
        completed_date: date,
        db: Session
    ) -> Dict:
        """
        Update user's streak on task completion.

        Args:
            user_id: User ID completing the task
            completed_date: Date the task was completed
            db: Database session

        Returns:
            Dict with streak statistics
        """
        # Get or create UserStreak record
        streak = db.query(UserStreak).filter_by(userId=user_id).first()

        if not streak:
            streak = UserStreak(
                id=str(uuid4()),
                userId=user_id,
                currentStreak=1,
                longestStreak=1,
                lastCompletionDate=datetime.combine(completed_date, datetime.min.time()),
                updatedAt=datetime.utcnow()
            )
            db.add(streak)
            db.flush()

            # Log streak start
            self._log_streak_event(
                db=db,
                user_id=user_id,
                action="streak.started",
                meta={"streak": 1, "date": completed_date.isoformat()}
            )

            db.commit()
            return self.get_streak_stats(user_id, db)

        # Check if this is a consecutive day
        last_completion = streak.lastCompletionDate.date() if streak.lastCompletionDate else None

        if last_completion:
            days_since_last = (completed_date - last_completion).days

            if days_since_last == 0:
                # Same day completion, no streak change
                return self.get_streak_stats(user_id, db)

            elif days_since_last == 1:
                # Consecutive day, increment streak
                streak.currentStreak += 1

                # Update longest streak if needed
                if streak.currentStreak > streak.longestStreak:
                    streak.longestStreak = streak.currentStreak
                    self._log_streak_event(
                        db=db,
                        user_id=user_id,
                        action="streak.longest_updated",
                        meta={
                            "new_longest": streak.longestStreak,
                            "date": completed_date.isoformat()
                        }
                    )

                # Check for streak milestones
                self._check_streak_milestones(
                    db=db,
                    user_id=user_id,
                    current_streak=streak.currentStreak,
                    completed_date=completed_date
                )

            else:
                # Streak broken, reset to 1
                old_streak = streak.currentStreak
                streak.currentStreak = 1

                self._log_streak_event(
                    db=db,
                    user_id=user_id,
                    action="streak.broken",
                    meta={
                        "previous_streak": old_streak,
                        "days_missed": days_since_last - 1,
                        "date": completed_date.isoformat()
                    }
                )

        # Update last completion date
        streak.lastCompletionDate = datetime.combine(completed_date, datetime.min.time())
        streak.updatedAt = datetime.utcnow()

        db.commit()
        return self.get_streak_stats(user_id, db)

    def check_streak_guard(self, user_id: str, db: Session) -> bool:
        """
        Check if streak is at risk (no completion today).
        Called by notification cron job at 20:00.

        Args:
            user_id: User ID to check
            db: Database session

        Returns:
            True if streak is at risk, False otherwise
        """
        streak = db.query(UserStreak).filter_by(userId=user_id).first()

        if not streak or not streak.lastCompletionDate:
            return False

        today = date.today()
        last_completion = streak.lastCompletionDate.date()

        # Streak is at risk if last completion was yesterday and no completion today
        return last_completion < today and streak.currentStreak > 0

    def get_streak_stats(self, user_id: str, db: Session) -> Dict:
        """
        Return streak statistics for UI.

        Args:
            user_id: User ID
            db: Database session

        Returns:
            Dict with streak statistics
        """
        streak = db.query(UserStreak).filter_by(userId=user_id).first()

        if not streak:
            return {
                "current": 0,
                "longest": 0,
                "days_since_last": None,
                "is_at_risk": False,
                "last_completion_date": None
            }

        days_since_last = None
        last_completion_date = None

        if streak.lastCompletionDate:
            last_completion_date = streak.lastCompletionDate.date().isoformat()
            days_since_last = (date.today() - streak.lastCompletionDate.date()).days

        is_at_risk = self.check_streak_guard(user_id, db)

        return {
            "current": streak.currentStreak,
            "longest": streak.longestStreak,
            "days_since_last": days_since_last,
            "is_at_risk": is_at_risk,
            "last_completion_date": last_completion_date
        }

    def _check_streak_milestones(
        self,
        db: Session,
        user_id: str,
        current_streak: int,
        completed_date: date
    ):
        """Check for streak milestones and trigger badge awards."""
        milestones = [3, 7, 14, 30, 60, 100]

        if current_streak in milestones:
            self._log_streak_event(
                db=db,
                user_id=user_id,
                action="streak.milestone",
                meta={
                    "milestone": current_streak,
                    "date": completed_date.isoformat()
                }
            )

    def _log_streak_event(
        self,
        db: Session,
        user_id: str,
        action: str,
        meta: Dict
    ):
        """Log streak event to audit log."""
        user = db.query(User).filter_by(id=user_id).first()
        if not user:
            return

        log_entry = AuditLog(
            id=str(uuid4()),
            actorUserId=user_id,
            familyId=user.familyId,
            action=action,
            meta=meta,
            createdAt=datetime.utcnow()
        )
        db.add(log_entry)
