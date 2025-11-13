"""
Premium Router
Stripe integration for FamQuest monetization
"""

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from core.db import SessionLocal
from core.models import User
from routers.auth import get_current_user
from services.premium_service import PremiumService
from pydantic import BaseModel
from typing import Optional
import stripe
import os

router = APIRouter(prefix="/premium", tags=["premium"])

# Initialize Stripe
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

def db():
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


# Pydantic schemas
class CheckoutRequest(BaseModel):
    plan: str  # 'monthly', 'yearly', 'family_unlock'


class PremiumStatusResponse(BaseModel):
    has_premium: bool
    has_family_unlock: bool
    premium_expires: Optional[str]
    premium_plan: Optional[str]
    features: dict


class AILimitResponse(BaseModel):
    allowed: bool
    remaining: int
    limit: int
    resets_at: Optional[str]


@router.get("/status", response_model=PremiumStatusResponse)
async def get_premium_status(
    d: Session = Depends(db),
    current_user: User = Depends(get_current_user)
):
    """
    Get user's premium status.

    Returns:
    {
        "has_premium": true,
        "has_family_unlock": false,
        "premium_expires": "2026-01-01T00:00:00",
        "premium_plan": "yearly",
        "features": {
            "unlimited_ai": true,
            "all_themes": true,
            ...
        }
    }
    """

    service = PremiumService(d)
    status = service.check_premium(current_user)

    return PremiumStatusResponse(**status)


@router.get("/ai-limits", response_model=AILimitResponse)
async def get_ai_limits(
    d: Session = Depends(db),
    current_user: User = Depends(get_current_user)
):
    """
    Get AI planning usage limits.

    Returns:
    {
        "allowed": true,
        "remaining": 2,
        "limit": 5,
        "resets_at": "2025-11-12T00:00:00"
    }
    """

    service = PremiumService(d)
    limits = service.can_use_ai_planning(current_user)

    return AILimitResponse(**limits)


@router.get("/pricing")
async def get_pricing():
    """
    Get pricing information.

    Returns:
    {
        "family_unlock": {"price": 9.99, "currency": "EUR", ...},
        "premium_monthly": {"price": 4.99, "currency": "EUR", ...},
        "premium_yearly": {"price": 49.99, "currency": "EUR", ...}
    }
    """

    service = PremiumService(None)  # No DB needed for static pricing
    return service.get_pricing()


@router.post("/checkout")
async def create_checkout_session(
    req: CheckoutRequest,
    d: Session = Depends(db),
    current_user: User = Depends(get_current_user)
):
    """
    Create Stripe checkout session.

    Request:
    {
        "plan": "family_unlock" | "monthly" | "yearly"
    }

    Returns:
    {
        "checkout_url": "https://checkout.stripe.com/...",
        "session_id": "cs_..."
    }
    """

    # Validate plan
    valid_plans = {'family_unlock', 'monthly', 'yearly'}
    if req.plan not in valid_plans:
        raise HTTPException(400, f"Invalid plan: {req.plan}. Must be one of: {', '.join(valid_plans)}")

    # Get Stripe price IDs from environment
    price_ids = {
        'family_unlock': os.getenv("STRIPE_PRICE_FAMILY_UNLOCK"),
        'monthly': os.getenv("STRIPE_PRICE_MONTHLY"),
        'yearly': os.getenv("STRIPE_PRICE_YEARLY")
    }

    price_id = price_ids.get(req.plan)
    if not price_id:
        raise HTTPException(500, f"Stripe price ID not configured for plan: {req.plan}")

    try:
        # Create checkout session
        checkout_session = stripe.checkout.Session.create(
            customer_email=current_user.email,
            payment_method_types=['card', 'ideal', 'sepa_debit'],  # European payment methods
            line_items=[{
                'price': price_id,
                'quantity': 1
            }],
            mode='payment' if req.plan == 'family_unlock' else 'subscription',
            success_url=f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/premium/success?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{os.getenv('FRONTEND_URL', 'http://localhost:3000')}/premium",
            metadata={
                'user_id': str(current_user.id),
                'plan': req.plan
            }
        )

        return {
            "checkout_url": checkout_session.url,
            "session_id": checkout_session.id
        }

    except stripe.error.StripeError as e:
        raise HTTPException(500, f"Stripe error: {str(e)}")


@router.post("/webhook")
async def stripe_webhook(
    request: Request,
    d: Session = Depends(db)
):
    """
    Handle Stripe webhook events.

    Events:
    - checkout.session.completed: Payment successful
    - customer.subscription.updated: Subscription renewed
    - customer.subscription.deleted: Subscription cancelled
    """

    payload = await request.body()
    sig_header = request.headers.get('stripe-signature')

    # Get webhook secret
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    if not webhook_secret:
        raise HTTPException(500, "Stripe webhook secret not configured")

    try:
        # Verify webhook signature
        event = stripe.Webhook.construct_event(
            payload, sig_header, webhook_secret
        )
    except ValueError as e:
        # Invalid payload
        raise HTTPException(400, f"Invalid payload: {str(e)}")
    except stripe.error.SignatureVerificationError as e:
        # Invalid signature
        raise HTTPException(400, f"Invalid signature: {str(e)}")

    # Handle event
    event_type = event['type']
    data = event['data']['object']

    service = PremiumService(d)

    if event_type == 'checkout.session.completed':
        # Payment successful - activate premium
        session = data
        user_id = session['metadata']['user_id']
        plan = session['metadata']['plan']
        payment_id = session.get('payment_intent') or session.get('subscription')

        user = d.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(404, f"User not found: {user_id}")

        try:
            service.activate_premium(user, plan, payment_id)
        except Exception as e:
            raise HTTPException(500, f"Error activating premium: {str(e)}")

    elif event_type == 'customer.subscription.updated':
        # Subscription renewed - extend premium
        subscription = data
        user_id = subscription['metadata'].get('user_id')

        if user_id:
            user = d.query(User).filter(User.id == user_id).first()
            if user:
                try:
                    service.renew_premium(user)
                except Exception as e:
                    print(f"Error renewing premium: {str(e)}")

    elif event_type == 'customer.subscription.deleted':
        # Subscription cancelled - stop renewal
        subscription = data
        user_id = subscription['metadata'].get('user_id')

        if user_id:
            user = d.query(User).filter(User.id == user_id).first()
            if user:
                try:
                    service.cancel_premium(user)
                except Exception as e:
                    print(f"Error cancelling premium: {str(e)}")

    return {"success": True}


@router.post("/cancel")
async def cancel_subscription(
    d: Session = Depends(db),
    current_user: User = Depends(get_current_user)
):
    """
    Cancel premium subscription (user keeps access until expiry).

    Returns:
    {
        "success": true,
        "message": "Subscription cancelled. You'll have access until 2026-01-01"
    }
    """

    if not current_user.premiumPaymentId:
        raise HTTPException(400, "No active premium subscription")

    try:
        # Cancel Stripe subscription
        stripe.Subscription.delete(current_user.premiumPaymentId)

        # Update user in database
        service = PremiumService(d)
        service.cancel_premium(current_user)

        return {
            "success": True,
            "message": f"Subscription cancelled. You'll have access until {current_user.premiumUntil.strftime('%Y-%m-%d')}"
        }

    except stripe.error.StripeError as e:
        raise HTTPException(500, f"Stripe error: {str(e)}")
