"""
Gamification Orchestration Service
Central handler for all gamification logic on task completion.
"""

from typing import Dict, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from core.models import Task, User
from services.streak_service import StreakService
from services.badge_service import BadgeService
from services.points_service import PointsService


class GamificationService:
    """Orchestrates all gamification services on task completion."""

    def __init__(self):
        self.streak_service = StreakService()
        self.badge_service = BadgeService()
        self.points_service = PointsService()

    def on_task_completed(
        self,
        task: Task,
        user: User,
        completion_time: datetime,
        db: Session,
        approval_rating: Optional[int] = None
    ) -> Dict:
        """
        Central handler for all gamification logic on task completion.

        This method orchestrates:
        1. Points calculation and award
        2. Streak tracking and updates
        3. Badge checking and awards
        4. Statistics gathering for UI

        Args:
            task: Task that was completed
            user: User who completed the task
            completion_time: When the task was completed
            db: Database session
            approval_rating: Parent approval rating (1-5), if applicable

        Returns:
            Dict with complete gamification response for UI animations
        """
        result = {
            "success": True,
            "user_id": user.id,
            "task_id": task.id,
            "completion_time": completion_time.isoformat()
        }

        try:
            # 1. Calculate and award points
            points, multipliers = self.points_service.calculate_points(
                task=task,
                user=user,
                completion_time=completion_time,
                approval_rating=approval_rating
            )

            self.points_service.award_points(
                user_id=user.id,
                task_id=task.id,
                points=points,
                reason="task_completed",
                db=db
            )

            result["points_earned"] = points
            result["multipliers"] = [
                {"name": name, "value": value} for name, value in multipliers
            ]
            result["total_points"] = self.points_service.get_user_points(user.id, db)

            # 2. Update streak
            streak_stats = self.streak_service.update_streak(
                user_id=user.id,
                completed_date=completion_time.date(),
                db=db
            )

            result["streak"] = streak_stats

            # 3. Check and award badges
            new_badges = self.badge_service.check_and_award_badges(
                user_id=user.id,
                task=task,
                db=db
            )

            # Format badge data for UI
            result["new_badges"] = []
            for badge in new_badges:
                badge_def = self.badge_service.badges.get(badge.code)
                if badge_def:
                    result["new_badges"].append({
                        "id": badge.id,
                        "code": badge.code,
                        "name": badge_def.name,
                        "description": badge_def.description,
                        "icon": badge_def.icon,
                        "category": badge_def.category
                    })

            # 4. Get badge progress for next unlocks
            badge_progress = self.badge_service.get_badge_progress(user.id, db)

            # Find badges close to unlocking (>75% progress)
            close_badges = {
                code: data for code, data in badge_progress.items()
                if data["progress"] >= 0.75
            }

            result["close_to_unlock"] = close_badges

            # 5. Get leaderboard position
            leaderboard = self.points_service.get_leaderboard(
                family_id=user.familyId,
                db=db,
                period="week"
            )

            user_rank = None
            for entry in leaderboard:
                if entry["user_id"] == user.id:
                    user_rank = entry["rank"]
                    break

            result["leaderboard_position"] = user_rank

            # 6. Check for special achievements
            achievements = self._check_special_achievements(
                user=user,
                task=task,
                points_earned=points,
                new_badges=new_badges,
                streak_stats=streak_stats,
                db=db
            )

            result["special_achievements"] = achievements

            # Commit all changes
            db.commit()

            return result

        except Exception as e:
            db.rollback()
            result["success"] = False
            result["error"] = str(e)
            return result

    def get_gamification_profile(
        self,
        user_id: str,
        db: Session
    ) -> Dict:
        """
        Get complete gamification profile for user.

        Returns:
            Dict with all gamification data (points, badges, streaks, progress)
        """
        user = db.query(User).filter_by(id=user_id).first()
        if not user:
            return {"error": "User not found"}

        # Points summary
        points_summary = self.points_service.get_points_summary(user_id, db)

        # Streak stats
        streak_stats = self.streak_service.get_streak_stats(user_id, db)

        # Badges
        earned_badges = self.badge_service.get_user_badges(user_id, db)
        badge_progress = self.badge_service.get_badge_progress(user_id, db)

        # Leaderboard
        leaderboard_week = self.points_service.get_leaderboard(
            family_id=user.familyId,
            db=db,
            period="week",
            limit=10
        )

        leaderboard_alltime = self.points_service.get_leaderboard(
            family_id=user.familyId,
            db=db,
            period="alltime",
            limit=10
        )

        # Affordable rewards
        affordable_rewards = self.points_service.get_affordable_rewards(
            user_id=user_id,
            family_id=user.familyId,
            db=db
        )

        return {
            "user_id": user_id,
            "display_name": user.displayName,
            "role": user.role,
            "points": points_summary,
            "streak": streak_stats,
            "badges": {
                "earned": earned_badges,
                "total_earned": len(earned_badges),
                "progress": badge_progress,
                "available": len(self.badge_service.badges)
            },
            "leaderboard": {
                "week": leaderboard_week,
                "alltime": leaderboard_alltime
            },
            "rewards": {
                "affordable": affordable_rewards,
                "count": len(affordable_rewards)
            }
        }

    def _check_special_achievements(
        self,
        user: User,
        task: Task,
        points_earned: int,
        new_badges: list,
        streak_stats: Dict,
        db: Session
    ) -> list:
        """
        Check for special one-time achievements to highlight.

        Returns:
            List of special achievement messages for UI
        """
        achievements = []

        # First task ever
        total_tasks = db.query(Task).filter(
            Task.completedBy == user.id,
            Task.status == "done"
        ).count()

        if total_tasks == 1:
            achievements.append({
                "type": "first_task",
                "message": "Your first task completed!",
                "icon": "🎉"
            })

        # High points earned (>50)
        if points_earned >= 50:
            achievements.append({
                "type": "high_points",
                "message": f"Wow! {points_earned} points earned!",
                "icon": "💰"
            })

        # Multiple new badges
        if len(new_badges) > 1:
            achievements.append({
                "type": "badge_combo",
                "message": f"Earned {len(new_badges)} badges at once!",
                "icon": "🏅"
            })

        # Streak milestones
        current_streak = streak_stats.get("current", 0)
        if current_streak in [3, 7, 14, 30]:
            achievements.append({
                "type": "streak_milestone",
                "message": f"{current_streak}-day streak achieved!",
                "icon": "🔥"
            })

        # Personal best streak
        if current_streak == streak_stats.get("longest", 0) and current_streak > 1:
            achievements.append({
                "type": "personal_best",
                "message": "New personal best streak!",
                "icon": "👑"
            })

        # Round number milestones (10, 25, 50, 100 tasks)
        if total_tasks in [10, 25, 50, 100]:
            achievements.append({
                "type": "task_milestone",
                "message": f"{total_tasks} tasks completed!",
                "icon": "⭐"
            })

        return achievements

    def preview_task_rewards(
        self,
        task: Task,
        user: User,
        db: Session
    ) -> Dict:
        """
        Preview points and potential badges for completing a task.

        Useful for showing users what they'll earn before completion.

        Args:
            task: Task to preview
            user: User who would complete it
            db: Database session

        Returns:
            Dict with estimated rewards
        """
        # Calculate base points (no multipliers without actual completion time)
        base_points = task.points if task.points else 10

        # Estimate multipliers
        estimated_multipliers = []
        estimated_points = float(base_points)

        # If task has due date in future
        if task.due and task.due > datetime.utcnow():
            estimated_multipliers.append({
                "name": "on_time",
                "value": 1.2,
                "description": "Complete before due date"
            })
            estimated_points *= 1.2

        # Current streak bonus
        streak_stats = self.streak_service.get_streak_stats(user.id, db)
        current_streak = streak_stats.get("current", 0)

        if current_streak >= 7:
            estimated_multipliers.append({
                "name": "streak_week",
                "value": 1.1,
                "description": "Week streak bonus"
            })
            estimated_points *= 1.1

        # Potential badges
        potential_badges = []
        badge_progress = self.badge_service.get_badge_progress(user.id, db)

        for code, data in badge_progress.items():
            if data["progress"] >= 0.9:  # Within 10% of unlocking
                potential_badges.append({
                    "code": code,
                    "name": data["name"],
                    "icon": data["icon"],
                    "progress": data["progress"]
                })

        return {
            "base_points": base_points,
            "estimated_points": int(estimated_points),
            "estimated_multipliers": estimated_multipliers,
            "potential_badges": potential_badges,
            "current_streak": current_streak
        }
