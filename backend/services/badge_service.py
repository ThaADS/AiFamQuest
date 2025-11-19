"""
Badge Awarding Service
Manages badge definitions and awarding logic with persona-specific motivations.
"""

from typing import List, Dict, Optional, Callable
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import func
from core.models import Badge, User, Task, TaskLog, PointsLedger, UserStreak, AuditLog
from uuid import uuid4


# Badge Definition Type
BadgeCondition = Callable[[User, Dict], bool]


class BadgeDefinition:
    """Badge definition with metadata and conditions."""

    def __init__(
        self,
        code: str,
        name: str,
        description: str,
        icon: str,
        condition: BadgeCondition,
        category: str = "general",
        persona_relevance: Optional[List[str]] = None
    ):
        self.code = code
        self.name = name
        self.description = description
        self.icon = icon
        self.condition = condition
        self.category = category
        self.persona_relevance = persona_relevance or ["child", "teen", "parent"]


class BadgeService:
    """Service for managing and awarding badges."""

    def __init__(self):
        self.badges = self._initialize_badge_definitions()

    def _initialize_badge_definitions(self) -> Dict[str, BadgeDefinition]:
        """Initialize all badge definitions with persona-specific motivations."""

        badges = {}

        # Streak Badges (All personas - build habits)
        badges["streak_3"] = BadgeDefinition(
            code="streak_3",
            name="3-Day Streak",
            description="Complete at least one task for 3 consecutive days",
            icon="🔥",
            condition=lambda user, stats: stats.get("streak", {}).get("current", 0) >= 3,
            category="streak",
            persona_relevance=["child", "teen", "parent"]
        )

        badges["streak_7"] = BadgeDefinition(
            code="streak_7",
            name="Week Warrior",
            description="Complete tasks for 7 consecutive days",
            icon="⭐",
            condition=lambda user, stats: stats.get("streak", {}).get("current", 0) >= 7,
            category="streak",
            persona_relevance=["child", "teen", "parent"]
        )

        badges["streak_14"] = BadgeDefinition(
            code="streak_14",
            name="Two Week Champion",
            description="Complete tasks for 14 consecutive days",
            icon="🏅",
            condition=lambda user, stats: stats.get("streak", {}).get("current", 0) >= 14,
            category="streak",
            persona_relevance=["teen", "parent"]
        )

        badges["streak_30"] = BadgeDefinition(
            code="streak_30",
            name="Monthly Master",
            description="Complete tasks for 30 consecutive days",
            icon="👑",
            condition=lambda user, stats: stats.get("streak", {}).get("current", 0) >= 30,
            category="streak",
            persona_relevance=["teen", "parent"]
        )

        # Task Completion Badges (Progressive motivation)
        badges["first_task"] = BadgeDefinition(
            code="first_task",
            name="First Steps",
            description="Complete your first task",
            icon="🎯",
            condition=lambda user, stats: stats.get("tasks_completed", 0) >= 1,
            category="completion",
            persona_relevance=["child", "teen"]
        )

        badges["tasks_10"] = BadgeDefinition(
            code="tasks_10",
            name="Getting Started",
            description="Complete 10 tasks",
            icon="💪",
            condition=lambda user, stats: stats.get("tasks_completed", 0) >= 10,
            category="completion",
            persona_relevance=["child", "teen"]
        )

        badges["tasks_25"] = BadgeDefinition(
            code="tasks_25",
            name="Helping Hand",
            description="Complete 25 tasks",
            icon="🌟",
            condition=lambda user, stats: stats.get("tasks_completed", 0) >= 25,
            category="completion",
            persona_relevance=["child", "teen"]
        )

        badges["tasks_50"] = BadgeDefinition(
            code="tasks_50",
            name="Task Master",
            description="Complete 50 tasks",
            icon="🏆",
            condition=lambda user, stats: stats.get("tasks_completed", 0) >= 50,
            category="completion",
            persona_relevance=["child", "teen", "parent"]
        )

        badges["tasks_100"] = BadgeDefinition(
            code="tasks_100",
            name="Century Club",
            description="Complete 100 tasks",
            icon="💎",
            condition=lambda user, stats: stats.get("tasks_completed", 0) >= 100,
            category="completion",
            persona_relevance=["teen", "parent"]
        )

        # Speed Badges (Boys 10-15: competition, time-trials)
        badges["speed_demon"] = BadgeDefinition(
            code="speed_demon",
            name="Speed Demon",
            description="Complete a task in less than 50% of estimated time",
            icon="⚡",
            condition=lambda user, stats: stats.get("speed_completion", False),
            category="speed",
            persona_relevance=["child", "teen"]
        )

        badges["efficiency_master"] = BadgeDefinition(
            code="efficiency_master",
            name="Efficiency Master",
            description="Complete 10 tasks faster than estimated",
            icon="🚀",
            condition=lambda user, stats: stats.get("fast_completions", 0) >= 10,
            category="speed",
            persona_relevance=["teen"]
        )

        # Quality Badges (All personas - excellence)
        badges["perfectionist"] = BadgeDefinition(
            code="perfectionist",
            name="Perfectionist",
            description="Get 5-star approval on 10 tasks",
            icon="✨",
            condition=lambda user, stats: stats.get("five_star_tasks", 0) >= 10,
            category="quality",
            persona_relevance=["child", "teen"]
        )

        badges["first_approval"] = BadgeDefinition(
            code="first_approval",
            name="Approved!",
            description="Get your first parental approval",
            icon="👍",
            condition=lambda user, stats: stats.get("approved_tasks", 0) >= 1,
            category="quality",
            persona_relevance=["child", "teen"]
        )

        # Helper Badges (Teamwork, claiming tasks from pool)
        badges["helper_hero"] = BadgeDefinition(
            code="helper_hero",
            name="Helper Hero",
            description="Claim and complete a task from the shared pool",
            icon="🦸",
            condition=lambda user, stats: stats.get("claimed_tasks", 0) >= 1,
            category="helper",
            persona_relevance=["child", "teen", "parent"]
        )

        badges["team_player"] = BadgeDefinition(
            code="team_player",
            name="Team Player",
            description="Claim and complete 10 tasks from the shared pool",
            icon="🤝",
            condition=lambda user, stats: stats.get("claimed_tasks", 0) >= 10,
            category="helper",
            persona_relevance=["teen", "parent"]
        )

        # Time-Based Badges (Fun milestones)
        badges["early_bird"] = BadgeDefinition(
            code="early_bird",
            name="Early Bird",
            description="Complete a task before 08:00",
            icon="🌅",
            condition=lambda user, stats: stats.get("early_completion", False),
            category="time",
            persona_relevance=["child", "teen"]
        )

        badges["night_owl"] = BadgeDefinition(
            code="night_owl",
            name="Night Owl",
            description="Complete a task after 20:00",
            icon="🌙",
            condition=lambda user, stats: stats.get("late_completion", False),
            category="time",
            persona_relevance=["teen"]
        )

        # Category-Specific Badges (Specialization)
        badges["cleaning_ace"] = BadgeDefinition(
            code="cleaning_ace",
            name="Cleaning Ace",
            description="Complete 20 cleaning tasks",
            icon="🧹",
            condition=lambda user, stats: stats.get("cleaning_tasks", 0) >= 20,
            category="category",
            persona_relevance=["child", "teen"]
        )

        badges["homework_hero"] = BadgeDefinition(
            code="homework_hero",
            name="Homework Hero",
            description="Complete 20 homework tasks",
            icon="📚",
            condition=lambda user, stats: stats.get("homework_tasks", 0) >= 20,
            category="category",
            persona_relevance=["child", "teen"]
        )

        badges["pet_guardian"] = BadgeDefinition(
            code="pet_guardian",
            name="Pet Guardian",
            description="Complete 20 pet care tasks",
            icon="🐾",
            condition=lambda user, stats: stats.get("pet_tasks", 0) >= 20,
            category="category",
            persona_relevance=["child", "teen"]
        )

        # On-Time Badges (Timeliness rewards)
        badges["punctual_pro"] = BadgeDefinition(
            code="punctual_pro",
            name="Punctual Pro",
            description="Complete 10 tasks before their due date",
            icon="⏰",
            condition=lambda user, stats: stats.get("on_time_tasks", 0) >= 10,
            category="timeliness",
            persona_relevance=["teen", "parent"]
        )

        return badges

    def check_and_award_badges(
        self,
        user_id: str,
        task: Optional[Task],
        db: Session
    ) -> List[Badge]:
        """
        Check if user earned any badges from task completion.

        Args:
            user_id: User ID completing the task
            task: Task that was completed (optional for general checks)
            db: Database session

        Returns:
            List of newly awarded badges
        """
        user = db.query(User).filter_by(id=user_id).first()
        if not user:
            return []

        # Get user statistics
        stats = self._get_user_stats(user_id, task, db)

        # Get already earned badges
        earned_badge_codes = {
            b.code for b in db.query(Badge).filter_by(userId=user_id).all()
        }

        # Check each badge condition
        newly_awarded = []

        for badge_def in self.badges.values():
            # Skip if already earned
            if badge_def.code in earned_badge_codes:
                continue

            # Check if badge is relevant for user's role
            if user.role not in badge_def.persona_relevance:
                continue

            # Evaluate badge condition
            try:
                if badge_def.condition(user, stats):
                    # Award badge
                    badge = Badge(
                        id=str(uuid4()),
                        userId=user_id,
                        code=badge_def.code,
                        awardedAt=datetime.utcnow()
                    )
                    db.add(badge)
                    newly_awarded.append(badge)

                    # Log badge award
                    self._log_badge_event(
                        db=db,
                        user_id=user_id,
                        family_id=user.familyId,
                        badge_code=badge_def.code,
                        badge_name=badge_def.name
                    )
            except Exception as e:
                # Log error but continue checking other badges
                print(f"Error evaluating badge {badge_def.code}: {e}")
                continue

        db.flush()
        return newly_awarded

    def get_user_badges(self, user_id: str, db: Session) -> List[Dict]:
        """
        Return all badges earned by user with metadata.

        Args:
            user_id: User ID
            db: Database session

        Returns:
            List of badge dictionaries with details
        """
        badges = db.query(Badge).filter_by(userId=user_id).order_by(Badge.awardedAt.desc()).all()

        result = []
        for badge in badges:
            badge_def = self.badges.get(badge.code)
            if badge_def:
                result.append({
                    "id": badge.id,
                    "code": badge.code,
                    "name": badge_def.name,
                    "description": badge_def.description,
                    "icon": badge_def.icon,
                    "category": badge_def.category,
                    "awarded_at": badge.awardedAt.isoformat()
                })

        return result

    def get_badge_progress(self, user_id: str, db: Session) -> Dict[str, Dict]:
        """
        Return progress towards unearn badges.

        Args:
            user_id: User ID
            db: Database session

        Returns:
            Dict mapping badge code to progress info
        """
        user = db.query(User).filter_by(id=user_id).first()
        if not user:
            return {}

        # Get user statistics
        stats = self._get_user_stats(user_id, None, db)

        # Get earned badges
        earned_badge_codes = {
            b.code for b in db.query(Badge).filter_by(userId=user_id).all()
        }

        progress = {}

        for badge_def in self.badges.values():
            # Skip earned badges
            if badge_def.code in earned_badge_codes:
                continue

            # Skip irrelevant badges
            if user.role not in badge_def.persona_relevance:
                continue

            # Calculate progress based on badge type
            current = 0
            target = 0

            if badge_def.category == "completion":
                current = stats.get("tasks_completed", 0)
                if "10" in badge_def.code:
                    target = 10
                elif "25" in badge_def.code:
                    target = 25
                elif "50" in badge_def.code:
                    target = 50
                elif "100" in badge_def.code:
                    target = 100
                else:
                    target = 1

            elif badge_def.category == "streak":
                current = stats.get("streak", {}).get("current", 0)
                if "3" in badge_def.code:
                    target = 3
                elif "7" in badge_def.code:
                    target = 7
                elif "14" in badge_def.code:
                    target = 14
                elif "30" in badge_def.code:
                    target = 30

            elif badge_def.category == "quality":
                if "perfectionist" in badge_def.code:
                    current = stats.get("five_star_tasks", 0)
                    target = 10
                elif "first_approval" in badge_def.code:
                    current = stats.get("approved_tasks", 0)
                    target = 1

            elif badge_def.category == "helper":
                current = stats.get("claimed_tasks", 0)
                if "team_player" in badge_def.code:
                    target = 10
                else:
                    target = 1

            elif badge_def.category == "category":
                if "cleaning" in badge_def.code:
                    current = stats.get("cleaning_tasks", 0)
                    target = 20
                elif "homework" in badge_def.code:
                    current = stats.get("homework_tasks", 0)
                    target = 20
                elif "pet" in badge_def.code:
                    current = stats.get("pet_tasks", 0)
                    target = 20

            elif badge_def.category == "timeliness":
                current = stats.get("on_time_tasks", 0)
                target = 10

            if target > 0:
                progress[badge_def.code] = {
                    "name": badge_def.name,
                    "description": badge_def.description,
                    "icon": badge_def.icon,
                    "category": badge_def.category,
                    "current": current,
                    "target": target,
                    "progress": min(current / target, 1.0) if target > 0 else 0
                }

        return progress

    def _get_user_stats(self, user_id: str, task: Optional[Task], db: Session) -> Dict:
        """Calculate user statistics for badge evaluation."""

        stats = {}

        # Total tasks completed
        tasks_completed = db.query(func.count(TaskLog.id)).filter(
            TaskLog.userId == user_id,
            TaskLog.action == "completed"
        ).scalar() or 0
        stats["tasks_completed"] = tasks_completed

        # Streak info
        from services.streak_service import StreakService
        streak_service = StreakService()
        stats["streak"] = streak_service.get_streak_stats(user_id, db)

        # Five-star approvals
        five_star_count = db.query(func.count(TaskLog.id)).filter(
            TaskLog.userId == user_id,
            TaskLog.action == "approved",
            TaskLog.meta["rating"].astext.cast(db.bind.dialect.type_descriptor(db.Integer)) >= 5
        ).scalar() or 0
        stats["five_star_tasks"] = five_star_count

        # Total approved tasks
        approved_count = db.query(func.count(TaskLog.id)).filter(
            TaskLog.userId == user_id,
            TaskLog.action == "approved"
        ).scalar() or 0
        stats["approved_tasks"] = approved_count

        # Claimed tasks from pool
        claimed_count = db.query(func.count(Task.id)).filter(
            Task.claimedBy == user_id,
            Task.status == "done"
        ).scalar() or 0
        stats["claimed_tasks"] = claimed_count

        # Fast completions (speed badges)
        # This would require actual duration vs estimate comparison
        # For now, mark as False unless specific check
        stats["speed_completion"] = False
        stats["fast_completions"] = 0

        # Time-based completions
        stats["early_completion"] = False
        stats["late_completion"] = False

        # Category-specific counts
        cleaning_count = db.query(func.count(TaskLog.id)).join(Task).filter(
            TaskLog.userId == user_id,
            TaskLog.action == "completed",
            Task.category == "cleaning"
        ).scalar() or 0
        stats["cleaning_tasks"] = cleaning_count

        homework_count = db.query(func.count(TaskLog.id)).join(Task).filter(
            TaskLog.userId == user_id,
            TaskLog.action == "completed",
            Task.category == "homework"
        ).scalar() or 0
        stats["homework_tasks"] = homework_count

        pet_count = db.query(func.count(TaskLog.id)).join(Task).filter(
            TaskLog.userId == user_id,
            TaskLog.action == "completed",
            Task.category == "pet"
        ).scalar() or 0
        stats["pet_tasks"] = pet_count

        # On-time tasks
        on_time_count = db.query(func.count(Task.id)).filter(
            Task.completedBy == user_id,
            Task.status == "done",
            Task.completedAt <= Task.due
        ).scalar() or 0
        stats["on_time_tasks"] = on_time_count

        # Task-specific stats (if task provided)
        if task:
            # Speed check
            if hasattr(task, 'completedAt') and hasattr(task, 'createdAt') and task.estDuration:
                actual_duration = (task.completedAt - task.createdAt).total_seconds() / 60
                if actual_duration < task.estDuration * 0.5:
                    stats["speed_completion"] = True

            # Time of day check
            if hasattr(task, 'completedAt') and task.completedAt:
                hour = task.completedAt.hour
                if hour < 8:
                    stats["early_completion"] = True
                elif hour >= 20:
                    stats["late_completion"] = True

        return stats

    def _log_badge_event(
        self,
        db: Session,
        user_id: str,
        family_id: str,
        badge_code: str,
        badge_name: str
    ):
        """Log badge award to audit log."""
        log_entry = AuditLog(
            id=str(uuid4()),
            actorUserId=user_id,
            familyId=family_id,
            action="badge.awarded",
            meta={
                "badge_code": badge_code,
                "badge_name": badge_name,
                "awarded_at": datetime.utcnow().isoformat()
            },
            createdAt=datetime.utcnow()
        )
        db.add(log_entry)
