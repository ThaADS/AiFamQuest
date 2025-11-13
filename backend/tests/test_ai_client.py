"""
Unit tests for AI client with 4-tier fallback system
Tests mock OpenRouter responses, timeouts, errors, and fallback behavior
"""
import pytest
import json
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime

from core.ai_client import (
    planner_plan,
    vision_tips,
    voice_intent,
    _call_openrouter,
    _call_with_fallback
)
from core.rule_based_planner import rule_based_plan

# Test fixtures
@pytest.fixture
def sample_week_context():
    """Sample family context for testing"""
    return {
        "familyMembers": [
            {"id": "uuid-noah", "name": "Noah", "age": 10, "role": "child"},
            {"id": "uuid-luna", "name": "Luna", "age": 8, "role": "child"},
            {"id": "uuid-eva", "name": "Eva", "age": 37, "role": "parent"}
        ],
        "tasks": [
            {"title": "Vaatwasser", "points": 10, "frequency": "daily"},
            {"title": "Stofzuigen", "points": 15, "frequency": "weekly"}
        ],
        "calendar": [
            {"date": "2025-11-17", "events": ["School 9-15"]}
        ],
        "constraints": {"maxTasksPerDay": 3}
    }

@pytest.fixture
def mock_openrouter_success():
    """Mock successful OpenRouter response"""
    return {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "weekPlan": [
                            {
                                "date": "2025-11-17",
                                "tasks": [
                                    {
                                        "title": "Vaatwasser",
                                        "assignee": "uuid-noah",
                                        "assigneeName": "Noah",
                                        "due": "2025-11-17T19:00:00Z",
                                        "points": 10
                                    }
                                ]
                            }
                        ],
                        "fairness": {
                            "distribution": {"Noah": 0.5, "Luna": 0.3, "Eva": 0.2},
                            "notes": "Balanced distribution"
                        }
                    })
                }
            }
        ],
        "usage": {
            "prompt_tokens": 150,
            "completion_tokens": 200
        }
    }

@pytest.fixture
def mock_vision_success():
    """Mock successful vision response"""
    return {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "detected": {"surface": "glass", "stain": "limescale"},
                        "steps": [
                            "Mix warm water with vinegar",
                            "Use microfiber cloth",
                            "Dry with newspaper"
                        ],
                        "warnings": ["Do not mix with bleach"],
                        "estimatedMinutes": 12,
                        "difficulty": 2
                    })
                }
            }
        ],
        "usage": {
            "prompt_tokens": 100,
            "completion_tokens": 150
        }
    }

# Test OpenRouter API call
@pytest.mark.asyncio
async def test_call_openrouter_success():
    """Test successful OpenRouter API call"""
    with patch("httpx.AsyncClient") as mock_client:
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"choices": [{"message": {"content": "test"}}]}
        mock_response.raise_for_status = Mock()

        mock_client.return_value.__aenter__.return_value.post = AsyncMock(return_value=mock_response)

        messages = [{"role": "user", "content": "test"}]
        response, error = await _call_openrouter(messages, "test-model")

        assert error is None
        assert response == {"choices": [{"message": {"content": "test"}}]}

@pytest.mark.asyncio
async def test_call_openrouter_timeout():
    """Test OpenRouter timeout handling"""
    with patch("httpx.AsyncClient") as mock_client:
        import httpx
        mock_client.return_value.__aenter__.return_value.post = AsyncMock(
            side_effect=httpx.TimeoutException("Timeout")
        )

        messages = [{"role": "user", "content": "test"}]
        response, error = await _call_openrouter(messages, "test-model", timeout=1.0)

        assert response is None
        assert "Timeout" in error

@pytest.mark.asyncio
async def test_call_openrouter_http_error():
    """Test OpenRouter HTTP error handling"""
    with patch("httpx.AsyncClient") as mock_client:
        import httpx
        mock_response = Mock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"

        mock_client.return_value.__aenter__.return_value.post = AsyncMock(
            side_effect=httpx.HTTPStatusError("Error", request=Mock(), response=mock_response)
        )

        messages = [{"role": "user", "content": "test"}]
        response, error = await _call_openrouter(messages, "test-model")

        assert response is None
        assert "HTTP 500" in error

# Test 4-tier fallback strategy
@pytest.mark.asyncio
async def test_fallback_tier1_success(mock_openrouter_success):
    """Test Tier 1 (Sonnet) success"""
    with patch("core.ai_client._call_openrouter", return_value=(mock_openrouter_success, None)):
        with patch("core.cache.get_cached_response", return_value=None):
            with patch("core.cache.set_cached_response", return_value=True):
                messages = [{"role": "user", "content": "test"}]
                response, tier, cache_hit, model = await _call_with_fallback(messages)

                assert tier == 1
                assert cache_hit is False
                assert "sonnet" in model.lower()
                assert response == mock_openrouter_success

@pytest.mark.asyncio
async def test_fallback_tier2_haiku():
    """Test Tier 2 (Haiku) fallback after Sonnet fails"""
    with patch("core.ai_client._call_openrouter") as mock_call:
        # First 3 calls (Sonnet retries) fail, 4th call (Haiku) succeeds
        mock_call.side_effect = [
            (None, "Timeout"),  # Sonnet attempt 1
            (None, "Timeout"),  # Sonnet attempt 2
            (None, "Timeout"),  # Sonnet attempt 3
            ({"choices": [{"message": {"content": "test"}}]}, None)  # Haiku success
        ]

        with patch("core.cache.get_cached_response", return_value=None):
            with patch("core.cache.set_cached_response", return_value=True):
                with patch("asyncio.sleep", return_value=None):  # Skip actual sleep
                    messages = [{"role": "user", "content": "test"}]
                    response, tier, cache_hit, model = await _call_with_fallback(messages)

                    assert tier == 2
                    assert cache_hit is False
                    assert "haiku" in model.lower()

@pytest.mark.asyncio
async def test_fallback_tier4_cache():
    """Test Tier 4 (cache) hit before trying API"""
    cached_response = {"choices": [{"message": {"content": "cached"}}]}

    with patch("core.cache.get_cached_response", return_value=cached_response):
        messages = [{"role": "user", "content": "test"}]
        response, tier, cache_hit, model = await _call_with_fallback(messages)

        assert tier == 4
        assert cache_hit is True
        assert model == "cached"
        assert response == cached_response

# Test planner with fallback to rule-based
@pytest.mark.asyncio
async def test_planner_tier1_success(sample_week_context, mock_openrouter_success):
    """Test planner with successful AI response"""
    with patch("core.ai_client._call_with_fallback", return_value=(mock_openrouter_success, 1, False, "sonnet")):
        result = await planner_plan(sample_week_context)

        assert "weekPlan" in result
        assert "fairness" in result
        assert len(result["weekPlan"]) >= 1
        assert result["fairness"]["distribution"]["Noah"] == 0.5

@pytest.mark.asyncio
async def test_planner_tier3_rule_based(sample_week_context):
    """Test planner fallback to rule-based (Tier 3)"""
    with patch("core.ai_client._call_with_fallback", return_value=({}, 3, False, "failed")):
        result = await planner_plan(sample_week_context)

        # Should get rule-based plan
        assert "weekPlan" in result
        assert "fairness" in result
        assert len(result["weekPlan"]) == 7  # 7 days

@pytest.mark.asyncio
async def test_planner_invalid_json():
    """Test planner with invalid AI JSON response"""
    invalid_response = {
        "choices": [{"message": {"content": "not valid json"}}],
        "usage": {"prompt_tokens": 10, "completion_tokens": 10}
    }

    with patch("core.ai_client._call_with_fallback", return_value=(invalid_response, 1, False, "sonnet")):
        result = await planner_plan({"familyMembers": [], "tasks": []})

        # Should fallback to rule-based
        assert "weekPlan" in result
        assert len(result["weekPlan"]) == 7

# Test vision tips
@pytest.mark.asyncio
async def test_vision_tips_success(mock_vision_success):
    """Test vision tips with successful AI response"""
    with patch("core.ai_client._call_with_fallback", return_value=(mock_vision_success, 1, False, "sonnet")):
        result = await vision_tips(
            photo_url="http://example.com/photo.jpg",
            user_description="dirty sink with limescale"
        )

        assert "detected" in result
        assert "steps" in result
        assert "warnings" in result
        assert result["detected"]["surface"] == "glass"
        assert len(result["steps"]) >= 3

@pytest.mark.asyncio
async def test_vision_tips_fallback():
    """Test vision tips fallback to generic advice"""
    with patch("core.ai_client._call_with_fallback", return_value=({}, 3, False, "failed")):
        result = await vision_tips(
            photo_url="http://example.com/photo.jpg",
            user_description="dirty surface"
        )

        # Should get generic fallback advice
        assert "steps" in result
        assert "warnings" in result
        assert result["detected"]["surface"] == "unknown"

# Test voice intent (stub)
@pytest.mark.asyncio
async def test_voice_intent_not_implemented():
    """Test voice intent returns not implemented message"""
    result = await voice_intent("Maak taak stofzuigen morgen 17:00")

    assert result["status"] == "not_implemented"
    assert "Phase 2" in result["message"]

# Test rule-based planner
def test_rule_based_planner(sample_week_context):
    """Test rule-based planner generates valid plan"""
    result = rule_based_plan(sample_week_context)

    assert "weekPlan" in result
    assert "fairness" in result
    assert len(result["weekPlan"]) == 7

    # Check fairness distribution
    distribution = result["fairness"]["distribution"]
    assert "Noah" in distribution
    assert "Luna" in distribution
    assert "Eva" in distribution

def test_rule_based_planner_empty():
    """Test rule-based planner with no members/tasks"""
    result = rule_based_plan({"familyMembers": [], "tasks": []})

    assert "weekPlan" in result
    assert len(result["weekPlan"]) == 7
    assert result["fairness"]["distribution"] == {}

# Test cost calculation
def test_cost_calculation():
    """Test AI usage cost calculation"""
    from core.monitoring import calculate_cost

    # Sonnet costs
    sonnet_cost = calculate_cost("anthropic/claude-3.5-sonnet", 1000, 1000)
    expected_sonnet = (1000/1000 * 0.003) + (1000/1000 * 0.015)  # $0.018
    assert abs(sonnet_cost - expected_sonnet) < 0.001

    # Haiku costs (10x cheaper)
    haiku_cost = calculate_cost("anthropic/claude-3-haiku", 1000, 1000)
    expected_haiku = (1000/1000 * 0.00025) + (1000/1000 * 0.00125)  # $0.0015
    assert abs(haiku_cost - expected_haiku) < 0.0001

    # Rule-based (free)
    rule_cost = calculate_cost("rule-based", 1000, 1000)
    assert rule_cost == 0.0

# Integration test: Full planner flow with DB logging
@pytest.mark.asyncio
async def test_planner_with_db_logging(sample_week_context, mock_openrouter_success):
    """Test planner with database logging"""
    mock_db = AsyncMock()

    with patch("core.ai_client._call_with_fallback", return_value=(mock_openrouter_success, 1, False, "sonnet")):
        with patch("core.monitoring.log_ai_usage") as mock_log:
            result = await planner_plan(
                sample_week_context,
                db_session=mock_db,
                family_id="test-family"
            )

            # Verify logging was called
            assert mock_log.called
            call_args = mock_log.call_args[1]
            assert call_args["endpoint"] == "planner"
            assert call_args["family_id"] == "test-family"
            assert call_args["cache_hit"] is False

# Performance test
@pytest.mark.asyncio
async def test_planner_response_time(sample_week_context):
    """Test planner response time meets requirements (<3s p95)"""
    with patch("core.ai_client._call_with_fallback") as mock_fallback:
        # Simulate fast response
        mock_fallback.return_value = (
            {
                "choices": [{
                    "message": {
                        "content": json.dumps({
                            "weekPlan": [{"date": "2025-11-17", "tasks": []}],
                            "fairness": {"distribution": {}, "notes": "test"}
                        })
                    }
                }],
                "usage": {"prompt_tokens": 10, "completion_tokens": 10}
            },
            1,
            False,
            "sonnet"
        )

        start = datetime.utcnow()
        result = await planner_plan(sample_week_context)
        duration = (datetime.utcnow() - start).total_seconds()

        # Should be very fast with mock
        assert duration < 1.0
        assert "weekPlan" in result

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
