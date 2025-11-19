"""
Test Premium Monetization System
Tests PremiumService, premium limits, and Stripe integration
"""

import pytest
from datetime import datetime, timedelta
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from core.db import Base
from core.models import User, Family, AIUsageLog
from services.premium_service import PremiumService
from uuid import uuid4


@pytest.fixture
def db_session():
    """Create test database session"""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    yield session

    session.close()


@pytest.fixture
def test_family(db_session):
    """Create test family"""
    family = Family(
        id=str(uuid4()),
        name="Test Family"
    )
    db_session.add(family)
    db_session.commit()
    return family


@pytest.fixture
def test_user(db_session, test_family):
    """Create test user"""
    user = User(
        id=str(uuid4()),
        familyId=test_family.id,
        email="test@famquest.app",
        displayName="Test User",
        role="parent"
    )
    db_session.add(user)
    db_session.commit()
    return user


class TestPremiumService:
    """Test PremiumService functionality"""

    def test_check_premium_free_user(self, db_session, test_user):
        """Test premium status for free user"""
        service = PremiumService(db_session)
        status = service.check_premium(test_user)

        assert status["has_premium"] is False
        assert status["has_family_unlock"] is False
        assert status["premium_expires"] is None
        assert status["features"]["unlimited_ai"] is False
        assert status["features"]["all_themes"] is False

    def test_check_premium_with_subscription(self, db_session, test_user):
        """Test premium status with active subscription"""
        # Set premium until tomorrow
        test_user.premiumUntil = datetime.utcnow() + timedelta(days=1)
        test_user.premiumPlan = 'monthly'
        db_session.commit()

        service = PremiumService(db_session)
        status = service.check_premium(test_user)

        assert status["has_premium"] is True
        assert status["premium_plan"] == 'monthly'
        assert status["features"]["unlimited_ai"] is True
        assert status["features"]["all_themes"] is True
        assert status["features"]["priority_support"] is True

    def test_check_premium_with_expired_subscription(self, db_session, test_user):
        """Test premium status with expired subscription"""
        # Set premium until yesterday
        test_user.premiumUntil = datetime.utcnow() - timedelta(days=1)
        test_user.premiumPlan = 'yearly'
        db_session.commit()

        service = PremiumService(db_session)
        status = service.check_premium(test_user)

        assert status["has_premium"] is False
        assert status["features"]["unlimited_ai"] is False

    def test_check_premium_with_family_unlock(self, db_session, test_user, test_family):
        """Test premium status with family unlock"""
        # Enable family unlock
        test_family.familyUnlock = True
        test_family.familyUnlockPurchasedAt = datetime.utcnow()
        test_family.familyUnlockPurchasedById = test_user.id
        db_session.commit()

        service = PremiumService(db_session)
        status = service.check_premium(test_user)

        assert status["has_family_unlock"] is True
        assert status["features"]["all_themes"] is True  # Family unlock unlocks themes
        assert status["features"]["unlimited_ai"] is False  # But not AI

    def test_can_use_ai_planning_free_user_no_usage(self, db_session, test_user):
        """Test AI planning for free user with no usage"""
        service = PremiumService(db_session)
        limits = service.can_use_ai_planning(test_user)

        assert limits["allowed"] is True
        assert limits["remaining"] == 5
        assert limits["limit"] == 5
        assert limits["resets_at"] is not None

    def test_can_use_ai_planning_free_user_with_usage(self, db_session, test_user):
        """Test AI planning for free user with some usage"""
        # Add 3 AI usage logs today
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

        for i in range(3):
            log = AIUsageLog(
                userId=test_user.id,
                action='plan_week',
                createdAt=today_start + timedelta(hours=i)
            )
            db_session.add(log)
        db_session.commit()

        service = PremiumService(db_session)
        limits = service.can_use_ai_planning(test_user)

        assert limits["allowed"] is True
        assert limits["remaining"] == 2
        assert limits["limit"] == 5

    def test_can_use_ai_planning_free_user_limit_reached(self, db_session, test_user):
        """Test AI planning for free user at limit"""
        # Add 5 AI usage logs today
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

        for i in range(5):
            log = AIUsageLog(
                userId=test_user.id,
                action='plan_week',
                createdAt=today_start + timedelta(hours=i)
            )
            db_session.add(log)
        db_session.commit()

        service = PremiumService(db_session)
        limits = service.can_use_ai_planning(test_user)

        assert limits["allowed"] is False
        assert limits["remaining"] == 0
        assert limits["limit"] == 5

    def test_can_use_ai_planning_premium_user(self, db_session, test_user):
        """Test AI planning for premium user (unlimited)"""
        # Set premium
        test_user.premiumUntil = datetime.utcnow() + timedelta(days=30)
        test_user.premiumPlan = 'monthly'
        db_session.commit()

        service = PremiumService(db_session)
        limits = service.can_use_ai_planning(test_user)

        assert limits["allowed"] is True
        assert limits["remaining"] == -1  # -1 indicates unlimited
        assert limits["limit"] == -1

    def test_log_ai_usage(self, db_session, test_user):
        """Test logging AI usage"""
        service = PremiumService(db_session)

        service.log_ai_usage(
            test_user,
            action='plan_week',
            metadata={'total_tasks': 28, 'cost': 0.003}
        )

        # Check log was created
        logs = db_session.query(AIUsageLog).filter(
            AIUsageLog.userId == test_user.id
        ).all()

        assert len(logs) == 1
        assert logs[0].action == 'plan_week'
        assert logs[0].meta['total_tasks'] == 28

    def test_can_use_theme_free_user(self, db_session, test_user):
        """Test theme access for free user"""
        service = PremiumService(db_session)

        # Free themes allowed
        assert service.can_use_theme(test_user, 'minimal') is True
        assert service.can_use_theme(test_user, 'cartoony') is True

        # Premium themes not allowed
        assert service.can_use_theme(test_user, 'classy') is False
        assert service.can_use_theme(test_user, 'dark') is False

    def test_can_use_theme_with_family_unlock(self, db_session, test_user, test_family):
        """Test theme access with family unlock"""
        # Enable family unlock
        test_family.familyUnlock = True
        db_session.commit()

        service = PremiumService(db_session)

        # All themes allowed with family unlock
        assert service.can_use_theme(test_user, 'minimal') is True
        assert service.can_use_theme(test_user, 'classy') is True
        assert service.can_use_theme(test_user, 'dark') is True

    def test_can_use_theme_with_premium(self, db_session, test_user):
        """Test theme access with premium subscription"""
        test_user.premiumUntil = datetime.utcnow() + timedelta(days=30)
        test_user.premiumPlan = 'monthly'
        db_session.commit()

        service = PremiumService(db_session)

        # All themes allowed with premium
        assert service.can_use_theme(test_user, 'minimal') is True
        assert service.can_use_theme(test_user, 'classy') is True
        assert service.can_use_theme(test_user, 'dark') is True

    def test_activate_premium_family_unlock(self, db_session, test_user, test_family):
        """Test activating family unlock"""
        service = PremiumService(db_session)

        service.activate_premium(test_user, 'family_unlock', 'pi_test123')

        db_session.refresh(test_family)

        assert test_family.familyUnlock is True
        assert test_family.familyUnlockPurchasedById == test_user.id
        assert test_family.familyUnlockPurchasedAt is not None

    def test_activate_premium_monthly(self, db_session, test_user):
        """Test activating monthly premium"""
        service = PremiumService(db_session)

        service.activate_premium(test_user, 'monthly', 'sub_test123')

        db_session.refresh(test_user)

        assert test_user.premiumUntil is not None
        assert test_user.premiumPlan == 'monthly'
        assert test_user.premiumPaymentId == 'sub_test123'

        # Check expiry is ~30 days from now
        days_until_expiry = (test_user.premiumUntil - datetime.utcnow()).days
        assert 29 <= days_until_expiry <= 31

    def test_activate_premium_yearly(self, db_session, test_user):
        """Test activating yearly premium"""
        service = PremiumService(db_session)

        service.activate_premium(test_user, 'yearly', 'sub_test456')

        db_session.refresh(test_user)

        assert test_user.premiumUntil is not None
        assert test_user.premiumPlan == 'yearly'

        # Check expiry is ~365 days from now
        days_until_expiry = (test_user.premiumUntil - datetime.utcnow()).days
        assert 364 <= days_until_expiry <= 366

    def test_cancel_premium(self, db_session, test_user):
        """Test cancelling premium subscription"""
        # Set up premium
        test_user.premiumUntil = datetime.utcnow() + timedelta(days=30)
        test_user.premiumPlan = 'monthly'
        test_user.premiumPaymentId = 'sub_test123'
        db_session.commit()

        service = PremiumService(db_session)
        service.cancel_premium(test_user)

        db_session.refresh(test_user)

        # premiumUntil kept (user has access until expiry)
        assert test_user.premiumUntil is not None
        # Payment ID cleared (no renewal)
        assert test_user.premiumPaymentId is None

    def test_renew_premium_monthly(self, db_session, test_user):
        """Test renewing monthly premium"""
        # Set up expiring premium
        test_user.premiumUntil = datetime.utcnow() + timedelta(days=5)
        test_user.premiumPlan = 'monthly'
        db_session.commit()

        service = PremiumService(db_session)
        service.renew_premium(test_user)

        db_session.refresh(test_user)

        # Check extended by 30 days
        days_until_expiry = (test_user.premiumUntil - datetime.utcnow()).days
        assert 34 <= days_until_expiry <= 36  # Original 5 + 30 days

    def test_renew_premium_yearly(self, db_session, test_user):
        """Test renewing yearly premium"""
        # Set up expiring premium
        test_user.premiumUntil = datetime.utcnow() + timedelta(days=10)
        test_user.premiumPlan = 'yearly'
        db_session.commit()

        service = PremiumService(db_session)
        service.renew_premium(test_user)

        db_session.refresh(test_user)

        # Check extended by 365 days
        days_until_expiry = (test_user.premiumUntil - datetime.utcnow()).days
        assert 374 <= days_until_expiry <= 376  # Original 10 + 365 days

    def test_get_pricing(self, db_session):
        """Test getting pricing information"""
        service = PremiumService(db_session)
        pricing = service.get_pricing()

        assert pricing["family_unlock"]["price"] == 9.99
        assert pricing["family_unlock"]["currency"] == "EUR"
        assert pricing["family_unlock"]["type"] == "one_time"

        assert pricing["premium_monthly"]["price"] == 4.99
        assert pricing["premium_monthly"]["billing_period"] == "monthly"

        assert pricing["premium_yearly"]["price"] == 49.99
        assert pricing["premium_yearly"]["save_percentage"] == "20%"
