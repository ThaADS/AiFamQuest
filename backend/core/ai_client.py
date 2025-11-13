"""
AI Client with 4-tier fallback system
Implements robust AI service with cost optimization and graceful degradation
"""
import os
import httpx
import json
import asyncio
from typing import Dict, Any, Optional, Tuple
from jsonschema import validate, ValidationError
from datetime import datetime

from core.cache import get_cached_response, set_cached_response
from core.rule_based_planner import rule_based_plan

# Configuration
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Model configurations
MODEL_SONNET = "anthropic/claude-3.5-sonnet"
MODEL_HAIKU = "anthropic/claude-3-haiku"

# Timeout and retry configuration
TIMEOUT_TIER1 = 30.0  # Sonnet timeout
TIMEOUT_TIER2 = 15.0  # Haiku timeout
RETRY_BACKOFF = [1, 2, 4]  # Exponential backoff seconds

# Schemas
PLAN_SCHEMA = {
    "type": "object",
    "properties": {
        "weekPlan": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "date": {"type": "string"},
                    "tasks": {"type": "array"}
                },
                "required": ["date", "tasks"]
            }
        },
        "fairness": {"type": "object"}
    },
    "required": ["weekPlan"]
}

VISION_SCHEMA = {
    "type": "object",
    "properties": {
        "detected": {"type": "object"},
        "steps": {"type": "array"},
        "warnings": {"type": "array"},
        "estimatedMinutes": {"type": "number"},
        "difficulty": {"type": "number"}
    },
    "required": ["steps"]
}

def _headers() -> Dict[str, str]:
    """Generate OpenRouter API headers"""
    if not OPENROUTER_API_KEY:
        return {}
    return {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "HTTP-Referer": "https://famquest.app",
        "X-Title": "FamQuest"
    }

async def _call_openrouter(
    messages: list,
    model: str,
    temperature: float = 0.4,
    timeout: float = 30.0
) -> Tuple[Optional[Dict], Optional[str]]:
    """
    Call OpenRouter API with timeout

    Returns:
        (response_dict, error_message)
    """
    if not OPENROUTER_API_KEY:
        return None, "OpenRouter API key not configured"

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                OPENROUTER_URL,
                headers=_headers(),
                json={
                    "model": model,
                    "messages": messages,
                    "temperature": temperature
                }
            )
            response.raise_for_status()
            return response.json(), None
    except httpx.TimeoutException:
        return None, f"Timeout after {timeout}s"
    except httpx.HTTPStatusError as e:
        return None, f"HTTP {e.response.status_code}: {e.response.text[:200]}"
    except Exception as e:
        return None, str(e)

async def _call_with_fallback(
    messages: list,
    temperature: float = 0.4
) -> Tuple[Dict, int, bool, str]:
    """
    4-tier fallback strategy

    Returns:
        (response, tier_used, cache_hit, model_name)
    """
    # Generate cache key from messages
    prompt = json.dumps(messages)

    # TIER 4: Check cache first
    cached = await get_cached_response(prompt, MODEL_SONNET, temperature)
    if cached:
        return cached, 4, True, "cached"

    # TIER 1: Try Sonnet (primary, high quality)
    for attempt, delay in enumerate(RETRY_BACKOFF):
        response, error = await _call_openrouter(
            messages, MODEL_SONNET, temperature, TIMEOUT_TIER1
        )
        if response:
            # Cache successful response
            await set_cached_response(prompt, MODEL_SONNET, temperature, response)
            return response, 1, False, MODEL_SONNET

        # Exponential backoff before retry
        if attempt < len(RETRY_BACKOFF) - 1:
            await asyncio.sleep(delay)

    # TIER 2: Fallback to Haiku (10x cheaper, faster)
    for attempt, delay in enumerate(RETRY_BACKOFF):
        response, error = await _call_openrouter(
            messages, MODEL_HAIKU, temperature, TIMEOUT_TIER2
        )
        if response:
            await set_cached_response(prompt, MODEL_HAIKU, temperature, response)
            return response, 2, False, MODEL_HAIKU

        if attempt < len(RETRY_BACKOFF) - 1:
            await asyncio.sleep(delay)

    # TIER 3: Rule-based fallback handled by caller
    # Return None to signal complete failure
    return {}, 3, False, "failed"

async def planner_plan(
    week_context: dict,
    db_session=None,
    family_id: str = "unknown"
) -> Dict[str, Any]:
    """
    AI Planner with 4-tier fallback

    Args:
        week_context: Family context, tasks, calendar, constraints
        db_session: Database session for logging (optional)
        family_id: Family ID for cost tracking

    Returns:
        JSON with weekPlan and fairness distribution
    """
    start_time = datetime.utcnow()

    # System prompt with fairness algorithm
    system_prompt = """You are a family task planning assistant.
Generate a weekly plan that fairly distributes household tasks across family members.

Consider:
- Age and role (parents do less, young children get easier tasks)
- Calendar events (don't assign tasks on busy days)
- Task rotation for variety
- Fairness: aim for equal distribution adjusted by capacity

Output pure JSON with this structure:
{
  "weekPlan": [
    {
      "date": "2025-11-17",
      "tasks": [
        {"title": "Vaatwasser", "assignee": "uuid", "assigneeName": "Noah", "due": "2025-11-17T19:00:00Z", "points": 10}
      ]
    }
  ],
  "fairness": {
    "distribution": {"Noah": 0.28, "Luna": 0.24, "Sam": 0.22, "Eva": 0.13, "Mark": 0.13},
    "notes": "Balanced distribution by age and availability"
  }
}"""

    user_prompt = f"Context: {json.dumps(week_context)}\n\nGenerate weekly plan as JSON."

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]

    # Try AI with fallback
    response, tier, cache_hit, model = await _call_with_fallback(messages)

    # Parse AI response
    if response and tier < 3:
        try:
            content = response["choices"][0]["message"]["content"]
            data = json.loads(content)
            validate(data, PLAN_SCHEMA)

            # Log usage
            if db_session:
                from core.monitoring import log_ai_usage
                tokens_in = response.get("usage", {}).get("prompt_tokens", 0)
                tokens_out = response.get("usage", {}).get("completion_tokens", 0)
                response_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)

                await log_ai_usage(
                    db_session,
                    model=model,
                    endpoint="planner",
                    tokens_in=tokens_in,
                    tokens_out=tokens_out,
                    cache_hit=cache_hit,
                    fallback_tier=tier,
                    family_id=family_id,
                    response_time_ms=response_time
                )

            return data

        except (json.JSONDecodeError, ValidationError, KeyError) as e:
            print(f"AI response parse error: {e}")
            # Fall through to rule-based

    # TIER 3: Rule-based planner (deterministic, offline-capable)
    print("Using rule-based planner (Tier 3 fallback)")
    rule_plan = rule_based_plan(week_context)

    # Log rule-based usage
    if db_session:
        from core.monitoring import log_ai_usage
        response_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        await log_ai_usage(
            db_session,
            model="rule-based",
            endpoint="planner",
            tokens_in=0,
            tokens_out=0,
            cache_hit=False,
            fallback_tier=3,
            family_id=family_id,
            response_time_ms=response_time
        )

    return rule_plan

async def vision_tips(
    photo_url: str,
    user_description: str = "",
    db_session=None,
    family_id: str = "unknown"
) -> Dict[str, Any]:
    """
    Vision tips for cleaning advice (GPT-4 Vision via OpenRouter)

    Args:
        photo_url: URL to photo
        user_description: Optional user description
        db_session: Database session for logging
        family_id: Family ID for cost tracking

    Returns:
        JSON with cleaning tips, warnings, estimated time
    """
    start_time = datetime.utcnow()

    system_prompt = """You are a professional cleaning coach.
Analyze the photo and provide step-by-step cleaning advice.

Output pure JSON:
{
  "detected": {"surface": "glass", "stain": "limescale"},
  "steps": [
    "Mix warm water with vinegar",
    "Use microfiber cloth, wring well",
    "Dry with newspaper or dry cloth"
  ],
  "warnings": ["Do not mix with bleach", "Ventilate the room"],
  "estimatedMinutes": 12,
  "difficulty": 2
}"""

    # For now, use text description (vision requires GPT-4V integration)
    # TODO: Implement actual image analysis in Phase 2
    user_prompt = f"Photo description: {user_description or 'dirty surface'}\n\nProvide cleaning tips as JSON."

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]

    # Try AI with fallback
    response, tier, cache_hit, model = await _call_with_fallback(messages, temperature=0.7)

    # Parse AI response
    if response and tier < 3:
        try:
            content = response["choices"][0]["message"]["content"]
            data = json.loads(content)
            validate(data, VISION_SCHEMA)

            # Log usage
            if db_session:
                from core.monitoring import log_ai_usage
                tokens_in = response.get("usage", {}).get("prompt_tokens", 0)
                tokens_out = response.get("usage", {}).get("completion_tokens", 0)
                response_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)

                await log_ai_usage(
                    db_session,
                    model=model,
                    endpoint="vision",
                    tokens_in=tokens_in,
                    tokens_out=tokens_out,
                    cache_hit=cache_hit,
                    fallback_tier=tier,
                    family_id=family_id,
                    response_time_ms=response_time
                )

            return data

        except (json.JSONDecodeError, ValidationError, KeyError) as e:
            print(f"Vision response parse error: {e}")
            # Fall through to fallback

    # Fallback: Generic cleaning advice
    fallback_tips = {
        "detected": {"surface": "unknown", "stain": "general"},
        "steps": [
            "Start with warm water and mild soap",
            "Use appropriate cloth for the surface",
            "Rinse thoroughly and dry",
            "Ventilate the area"
        ],
        "warnings": ["Test cleaning solution in hidden area first", "Wear gloves if using chemicals"],
        "estimatedMinutes": 15,
        "difficulty": 2
    }

    # Log fallback usage
    if db_session:
        from core.monitoring import log_ai_usage
        response_time = int((datetime.utcnow() - start_time).total_seconds() * 1000)
        await log_ai_usage(
            db_session,
            model="fallback",
            endpoint="vision",
            tokens_in=0,
            tokens_out=0,
            cache_hit=False,
            fallback_tier=3,
            family_id=family_id,
            response_time_ms=response_time,
            error="AI unavailable, used fallback"
        )

    return fallback_tips

async def voice_intent(
    transcript: str,
    db_session=None,
    family_id: str = "unknown"
) -> Dict[str, Any]:
    """
    Voice NLU intent parsing (Phase 2 - stub for now)

    Args:
        transcript: Voice transcript text
        db_session: Database session
        family_id: Family ID

    Returns:
        Parsed intent and slots
    """
    return {
        "status": "not_implemented",
        "message": "Voice NLU will be implemented in Phase 2",
        "transcript": transcript
    }
