"""
Points Calculation Service
Manages points economy with multipliers and redemption.
"""

from typing import Tuple, List, Dict, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import func
from core.models import Task, User, PointsLedger, UserStreak, Reward, AuditLog
from uuid import uuid4


class PointsService:
    """Service for calculating and managing user points."""

    def calculate_points(
        self,
        task: Task,
        user: User,
        completion_time: datetime,
        approval_rating: Optional[int] = None
    ) -> Tuple[int, List[Tuple[str, float]]]:
        """
        Calculate points for task completion with multipliers.

        Args:
            task: Task that was completed
            user: User who completed the task
            completion_time: When the task was completed
            approval_rating: Parent approval rating (1-5), if applicable

        Returns:
            Tuple of (final_points, list of (multiplier_name, multiplier_value))
        """
        base_points = task.points if task.points else 10
        multipliers = []

        # On-time bonus (completed before due)
        if task.due and completion_time < task.due:
            multipliers.append(("on_time", 1.2))
        # Overdue penalty
        elif task.due and completion_time > task.due:
            multipliers.append(("overdue", 0.8))

        # Quality bonus (if parent approved with rating)
        if approval_rating:
            if approval_rating >= 5:
                multipliers.append(("quality_excellent", 1.2))
            elif approval_rating >= 4:
                multipliers.append(("quality_good", 1.1))

        # Streak bonus (if user has active streak)
        from services.streak_service import StreakService
        streak_service = StreakService()
        streak = streak_service.get_streak_stats(user.id, Session.object_session(user))

        current_streak = streak.get("current", 0)
        if current_streak >= 30:
            multipliers.append(("streak_month", 1.3))
        elif current_streak >= 14:
            multipliers.append(("streak_two_weeks", 1.2))
        elif current_streak >= 7:
            multipliers.append(("streak_week", 1.1))

        # Speed bonus (completed faster than estimated)
        if hasattr(task, 'createdAt') and hasattr(task, 'completedAt') and task.estDuration:
            actual_duration = (task.completedAt - task.createdAt).total_seconds() / 60
            if actual_duration < task.estDuration * 0.5:
                multipliers.append(("speed_demon", 1.15))
            elif actual_duration < task.estDuration * 0.75:
                multipliers.append(("speed_bonus", 1.05))

        # Photo proof bonus (extra effort)
        if task.photoRequired and task.proofPhotos:
            multipliers.append(("photo_proof", 1.05))

        # Claimed task bonus (helper motivation)
        if task.claimable and task.claimedBy == user.id:
            multipliers.append(("helper_bonus", 1.1))

        # Calculate final points
        final_points = float(base_points)
        for name, mult in multipliers:
            final_points *= mult

        return int(final_points), multipliers

    def award_points(
        self,
        user_id: str,
        task_id: Optional[str],
        points: int,
        reason: str,
        db: Session,
        reward_id: Optional[str] = None
    ):
        """
        Award points to user and log in ledger.

        Args:
            user_id: User ID receiving points
            task_id: Task ID (if points from task completion)
            points: Points to award (positive) or deduct (negative)
            reason: Reason for points transaction
            db: Database session
            reward_id: Reward ID (if points spent on reward)
        """
        # Create ledger entry
        entry = PointsLedger(
            id=str(uuid4()),
            userId=user_id,
            delta=points,
            reason=reason,
            taskId=task_id,
            rewardId=reward_id,
            createdAt=datetime.utcnow()
        )
        db.add(entry)

        # Log to audit log
        user = db.query(User).filter_by(id=user_id).first()
        if user:
            log_entry = AuditLog(
                id=str(uuid4()),
                actorUserId=user_id,
                familyId=user.familyId,
                action="points.awarded" if points > 0 else "points.spent",
                meta={
                    "delta": points,
                    "reason": reason,
                    "task_id": task_id,
                    "reward_id": reward_id,
                    "new_balance": self.get_user_points(user_id, db)
                },
                createdAt=datetime.utcnow()
            )
            db.add(log_entry)

        db.flush()

    def get_user_points(self, user_id: str, db: Session) -> int:
        """
        Calculate total points for user.

        Args:
            user_id: User ID
            db: Database session

        Returns:
            Total points balance
        """
        total = db.query(func.sum(PointsLedger.delta)).filter(
            PointsLedger.userId == user_id
        ).scalar()

        return int(total) if total else 0

    def get_points_history(
        self,
        user_id: str,
        db: Session,
        limit: int = 50
    ) -> List[Dict]:
        """
        Get points transaction history for user.

        Args:
            user_id: User ID
            db: Database session
            limit: Maximum number of entries to return

        Returns:
            List of transaction dictionaries
        """
        entries = db.query(PointsLedger).filter(
            PointsLedger.userId == user_id
        ).order_by(PointsLedger.createdAt.desc()).limit(limit).all()

        history = []
        running_balance = self.get_user_points(user_id, db)

        for entry in entries:
            history.append({
                "id": entry.id,
                "delta": entry.delta,
                "reason": entry.reason,
                "task_id": entry.taskId,
                "reward_id": entry.rewardId,
                "created_at": entry.createdAt.isoformat(),
                "balance_after": running_balance
            })
            running_balance -= entry.delta

        return history

    def spend_points(
        self,
        user_id: str,
        reward_id: str,
        cost: int,
        db: Session,
        require_approval: bool = False
    ) -> Dict:
        """
        Spend points on reward (shop redemption).

        Args:
            user_id: User ID spending points
            reward_id: Reward being redeemed
            cost: Point cost of reward
            db: Database session
            require_approval: Whether parent approval is needed

        Returns:
            Dict with redemption status

        Raises:
            ValueError: If insufficient points or reward not found
        """
        # Check user has enough points
        current_points = self.get_user_points(user_id, db)
        if current_points < cost:
            raise ValueError(
                f"Insufficient points. Have {current_points}, need {cost}"
            )

        # Verify reward exists and is active
        reward = db.query(Reward).filter_by(id=reward_id).first()
        if not reward:
            raise ValueError("Reward not found")

        if not reward.isActive:
            raise ValueError("Reward is no longer available")

        # Deduct points
        self.award_points(
            user_id=user_id,
            task_id=None,
            points=-cost,
            reason=f"Redeemed: {reward.name}",
            db=db,
            reward_id=reward_id
        )

        # Log redemption
        user = db.query(User).filter_by(id=user_id).first()
        if user:
            log_entry = AuditLog(
                id=str(uuid4()),
                actorUserId=user_id,
                familyId=user.familyId,
                action="reward.redeemed",
                meta={
                    "reward_id": reward_id,
                    "reward_name": reward.name,
                    "cost": cost,
                    "requires_approval": require_approval,
                    "new_balance": self.get_user_points(user_id, db)
                },
                createdAt=datetime.utcnow()
            )
            db.add(log_entry)

        db.commit()

        return {
            "success": True,
            "reward_id": reward_id,
            "reward_name": reward.name,
            "cost": cost,
            "new_balance": self.get_user_points(user_id, db),
            "requires_approval": require_approval
        }

    def get_affordable_rewards(
        self,
        user_id: str,
        family_id: str,
        db: Session
    ) -> List[Dict]:
        """
        Get rewards user can afford with current points.

        Args:
            user_id: User ID
            family_id: Family ID
            db: Database session

        Returns:
            List of affordable reward dictionaries
        """
        current_points = self.get_user_points(user_id, db)

        rewards = db.query(Reward).filter(
            Reward.familyId == family_id,
            Reward.isActive == True,
            Reward.cost <= current_points
        ).order_by(Reward.cost.asc()).all()

        return [
            {
                "id": r.id,
                "name": r.name,
                "description": r.description,
                "cost": r.cost,
                "icon": r.icon,
                "can_afford": True
            }
            for r in rewards
        ]

    def get_leaderboard(
        self,
        family_id: str,
        db: Session,
        period: str = "week",
        limit: int = 10
    ) -> List[Dict]:
        """
        Get family leaderboard for specified period.

        Args:
            family_id: Family ID
            db: Database session
            period: Time period (week, month, alltime)
            limit: Maximum number of users to return

        Returns:
            List of leaderboard entries with rankings
        """
        # Get family users
        users = db.query(User).filter_by(familyId=family_id).all()
        user_ids = [u.id for u in users]

        # Calculate time filter
        now = datetime.utcnow()
        if period == "week":
            from datetime import timedelta
            cutoff = now - timedelta(days=7)
        elif period == "month":
            from datetime import timedelta
            cutoff = now - timedelta(days=30)
        else:
            cutoff = None

        # Get points for each user
        leaderboard = []

        for user in users:
            # Skip helper role from leaderboard
            if user.role == "helper":
                continue

            query = db.query(func.sum(PointsLedger.delta)).filter(
                PointsLedger.userId == user.id
            )

            if cutoff:
                query = query.filter(PointsLedger.createdAt >= cutoff)

            total_points = query.scalar() or 0

            if total_points > 0:
                leaderboard.append({
                    "user_id": user.id,
                    "display_name": user.displayName,
                    "avatar": user.avatar,
                    "role": user.role,
                    "points": int(total_points)
                })

        # Sort by points descending
        leaderboard.sort(key=lambda x: x["points"], reverse=True)

        # Add rankings
        for idx, entry in enumerate(leaderboard[:limit], start=1):
            entry["rank"] = idx

        return leaderboard[:limit]

    def get_points_summary(self, user_id: str, db: Session) -> Dict:
        """
        Get comprehensive points summary for user.

        Args:
            user_id: User ID
            db: Database session

        Returns:
            Dict with points statistics
        """
        total_points = self.get_user_points(user_id, db)

        # Points earned (positive deltas only)
        total_earned = db.query(func.sum(PointsLedger.delta)).filter(
            PointsLedger.userId == user_id,
            PointsLedger.delta > 0
        ).scalar() or 0

        # Points spent (negative deltas only)
        total_spent = db.query(func.sum(PointsLedger.delta)).filter(
            PointsLedger.userId == user_id,
            PointsLedger.delta < 0
        ).scalar() or 0

        # Recent transactions
        recent_history = self.get_points_history(user_id, db, limit=10)

        # Get user's family for leaderboard position
        user = db.query(User).filter_by(id=user_id).first()
        leaderboard_position = None

        if user:
            leaderboard = self.get_leaderboard(user.familyId, db, period="alltime")
            for idx, entry in enumerate(leaderboard, start=1):
                if entry["user_id"] == user_id:
                    leaderboard_position = idx
                    break

        return {
            "current_balance": int(total_points),
            "total_earned": int(total_earned),
            "total_spent": abs(int(total_spent)),
            "recent_history": recent_history,
            "leaderboard_position": leaderboard_position
        }
