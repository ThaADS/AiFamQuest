"""
Premium Service
Monetization logic for FamQuest premium features and limits
"""

from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from core.models import User, Family, AIUsageLog
from typing import Dict, Optional

class PremiumService:
    """
    Premium monetization service with limit enforcement.

    Features:
    - Family Unlock: €9.99 one-time (all themes for family)
    - Premium Monthly: €4.99/month (unlimited AI, all themes, priority support)
    - Premium Yearly: €49.99/year (unlimited AI, all themes, priority support, save 20%)
    """

    def __init__(self, db: Session):
        self.db = db

    def check_premium(self, user: User) -> Dict[str, any]:
        """
        Check user's premium status.

        Returns:
        {
            "has_premium": true,
            "has_family_unlock": true,
            "premium_expires": "2026-01-01T00:00:00",
            "premium_plan": "yearly",
            "features": {
                "unlimited_ai": true,
                "all_themes": true,
                "priority_support": true,
                "advanced_analytics": true
            }
        }
        """

        has_premium = False
        has_family_unlock = False
        premium_expires = None
        premium_plan = None

        # Check premium subscription (individual user)
        if user.premiumUntil and user.premiumUntil > datetime.utcnow():
            has_premium = True
            premium_expires = user.premiumUntil.isoformat()
            premium_plan = user.premiumPlan

        # Check family unlock (one-time purchase for entire family)
        family = self.db.query(Family).filter(Family.id == user.familyId).first()
        if family and family.familyUnlock:
            has_family_unlock = True

        return {
            "has_premium": has_premium,
            "has_family_unlock": has_family_unlock,
            "premium_expires": premium_expires,
            "premium_plan": premium_plan,
            "features": {
                "unlimited_ai": has_premium,
                "all_themes": has_premium or has_family_unlock,
                "priority_support": has_premium,
                "advanced_analytics": has_premium,
                "custom_badges": has_premium,
                "export_data": has_premium
            }
        }

    def can_use_ai_planning(self, user: User) -> Dict[str, any]:
        """
        Check if user can use AI planning (rate limited for free users).

        Free: 5 AI planning requests per day
        Premium: Unlimited

        Returns:
        {
            "allowed": true,
            "remaining": 2,
            "limit": 5,
            "resets_at": "2025-11-12T00:00:00"
        }
        """

        status = self.check_premium(user)

        # Premium users have unlimited access
        if status["has_premium"]:
            return {
                "allowed": True,
                "remaining": -1,  # -1 indicates unlimited
                "limit": -1,
                "resets_at": None
            }

        # Free users: 5 per day limit
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        tomorrow_start = today_start + timedelta(days=1)

        ai_count_today = self.db.query(AIUsageLog).filter(
            AIUsageLog.userId == user.id,
            AIUsageLog.createdAt >= today_start,
            AIUsageLog.action.in_(['plan_week', 'generate_tasks', 'study_plan'])
        ).count()

        daily_limit = 5
        remaining = max(0, daily_limit - ai_count_today)

        return {
            "allowed": ai_count_today < daily_limit,
            "remaining": remaining,
            "limit": daily_limit,
            "resets_at": tomorrow_start.isoformat()
        }

    def log_ai_usage(self, user: User, action: str, metadata: Optional[Dict] = None):
        """
        Log AI usage for rate limiting and analytics.

        Args:
            user: User object
            action: 'plan_week' | 'generate_tasks' | 'study_plan'
            metadata: Optional metadata (e.g., tasks_generated, model, tokens)
        """

        usage_log = AIUsageLog(
            userId=user.id,
            action=action,
            metadata=metadata or {}
        )

        self.db.add(usage_log)
        self.db.commit()

    def can_use_theme(self, user: User, theme: str) -> bool:
        """
        Check if user can use a specific theme.

        Free: 'minimal', 'cartoony' (2 basic themes)
        Family Unlock: All 8 themes
        Premium: All 8 themes
        """

        free_themes = {'minimal', 'cartoony'}

        # Free themes always allowed
        if theme in free_themes:
            return True

        # Check premium or family unlock
        status = self.check_premium(user)
        return status["has_premium"] or status["has_family_unlock"]

    def activate_premium(
        self,
        user: User,
        plan: str,  # 'monthly', 'yearly', 'family_unlock'
        payment_id: str
    ):
        """
        Activate premium after successful payment.

        Args:
            user: User object
            plan: 'monthly', 'yearly', or 'family_unlock'
            payment_id: Stripe payment/subscription ID
        """

        if plan == 'family_unlock':
            # One-time purchase for entire family
            family = self.db.query(Family).filter(Family.id == user.familyId).first()
            if not family:
                raise ValueError("User's family not found")

            family.familyUnlock = True
            family.familyUnlockPurchasedAt = datetime.utcnow()
            family.familyUnlockPurchasedById = user.id

        elif plan == 'monthly':
            # Monthly subscription (€4.99/month)
            user.premiumUntil = datetime.utcnow() + timedelta(days=30)
            user.premiumPlan = 'monthly'
            user.premiumPaymentId = payment_id

        elif plan == 'yearly':
            # Yearly subscription (€49.99/year)
            user.premiumUntil = datetime.utcnow() + timedelta(days=365)
            user.premiumPlan = 'yearly'
            user.premiumPaymentId = payment_id

        else:
            raise ValueError(f"Invalid plan: {plan}")

        self.db.commit()

    def cancel_premium(self, user: User):
        """
        Cancel premium subscription (user keeps access until expiry).

        Args:
            user: User object
        """

        # Keep premiumUntil so user has access until expiry
        # Just clear payment ID to prevent renewal
        user.premiumPaymentId = None
        self.db.commit()

    def renew_premium(self, user: User):
        """
        Renew premium subscription (called by Stripe webhook).

        Args:
            user: User object
        """

        if not user.premiumPlan:
            raise ValueError("User has no premium plan to renew")

        if user.premiumPlan == 'monthly':
            # Extend by 30 days
            if user.premiumUntil and user.premiumUntil > datetime.utcnow():
                # Still active, extend from current expiry
                user.premiumUntil = user.premiumUntil + timedelta(days=30)
            else:
                # Expired, extend from now
                user.premiumUntil = datetime.utcnow() + timedelta(days=30)

        elif user.premiumPlan == 'yearly':
            # Extend by 365 days
            if user.premiumUntil and user.premiumUntil > datetime.utcnow():
                user.premiumUntil = user.premiumUntil + timedelta(days=365)
            else:
                user.premiumUntil = datetime.utcnow() + timedelta(days=365)

        self.db.commit()

    def get_pricing(self) -> Dict[str, any]:
        """
        Get pricing information.

        Returns:
        {
            "family_unlock": {"price": 9.99, "currency": "EUR", "type": "one_time"},
            "premium_monthly": {"price": 4.99, "currency": "EUR", "type": "subscription"},
            "premium_yearly": {"price": 49.99, "currency": "EUR", "type": "subscription", "save": "20%"}
        }
        """

        return {
            "family_unlock": {
                "price": 9.99,
                "currency": "EUR",
                "type": "one_time",
                "description": "Unlock all 8 themes for your entire family"
            },
            "premium_monthly": {
                "price": 4.99,
                "currency": "EUR",
                "type": "subscription",
                "billing_period": "monthly",
                "description": "Unlimited AI planning, all themes, priority support"
            },
            "premium_yearly": {
                "price": 49.99,
                "currency": "EUR",
                "type": "subscription",
                "billing_period": "yearly",
                "save_percentage": "20%",
                "description": "Unlimited AI planning, all themes, priority support (save 20%)"
            }
        }
