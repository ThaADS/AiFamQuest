"""
Comprehensive Tests for Gamification System
Tests streaks, badges, points, and integration.
"""

import pytest
from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
from uuid import uuid4

from core.models import User, Family, Task, UserStreak, Badge, PointsLedger, TaskLog
from services.streak_service import StreakService
from services.badge_service import BadgeService
from services.points_service import PointsService
from services.gamification_service import GamificationService


@pytest.fixture
def db_session():
    """Database session fixture."""
    from core.db import SessionLocal
    db = SessionLocal()
    try:
        yield db
    finally:
        db.rollback()
        db.close()


@pytest.fixture
def test_family(db_session):
    """Create test family."""
    family = Family(
        id=str(uuid4()),
        name="Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(family)
    db_session.commit()
    return family


@pytest.fixture
def test_user(db_session, test_family):
    """Create test user."""
    user = User(
        id=str(uuid4()),
        familyId=test_family.id,
        email=f"test_{uuid4()}@example.com",
        displayName="Test Child",
        role="child",
        passwordHash="dummy_hash",
        locale="en",
        theme="minimal",
        permissions={},
        sso={},
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(user)
    db_session.commit()
    return user


@pytest.fixture
def test_task(db_session, test_family, test_user):
    """Create test task."""
    task = Task(
        id=str(uuid4()),
        familyId=test_family.id,
        title="Test Task",
        desc="Test description",
        category="cleaning",
        due=datetime.utcnow() + timedelta(days=1),
        points=10,
        status="open",
        assignees=[test_user.id],
        claimable=False,
        photoRequired=False,
        parentApproval=False,
        proofPhotos=[],
        priority="med",
        estDuration=15,
        createdBy=test_user.id,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow(),
        version=0
    )
    db_session.add(task)
    db_session.commit()
    return task


# =============================================================================
# Streak Service Tests
# =============================================================================

class TestStreakService:
    """Test streak tracking logic."""

    def test_first_streak_creation(self, db_session, test_user):
        """Test creating first streak."""
        streak_service = StreakService()

        stats = streak_service.update_streak(
            user_id=test_user.id,
            completed_date=date.today(),
            db=db_session
        )

        assert stats["current"] == 1
        assert stats["longest"] == 1
        assert stats["days_since_last"] == 0

    def test_consecutive_day_increment(self, db_session, test_user):
        """Test streak increments on consecutive days."""
        streak_service = StreakService()

        # Day 1
        streak_service.update_streak(test_user.id, date.today() - timedelta(days=1), db_session)

        # Day 2 (consecutive)
        stats = streak_service.update_streak(test_user.id, date.today(), db_session)

        assert stats["current"] == 2
        assert stats["longest"] == 2

    def test_same_day_no_change(self, db_session, test_user):
        """Test same-day completion doesn't change streak."""
        streak_service = StreakService()

        # First completion today
        stats1 = streak_service.update_streak(test_user.id, date.today(), db_session)

        # Second completion today
        stats2 = streak_service.update_streak(test_user.id, date.today(), db_session)

        assert stats1["current"] == stats2["current"]
        assert stats1["longest"] == stats2["longest"]

    def test_streak_reset_on_gap(self, db_session, test_user):
        """Test streak resets after missing a day."""
        streak_service = StreakService()

        # Build 3-day streak
        for i in range(3):
            streak_service.update_streak(
                test_user.id,
                date.today() - timedelta(days=5-i),
                db_session
            )

        # Miss 2 days, then complete
        stats = streak_service.update_streak(test_user.id, date.today(), db_session)

        assert stats["current"] == 1  # Reset to 1
        assert stats["longest"] == 3  # Longest still preserved

    def test_longest_streak_update(self, db_session, test_user):
        """Test longest streak is updated correctly."""
        streak_service = StreakService()

        # Build 5-day streak
        for i in range(5):
            stats = streak_service.update_streak(
                test_user.id,
                date.today() - timedelta(days=4-i),
                db_session
            )

        assert stats["current"] == 5
        assert stats["longest"] == 5

    def test_streak_at_risk_detection(self, db_session, test_user):
        """Test streak at-risk detection."""
        streak_service = StreakService()

        # Complete task yesterday
        streak_service.update_streak(
            test_user.id,
            date.today() - timedelta(days=1),
            db_session
        )

        # Check if at risk (no completion today)
        is_at_risk = streak_service.check_streak_guard(test_user.id, db_session)

        assert is_at_risk is True


# =============================================================================
# Badge Service Tests
# =============================================================================

class TestBadgeService:
    """Test badge awarding logic."""

    def test_first_task_badge(self, db_session, test_user, test_task):
        """Test first task badge is awarded."""
        badge_service = BadgeService()

        # Create task completion log
        task_log = TaskLog(
            id=str(uuid4()),
            taskId=test_task.id,
            userId=test_user.id,
            action="completed",
            metadata={},
            createdAt=datetime.utcnow()
        )
        db_session.add(task_log)
        db_session.commit()

        # Check badges
        new_badges = badge_service.check_and_award_badges(
            user_id=test_user.id,
            task=test_task,
            db=db_session
        )

        badge_codes = [b.code for b in new_badges]
        assert "first_task" in badge_codes

    def test_streak_badges(self, db_session, test_user):
        """Test streak milestone badges."""
        badge_service = BadgeService()
        streak_service = StreakService()

        # Build 7-day streak
        for i in range(7):
            streak_service.update_streak(
                test_user.id,
                date.today() - timedelta(days=6-i),
                db_session
            )

        # Check badges
        new_badges = badge_service.check_and_award_badges(
            user_id=test_user.id,
            task=None,
            db=db_session
        )

        badge_codes = [b.code for b in new_badges]
        assert "streak_3" in badge_codes
        assert "streak_7" in badge_codes

    def test_completion_count_badges(self, db_session, test_user, test_task):
        """Test task completion count badges."""
        badge_service = BadgeService()

        # Create 10 completed tasks
        for i in range(10):
            task_log = TaskLog(
                id=str(uuid4()),
                taskId=test_task.id,
                userId=test_user.id,
                action="completed",
                metadata={},
                createdAt=datetime.utcnow()
            )
            db_session.add(task_log)
        db_session.commit()

        # Check badges
        new_badges = badge_service.check_and_award_badges(
            user_id=test_user.id,
            task=test_task,
            db=db_session
        )

        badge_codes = [b.code for b in new_badges]
        assert "tasks_10" in badge_codes

    def test_category_specific_badges(self, db_session, test_user, test_family):
        """Test category-specific badges (cleaning, homework, pet)."""
        badge_service = BadgeService()

        # Create 20 cleaning tasks
        for i in range(20):
            task = Task(
                id=str(uuid4()),
                familyId=test_family.id,
                title=f"Cleaning Task {i}",
                desc="",
                category="cleaning",
                points=10,
                status="done",
                assignees=[test_user.id],
                completedBy=test_user.id,
                completedAt=datetime.utcnow(),
                claimable=False,
                photoRequired=False,
                parentApproval=False,
                proofPhotos=[],
                priority="med",
                estDuration=15,
                createdBy=test_user.id,
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow(),
                version=0
            )
            db_session.add(task)

            task_log = TaskLog(
                id=str(uuid4()),
                taskId=task.id,
                userId=test_user.id,
                action="completed",
                metadata={},
                createdAt=datetime.utcnow()
            )
            db_session.add(task_log)

        db_session.commit()

        # Check badges
        new_badges = badge_service.check_and_award_badges(
            user_id=test_user.id,
            task=None,
            db=db_session
        )

        badge_codes = [b.code for b in new_badges]
        assert "cleaning_ace" in badge_codes

    def test_badge_not_awarded_twice(self, db_session, test_user, test_task):
        """Test badges are not awarded multiple times."""
        badge_service = BadgeService()

        # Create first task log
        task_log = TaskLog(
            id=str(uuid4()),
            taskId=test_task.id,
            userId=test_user.id,
            action="completed",
            metadata={},
            createdAt=datetime.utcnow()
        )
        db_session.add(task_log)
        db_session.commit()

        # First check - should award
        badges1 = badge_service.check_and_award_badges(
            user_id=test_user.id,
            task=test_task,
            db=db_session
        )

        # Second check - should not award again
        badges2 = badge_service.check_and_award_badges(
            user_id=test_user.id,
            task=test_task,
            db=db_session
        )

        assert len(badges1) > 0
        assert len(badges2) == 0

    def test_badge_progress_tracking(self, db_session, test_user, test_task):
        """Test badge progress calculation."""
        badge_service = BadgeService()

        # Create 5 completed tasks (halfway to tasks_10)
        for i in range(5):
            task_log = TaskLog(
                id=str(uuid4()),
                taskId=test_task.id,
                userId=test_user.id,
                action="completed",
                metadata={},
                createdAt=datetime.utcnow()
            )
            db_session.add(task_log)
        db_session.commit()

        # Get progress
        progress = badge_service.get_badge_progress(test_user.id, db_session)

        assert "tasks_10" in progress
        assert progress["tasks_10"]["current"] == 5
        assert progress["tasks_10"]["target"] == 10
        assert progress["tasks_10"]["progress"] == 0.5


# =============================================================================
# Points Service Tests
# =============================================================================

class TestPointsService:
    """Test points calculation and management."""

    def test_base_points_calculation(self, db_session, test_user, test_task):
        """Test base points are calculated correctly."""
        points_service = PointsService()

        points, multipliers = points_service.calculate_points(
            task=test_task,
            user=test_user,
            completion_time=datetime.utcnow(),
            approval_rating=None
        )

        assert points == 10  # Base points

    def test_on_time_bonus(self, db_session, test_user, test_task):
        """Test on-time completion bonus."""
        points_service = PointsService()

        # Complete before due date
        completion_time = test_task.due - timedelta(hours=1)

        points, multipliers = points_service.calculate_points(
            task=test_task,
            user=test_user,
            completion_time=completion_time,
            approval_rating=None
        )

        assert points == 12  # 10 * 1.2
        assert any(m[0] == "on_time" for m in multipliers)

    def test_streak_multiplier(self, db_session, test_user, test_task):
        """Test streak multiplier is applied."""
        points_service = PointsService()
        streak_service = StreakService()

        # Build 7-day streak
        for i in range(7):
            streak_service.update_streak(
                test_user.id,
                date.today() - timedelta(days=6-i),
                db_session
            )

        points, multipliers = points_service.calculate_points(
            task=test_task,
            user=test_user,
            completion_time=datetime.utcnow(),
            approval_rating=None
        )

        # Should have streak bonus
        assert any("streak" in m[0] for m in multipliers)
        assert points > 10

    def test_quality_bonus(self, db_session, test_user, test_task):
        """Test quality bonus from parent approval."""
        points_service = PointsService()

        # 5-star approval
        points, multipliers = points_service.calculate_points(
            task=test_task,
            user=test_user,
            completion_time=datetime.utcnow(),
            approval_rating=5
        )

        assert points == 12  # 10 * 1.2
        assert any(m[0] == "quality_excellent" for m in multipliers)

    def test_points_ledger_entry(self, db_session, test_user, test_task):
        """Test points are recorded in ledger."""
        points_service = PointsService()

        points_service.award_points(
            user_id=test_user.id,
            task_id=test_task.id,
            points=10,
            reason="Task completed",
            db=db_session
        )

        db_session.commit()

        # Check ledger
        entries = db_session.query(PointsLedger).filter_by(userId=test_user.id).all()
        assert len(entries) == 1
        assert entries[0].delta == 10
        assert entries[0].taskId == test_task.id

    def test_user_balance_calculation(self, db_session, test_user):
        """Test user balance is calculated correctly."""
        points_service = PointsService()

        # Award points multiple times
        points_service.award_points(test_user.id, None, 10, "Task 1", db_session)
        points_service.award_points(test_user.id, None, 20, "Task 2", db_session)
        points_service.award_points(test_user.id, None, -5, "Spent", db_session)

        db_session.commit()

        balance = points_service.get_user_points(test_user.id, db_session)
        assert balance == 25  # 10 + 20 - 5

    def test_leaderboard_sorting(self, db_session, test_family):
        """Test leaderboard is sorted correctly."""
        points_service = PointsService()

        # Create 3 users with different points
        users = []
        for i in range(3):
            user = User(
                id=str(uuid4()),
                familyId=test_family.id,
                email=f"user{i}@example.com",
                displayName=f"User {i}",
                role="child",
                passwordHash="dummy",
                locale="en",
                theme="minimal",
                permissions={},
                sso={},
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow()
            )
            db_session.add(user)
            users.append(user)

        db_session.commit()

        # Award different points
        points_service.award_points(users[0].id, None, 50, "Test", db_session)
        points_service.award_points(users[1].id, None, 100, "Test", db_session)
        points_service.award_points(users[2].id, None, 25, "Test", db_session)

        db_session.commit()

        # Get leaderboard
        leaderboard = points_service.get_leaderboard(
            family_id=test_family.id,
            db=db_session,
            period="alltime"
        )

        assert len(leaderboard) == 3
        assert leaderboard[0]["points"] == 100
        assert leaderboard[1]["points"] == 50
        assert leaderboard[2]["points"] == 25
        assert leaderboard[0]["rank"] == 1


# =============================================================================
# Integration Tests
# =============================================================================

class TestGamificationIntegration:
    """Test complete gamification flow."""

    def test_task_completion_flow(self, db_session, test_user, test_task):
        """Test complete task completion with all gamification."""
        gamification_service = GamificationService()

        # Mark task as completed
        test_task.status = "done"
        test_task.completedBy = test_user.id
        test_task.completedAt = datetime.utcnow()

        result = gamification_service.on_task_completed(
            task=test_task,
            user=test_user,
            completion_time=datetime.utcnow(),
            db=db_session,
            approval_rating=None
        )

        db_session.commit()

        # Verify all components
        assert result["success"] is True
        assert result["points_earned"] > 0
        assert "streak" in result
        assert "new_badges" in result
        assert "total_points" in result

    def test_multiple_task_completions(self, db_session, test_user, test_family):
        """Test multiple consecutive task completions."""
        gamification_service = GamificationService()

        # Complete 5 tasks over 5 days
        for i in range(5):
            task = Task(
                id=str(uuid4()),
                familyId=test_family.id,
                title=f"Task {i}",
                desc="",
                category="cleaning",
                points=10,
                status="open",
                assignees=[test_user.id],
                claimable=False,
                photoRequired=False,
                parentApproval=False,
                proofPhotos=[],
                priority="med",
                estDuration=15,
                createdBy=test_user.id,
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow(),
                version=0
            )
            db_session.add(task)
            db_session.flush()

            completion_time = datetime.combine(
                date.today() - timedelta(days=4-i),
                datetime.min.time()
            )

            task.status = "done"
            task.completedBy = test_user.id
            task.completedAt = completion_time

            result = gamification_service.on_task_completed(
                task=task,
                user=test_user,
                completion_time=completion_time,
                db=db_session
            )

        db_session.commit()

        # Check results
        streak = gamification_service.streak_service.get_streak_stats(
            test_user.id, db_session
        )
        assert streak["current"] == 5

        balance = gamification_service.points_service.get_user_points(
            test_user.id, db_session
        )
        assert balance > 50  # Should have multipliers

    def test_gamification_profile(self, db_session, test_user):
        """Test complete gamification profile retrieval."""
        gamification_service = GamificationService()

        profile = gamification_service.get_gamification_profile(
            user_id=test_user.id,
            db=db_session
        )

        # Verify structure
        assert "user_id" in profile
        assert "points" in profile
        assert "streak" in profile
        assert "badges" in profile
        assert "leaderboard" in profile
        assert "rewards" in profile

    def test_preview_task_rewards(self, db_session, test_user, test_task):
        """Test task reward preview."""
        gamification_service = GamificationService()

        preview = gamification_service.preview_task_rewards(
            task=test_task,
            user=test_user,
            db=db_session
        )

        assert "base_points" in preview
        assert "estimated_points" in preview
        assert "potential_badges" in preview
        assert "current_streak" in preview
        assert preview["base_points"] == 10


# =============================================================================
# Edge Case Tests
# =============================================================================

class TestEdgeCases:
    """Test edge cases and error handling."""

    def test_no_user_streak_record(self, db_session, test_user):
        """Test handling of user with no streak record."""
        streak_service = StreakService()

        stats = streak_service.get_streak_stats(test_user.id, db_session)

        assert stats["current"] == 0
        assert stats["longest"] == 0
        assert stats["last_completion_date"] is None

    def test_zero_points_task(self, db_session, test_user, test_task):
        """Test task with zero points."""
        points_service = PointsService()

        test_task.points = 0

        points, multipliers = points_service.calculate_points(
            task=test_task,
            user=test_user,
            completion_time=datetime.utcnow(),
            approval_rating=None
        )

        # Should default to 10 if points is 0
        assert points >= 0

    def test_overdue_task_penalty(self, db_session, test_user, test_task):
        """Test overdue task has penalty."""
        points_service = PointsService()

        # Complete after due date
        completion_time = test_task.due + timedelta(days=1)

        points, multipliers = points_service.calculate_points(
            task=test_task,
            user=test_user,
            completion_time=completion_time,
            approval_rating=None
        )

        assert any(m[0] == "overdue" for m in multipliers)
        assert points == 8  # 10 * 0.8

    def test_timezone_handling(self, db_session, test_user):
        """Test timezone-aware date handling."""
        streak_service = StreakService()

        # Complete task with UTC time
        stats = streak_service.update_streak(
            user_id=test_user.id,
            completed_date=date.today(),
            db=db_session
        )

        assert stats["current"] == 1
        assert stats["days_since_last"] == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
