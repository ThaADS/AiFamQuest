"""
AI usage monitoring and cost tracking
Implements real-time cost tracking with Slack alerts
"""
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from sqlalchemy import String, Integer, Float, DateTime, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from core.models import AIUsageLog

# Cost constants (per 1K tokens)
COST_SONNET_INPUT = 0.003  # $0.003 per 1K input tokens
COST_SONNET_OUTPUT = 0.015  # $0.015 per 1K output tokens
COST_HAIKU_INPUT = 0.00025  # $0.00025 per 1K input tokens
COST_HAIKU_OUTPUT = 0.00125  # $0.00125 per 1K output tokens

# Alert thresholds
WEEKLY_BUDGET_USD = 500.0  # Alert if exceeds $500/week
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")

def calculate_cost(model: str, tokens_in: int, tokens_out: int) -> float:
    """Calculate cost in USD for AI usage"""
    if "sonnet" in model.lower():
        input_cost = (tokens_in / 1000) * COST_SONNET_INPUT
        output_cost = (tokens_out / 1000) * COST_SONNET_OUTPUT
        return input_cost + output_cost
    elif "haiku" in model.lower():
        input_cost = (tokens_in / 1000) * COST_HAIKU_INPUT
        output_cost = (tokens_out / 1000) * COST_HAIKU_OUTPUT
        return input_cost + output_cost
    else:
        return 0.0  # rule-based or cached = zero cost

async def log_ai_usage(
    db_session,
    model: str,
    endpoint: str,
    tokens_in: int,
    tokens_out: int,
    cache_hit: bool,
    fallback_tier: int,
    family_id: str,
    response_time_ms: int,
    error: Optional[str] = None
) -> AIUsageLog:
    """Log AI usage to database"""
    import uuid

    cost = calculate_cost(model, tokens_in, tokens_out)

    log_entry = AIUsageLog(
        id=str(uuid.uuid4()),
        model=model,
        endpoint=endpoint,
        tokens_in=tokens_in,
        tokens_out=tokens_out,
        cost_usd=cost,
        cache_hit=cache_hit,
        fallback_tier=fallback_tier,
        family_id=family_id,
        response_time_ms=response_time_ms,
        error=error
    )

    db_session.add(log_entry)
    await db_session.commit()

    # Check if weekly budget exceeded
    await check_weekly_budget_alert(db_session)

    return log_entry

async def check_weekly_budget_alert(db_session):
    """Check if weekly budget exceeded and send Slack alert"""
    if not SLACK_WEBHOOK_URL:
        return

    # Calculate this week's costs
    week_start = datetime.utcnow() - timedelta(days=7)

    from sqlalchemy import select, func
    stmt = select(func.sum(AIUsageLog.cost_usd)).where(
        AIUsageLog.timestamp >= week_start
    )
    result = await db_session.execute(stmt)
    weekly_cost = result.scalar() or 0.0

    if weekly_cost > WEEKLY_BUDGET_USD:
        await send_slack_alert(
            f"AI cost alert: ${weekly_cost:.2f} exceeds weekly budget of ${WEEKLY_BUDGET_USD:.2f}"
        )

async def send_slack_alert(message: str):
    """Send alert to Slack webhook"""
    import httpx
    import json

    if not SLACK_WEBHOOK_URL:
        print(f"Slack alert (no webhook configured): {message}")
        return

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            await client.post(
                SLACK_WEBHOOK_URL,
                json={"text": message}
            )
    except Exception as e:
        print(f"Failed to send Slack alert: {e}")

async def get_cost_metrics(
    db_session,
    days: int = 7
) -> Dict[str, any]:
    """Get AI cost metrics for dashboard"""
    from sqlalchemy import select, func

    since = datetime.utcnow() - timedelta(days=days)

    # Total cost
    cost_stmt = select(func.sum(AIUsageLog.cost_usd)).where(
        AIUsageLog.timestamp >= since
    )
    cost_result = await db_session.execute(cost_stmt)
    total_cost = cost_result.scalar() or 0.0

    # Total requests
    count_stmt = select(func.count(AIUsageLog.id)).where(
        AIUsageLog.timestamp >= since
    )
    count_result = await db_session.execute(count_stmt)
    total_requests = count_result.scalar() or 0

    # Cache hit rate
    cache_stmt = select(func.count(AIUsageLog.id)).where(
        AIUsageLog.timestamp >= since,
        AIUsageLog.cache_hit == True
    )
    cache_result = await db_session.execute(cache_stmt)
    cache_hits = cache_result.scalar() or 0

    cache_hit_rate = (cache_hits / total_requests * 100) if total_requests > 0 else 0.0

    # Cost by model
    model_stmt = select(
        AIUsageLog.model,
        func.sum(AIUsageLog.cost_usd).label("cost"),
        func.count(AIUsageLog.id).label("count")
    ).where(
        AIUsageLog.timestamp >= since
    ).group_by(AIUsageLog.model)

    model_result = await db_session.execute(model_stmt)
    cost_by_model = [
        {"model": row.model, "cost": float(row.cost), "count": row.count}
        for row in model_result
    ]

    # Daily breakdown
    daily_stmt = select(
        func.date(AIUsageLog.timestamp).label("date"),
        func.sum(AIUsageLog.cost_usd).label("cost"),
        func.count(AIUsageLog.id).label("requests")
    ).where(
        AIUsageLog.timestamp >= since
    ).group_by(func.date(AIUsageLog.timestamp)).order_by("date")

    daily_result = await db_session.execute(daily_stmt)
    daily_breakdown = [
        {"date": str(row.date), "cost": float(row.cost), "requests": row.requests}
        for row in daily_result
    ]

    return {
        "total_cost_usd": round(total_cost, 2),
        "total_requests": total_requests,
        "cache_hit_rate_pct": round(cache_hit_rate, 1),
        "cost_by_model": cost_by_model,
        "daily_breakdown": daily_breakdown,
        "period_days": days
    }

async def get_fallback_stats(db_session, days: int = 7) -> Dict[str, int]:
    """Get fallback tier usage statistics"""
    from sqlalchemy import select, func

    since = datetime.utcnow() - timedelta(days=days)

    stmt = select(
        AIUsageLog.fallback_tier,
        func.count(AIUsageLog.id).label("count")
    ).where(
        AIUsageLog.timestamp >= since
    ).group_by(AIUsageLog.fallback_tier)

    result = await db_session.execute(stmt)
    return {f"tier_{row.fallback_tier}": row.count for row in result}
