# FamQuest Premium Monetization

Complete monetization system with Stripe integration, feature gates, and limit enforcement.

## Pricing Model

### Family Unlock - €9.99 One-Time

**What's Included:**
- All 8 themes unlocked for entire family
- One-time purchase, no subscription
- Applies to all family members forever

**Target Audience:** Families who want theme customization without subscription

### Premium Monthly - €4.99/Month

**What's Included:**
- Unlimited AI planning (no 5/day limit)
- All 8 themes unlocked
- Priority support
- Advanced analytics
- Custom badges
- Data export

**Target Audience:** Active families who use AI planning weekly

### Premium Yearly - €49.99/Year (Save 20%)

**What's Included:**
- Everything in Monthly
- Save €9.89 per year (2 months free)

**Target Audience:** Committed families looking for best value

## Feature Comparison

| Feature | Free | Family Unlock | Premium |
|---------|------|---------------|---------|
| Task Management | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited |
| Calendar | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited |
| Gamification | ✅ Full | ✅ Full | ✅ Full |
| AI Planning | 🔒 5/day | 🔒 5/day | ✅ Unlimited |
| Themes | 🔒 2 basic | ✅ All 8 | ✅ All 8 |
| Priority Support | ❌ | ❌ | ✅ |
| Advanced Analytics | ❌ | ❌ | ✅ |
| Custom Badges | ❌ | ❌ | ✅ |
| Data Export | ❌ | ❌ | ✅ |

## Architecture

### Database Schema

**Family Model:**
```python
class Family(Base):
    # ...existing fields...

    # Family Unlock (one-time purchase)
    familyUnlock: bool = False
    familyUnlockPurchasedAt: datetime | None
    familyUnlockPurchasedById: UUID | None  # FK to users
```

**User Model:**
```python
class User(Base):
    # ...existing fields...

    # Premium subscription (individual)
    premiumUntil: datetime | None  # Subscription expiry
    premiumPlan: str | None  # 'monthly' | 'yearly'
    premiumPaymentId: str | None  # Stripe subscription ID
```

**AIUsageLog Model:**
```python
class AIUsageLog(Base):
    id: UUID
    userId: UUID
    action: str  # 'plan_week' | 'generate_tasks' | 'study_plan'
    metadata: dict  # {'total_tasks': 28, 'cost': 0.003}
    createdAt: datetime
```

### Services

#### PremiumService

```python
from services.premium_service import PremiumService

service = PremiumService(db)

# Check premium status
status = service.check_premium(user)
# {
#     "has_premium": true,
#     "has_family_unlock": false,
#     "premium_expires": "2026-01-15T00:00:00",
#     "premium_plan": "yearly",
#     "features": {
#         "unlimited_ai": true,
#         "all_themes": true,
#         "priority_support": true
#     }
# }

# Check AI planning limits
limits = service.can_use_ai_planning(user)
# {
#     "allowed": true,
#     "remaining": 2,
#     "limit": 5,
#     "resets_at": "2025-11-12T00:00:00"
# }

# Log AI usage
service.log_ai_usage(user, action='plan_week', metadata={
    'total_tasks': 28,
    'cost': 0.003
})

# Check theme access
can_use = service.can_use_theme(user, 'classy')  # true/false

# Activate premium (called by Stripe webhook)
service.activate_premium(user, plan='yearly', payment_id='sub_...')

# Cancel subscription
service.cancel_premium(user)  # User keeps access until expiry

# Renew subscription (called by Stripe webhook)
service.renew_premium(user)
```

## API Endpoints

### GET /premium/status

Get user's premium status.

**Request:**
```bash
GET /premium/status
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "has_premium": true,
  "has_family_unlock": false,
  "premium_expires": "2026-01-15T00:00:00",
  "premium_plan": "yearly",
  "features": {
    "unlimited_ai": true,
    "all_themes": true,
    "priority_support": true,
    "advanced_analytics": true,
    "custom_badges": true,
    "export_data": true
  }
}
```

### GET /premium/ai-limits

Get AI planning usage limits.

**Response:**
```json
{
  "allowed": true,
  "remaining": 2,
  "limit": 5,
  "resets_at": "2025-11-12T00:00:00"
}
```

For premium users:
```json
{
  "allowed": true,
  "remaining": -1,
  "limit": -1,
  "resets_at": null
}
```

### GET /premium/pricing

Get pricing information.

**Response:**
```json
{
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
    "description": "Everything in Monthly (save 20%)"
  }
}
```

### POST /premium/checkout

Create Stripe checkout session.

**Request:**
```json
{
  "plan": "family_unlock"  // 'family_unlock' | 'monthly' | 'yearly'
}
```

**Response:**
```json
{
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_...",
  "session_id": "cs_..."
}
```

**Frontend Usage:**
```javascript
// Redirect to Stripe Checkout
const response = await fetch('/premium/checkout', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` },
  body: JSON.stringify({ plan: 'yearly' })
});

const { checkout_url } = await response.json();
window.location.href = checkout_url;  // Redirect to Stripe
```

### POST /premium/webhook

Stripe webhook endpoint (called by Stripe).

**Events Handled:**
- `checkout.session.completed`: Payment successful → activate premium
- `customer.subscription.updated`: Subscription renewed → extend premium
- `customer.subscription.deleted`: Subscription cancelled → stop renewal

**Configuration:**
```bash
# Stripe Dashboard → Webhooks → Add endpoint
# URL: https://api.famquest.app/premium/webhook
# Events: checkout.session.completed, customer.subscription.*
```

### POST /premium/cancel

Cancel premium subscription.

**Response:**
```json
{
  "success": true,
  "message": "Subscription cancelled. You'll have access until 2026-01-15"
}
```

## Limit Enforcement

### AI Planning Limit

**Implementation in AI Router:**

```python
# backend/routers/ai.py

@router.post("/ai/plan-week")
async def plan_week(
    request: WeekPlanRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Get user object
    user = db.query(User).filter(User.id == current_user["id"]).first()

    # Check premium limits
    premium_service = PremiumService(db)
    ai_limits = premium_service.can_use_ai_planning(user)

    if not ai_limits["allowed"]:
        raise HTTPException(
            403,
            f"Daily AI planning limit reached ({ai_limits['limit']} per day). "
            f"Resets at {ai_limits['resets_at']}. "
            "Upgrade to Premium for unlimited AI planning."
        )

    # Generate plan
    planner = AIPlanner(db, family_id)
    plan = await planner.generate_week_plan(start_date, preferences)

    # Log AI usage for rate limiting
    premium_service.log_ai_usage(
        user,
        action='plan_week',
        metadata={'total_tasks': plan['total_tasks'], 'cost': plan['cost']}
    )

    return plan
```

**Error Response (Limit Reached):**
```json
{
  "detail": "Daily AI planning limit reached (5 per day). Resets at 2025-11-12T00:00:00. Upgrade to Premium for unlimited AI planning."
}
```

### Theme Access Limit

**Implementation in User Profile:**

```python
@router.put("/users/profile")
async def update_profile(
    profile: ProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    user = db.query(User).filter(User.id == current_user["id"]).first()

    # Check theme access
    if profile.theme:
        premium_service = PremiumService(db)

        if not premium_service.can_use_theme(user, profile.theme):
            raise HTTPException(
                403,
                f"Theme '{profile.theme}' requires Family Unlock or Premium. "
                "Upgrade to unlock all themes."
            )

    user.theme = profile.theme
    db.commit()

    return {"success": True}
```

## Stripe Configuration

### 1. Create Stripe Account

Visit [https://dashboard.stripe.com/register](https://dashboard.stripe.com/register)

### 2. Create Products

**Family Unlock:**
- Name: "FamQuest Family Unlock"
- Price: €9.99
- Type: One-time payment
- Copy Price ID → `STRIPE_PRICE_FAMILY_UNLOCK`

**Premium Monthly:**
- Name: "FamQuest Premium"
- Price: €4.99
- Type: Recurring (monthly)
- Copy Price ID → `STRIPE_PRICE_MONTHLY`

**Premium Yearly:**
- Name: "FamQuest Premium (Yearly)"
- Price: €49.99
- Type: Recurring (yearly)
- Copy Price ID → `STRIPE_PRICE_YEARLY`

### 3. Configure Webhooks

**URL:** `https://api.famquest.app/premium/webhook`

**Events:**
- `checkout.session.completed`
- `customer.subscription.updated`
- `customer.subscription.deleted`

Copy Webhook Secret → `STRIPE_WEBHOOK_SECRET`

### 4. Environment Variables

```bash
# .env
STRIPE_SECRET_KEY=sk_test_...  # or sk_live_... for production
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_FAMILY_UNLOCK=price_...
STRIPE_PRICE_MONTHLY=price_...
STRIPE_PRICE_YEARLY=price_...
FRONTEND_URL=https://famquest.app
```

### 5. Test Payments

**Test Cards:**
- Success: `4242 4242 4242 4242`
- Decline: `4000 0000 0000 0002`
- 3D Secure: `4000 0027 6000 3184`

## Testing

### Unit Tests

```bash
cd backend
pytest tests/test_premium.py -v
```

**Test Coverage:**
- 22 test cases
- Premium status (free, monthly, yearly, family unlock)
- AI planning limits (free, premium, limit reached)
- Theme access (free, premium, family unlock)
- Activation, cancellation, renewal
- Pricing information

### Integration Testing

```bash
# 1. Start backend
cd backend
uvicorn main:app --reload

# 2. Test checkout flow
curl -X POST http://localhost:8000/premium/checkout \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"plan": "family_unlock"}'

# 3. Test webhook
stripe listen --forward-to localhost:8000/premium/webhook
stripe trigger checkout.session.completed
```

## Best Practices

### 1. Feature Gate Consistently

Always check premium status before feature access:

```python
# Good
premium_service = PremiumService(db)
if not premium_service.can_use_ai_planning(user)["allowed"]:
    raise HTTPException(403, "Upgrade to Premium")

# Bad (no check)
plan = await generate_plan()  # No limit enforcement
```

### 2. Provide Clear Upgrade Prompts

```json
{
  "error": "Daily limit reached (5/day)",
  "upgrade_message": "Upgrade to Premium for unlimited AI planning",
  "pricing": {
    "monthly": "€4.99/month",
    "yearly": "€49.99/year (save 20%)"
  },
  "checkout_url": "/premium"
}
```

### 3. Log All Premium Events

```python
# Log activation
audit = AuditLog(
    actorUserId=user.id,
    familyId=user.familyId,
    action="premium_activated",
    meta={"plan": "yearly", "payment_id": payment_id}
)
db.add(audit)
```

### 4. Handle Edge Cases

```python
# Check for expiring premium
if user.premiumUntil:
    days_remaining = (user.premiumUntil - datetime.utcnow()).days

    if days_remaining <= 7:
        # Show renewal reminder
        notifications.send(
            user,
            "Your premium expires in {days_remaining} days"
        )
```

## Troubleshooting

### Stripe Checkout Not Redirecting

Check `FRONTEND_URL` in `.env`:

```bash
# Development
FRONTEND_URL=http://localhost:3000

# Production
FRONTEND_URL=https://famquest.app
```

### Webhook Not Receiving Events

1. Check webhook URL in Stripe Dashboard
2. Verify webhook secret: `echo $STRIPE_WEBHOOK_SECRET`
3. Test with Stripe CLI: `stripe listen --forward-to localhost:8000/premium/webhook`

### AI Limit Not Resetting

Limits reset at midnight UTC. Check timezone:

```python
# Debug: Check current UTC time
from datetime import datetime
print(datetime.utcnow())

# Debug: Check reset time
service = PremiumService(db)
limits = service.can_use_ai_planning(user)
print(limits["resets_at"])  # Should be midnight UTC
```

## Roadmap

### Phase 1 (Complete)
- ✅ Family Unlock (€9.99)
- ✅ Premium Monthly (€4.99)
- ✅ Premium Yearly (€49.99)
- ✅ AI planning limits (5/day free)
- ✅ Theme access limits
- ✅ Stripe integration

### Phase 2 (Q1 2026)
- [ ] Lifetime Premium (€99.99 one-time)
- [ ] Family Premium (€9.99/month for 2-6 members)
- [ ] Advanced analytics dashboard
- [ ] Custom badge creation
- [ ] Data export (JSON, CSV)

### Phase 3 (Q2 2026)
- [ ] Team/Organization plans
- [ ] Affiliate program
- [ ] Referral rewards
- [ ] Gift subscriptions
