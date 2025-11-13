# FamQuest AI Architecture Documentation

## Overview

FamQuest implements a robust 4-tier AI fallback system to mitigate the risk of OpenRouter Single Point of Failure (SPOF) while optimizing costs from a baseline of €80K/year to €15-30K/year through aggressive caching and model selection.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Request                          │
│                   (FastAPI /ai/plan)                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   TIER 4: Redis Cache                        │
│              (7-day TTL, 60% target hit rate)               │
│                   Zero cost if hit                          │
└─────────────────────┬───────────────────────────────────────┘
                      │ Cache miss
                      ▼
┌─────────────────────────────────────────────────────────────┐
│             TIER 1: OpenRouter Claude Sonnet                │
│          (Primary, €0.003/1K tokens, 30s timeout)           │
│              Exponential backoff: 1s, 2s, 4s                │
└─────────────────────┬───────────────────────────────────────┘
                      │ Timeout/Error
                      ▼
┌─────────────────────────────────────────────────────────────┐
│             TIER 2: OpenRouter Claude Haiku                 │
│        (Fallback, €0.00025/1K tokens, 15s timeout)          │
│              Exponential backoff: 1s, 2s, 4s                │
└─────────────────────┬───────────────────────────────────────┘
                      │ Complete failure
                      ▼
┌─────────────────────────────────────────────────────────────┐
│            TIER 3: Rule-Based Planner                       │
│       (Deterministic, offline-capable, zero cost)            │
│         Fairness algorithm by age/role/calendar             │
└─────────────────────────────────────────────────────────────┘
```

## 4-Tier Fallback Strategy

### Tier 1: OpenRouter Claude Sonnet (Primary)

- **Model**: `anthropic/claude-3.5-sonnet`
- **Cost**: $0.003/1K input tokens, $0.015/1K output tokens
- **Timeout**: 30 seconds
- **Retry Strategy**: 3 attempts with exponential backoff (1s, 2s, 4s)
- **Use Case**: High-quality AI planning with complex fairness logic
- **Response Caching**: All successful responses cached to Redis

**Quality**: Highest quality results with nuanced understanding of family dynamics

### Tier 2: OpenRouter Claude Haiku (Fallback)

- **Model**: `anthropic/claude-3-haiku`
- **Cost**: $0.00025/1K input tokens, $0.00125/1K output tokens (10x cheaper)
- **Timeout**: 15 seconds
- **Retry Strategy**: 3 attempts with exponential backoff (1s, 2s, 4s)
- **Use Case**: Fast, cost-effective planning when Sonnet fails
- **Response Caching**: All successful responses cached to Redis

**Quality**: Good quality results, suitable for most planning scenarios

### Tier 3: Rule-Based Planner (Deterministic)

- **Implementation**: `core/rule_based_planner.py`
- **Cost**: Zero (pure Python logic)
- **Latency**: <100ms
- **Use Case**: Complete AI service outage, offline capability
- **Logic**:
  - Workload capacity by age/role
  - Calendar event awareness (skip busy days)
  - Round-robin task assignment
  - Fairness distribution calculation

**Quality**: Predictable, fair results without AI intelligence

### Tier 4: Redis Cache (Pre-computed)

- **Storage**: Redis with 7-day TTL
- **Cost**: Zero (cached responses)
- **Latency**: <10ms
- **Hit Rate Target**: 60% after 7 days of usage
- **Cache Key**: SHA256 hash of `(prompt + model + temperature)`
- **Invalidation**: On family settings change

**Quality**: Identical to original AI response quality

## Cost Optimization Strategy

### Baseline Costs (Without Optimization)

```yaml
assumptions:
  families: 5000
  ai_requests_per_family_per_week: 7
  average_prompt_tokens: 800
  average_completion_tokens: 600
  model: claude-3.5-sonnet

calculations:
  total_requests_per_week: 35000
  total_input_tokens: 28M tokens/week
  total_output_tokens: 21M tokens/week
  weekly_cost: $154
  annual_cost: $80,080

conclusion: UNSUSTAINABLE
```

### Optimized Costs (With Caching + Model Selection)

```yaml
optimizations:
  cache_hit_rate: 60%
  haiku_usage: 30%
  sonnet_usage: 10%
  rule_based_usage: 0%  # Emergency only

calculations:
  cached_requests: 21000 (60%)  # $0 cost
  haiku_requests: 10500 (30%)   # $26/week
  sonnet_requests: 3500 (10%)   # $54/week
  weekly_cost: $80
  annual_cost: $4,160

monthly_breakdown:
  month_1: $577 (low cache hit rate)
  month_2: $346 (cache warming)
  month_3+: $320 (steady state)

annual_total: $4,160 (95% cost reduction)
```

### Cost Monitoring Alerts

- **Weekly Budget**: $500/week threshold
- **Alert Channel**: Slack webhook
- **Trigger**: Automatic alert if weekly cost exceeds budget
- **Dashboard**: `/ai/costs` endpoint with daily breakdown

## Implementation Details

### Core Files

1. **backend/core/ai_client.py**
   - `planner_plan()`: Main AI planner with 4-tier fallback
   - `vision_tips()`: Vision-based cleaning advice
   - `voice_intent()`: Voice NLU (Phase 2 stub)
   - `_call_with_fallback()`: 4-tier strategy orchestration

2. **backend/core/cache.py**
   - `get_cached_response()`: Retrieve from Redis
   - `set_cached_response()`: Store with TTL
   - `invalidate_family_cache()`: Clear on settings change
   - `get_cache_stats()`: Hit rate metrics

3. **backend/core/rule_based_planner.py**
   - `rule_based_plan()`: Deterministic planning logic
   - `_calculate_workload_weights()`: Age/role capacity
   - `_distribute_daily_tasks()`: Fair task assignment
   - `_calculate_fairness()`: Distribution metrics

4. **backend/core/monitoring.py**
   - `AIUsageLog`: Database model for usage tracking
   - `log_ai_usage()`: Record every AI call
   - `get_cost_metrics()`: Dashboard metrics
   - `check_weekly_budget_alert()`: Cost monitoring

5. **backend/routers/ai.py**
   - `POST /ai/plan`: AI planner endpoint
   - `POST /ai/vision-tips`: Vision cleaning advice
   - `POST /ai/voice-intent`: Voice NLU (stub)
   - `GET /ai/costs`: Cost monitoring dashboard
   - `GET /ai/health`: Service health check

### Database Schema

```sql
CREATE TABLE ai_usage_log (
    id VARCHAR PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    model VARCHAR,              -- sonnet, haiku, rule-based, cached
    endpoint VARCHAR,            -- planner, vision, voice
    tokens_in INTEGER,
    tokens_out INTEGER,
    cost_usd FLOAT,
    cache_hit BOOLEAN,
    fallback_tier INTEGER,      -- 1=sonnet, 2=haiku, 3=rules, 4=cache
    family_id VARCHAR,
    response_time_ms INTEGER,
    error VARCHAR
);

CREATE INDEX idx_timestamp ON ai_usage_log(timestamp);
CREATE INDEX idx_model ON ai_usage_log(model);
CREATE INDEX idx_family_id ON ai_usage_log(family_id);
```

### Environment Variables

```bash
# Required
OPENROUTER_API_KEY=sk-or-v1-xxxxx
REDIS_URL=redis://localhost:6379/0

# Optional
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx
MEDIA_DIR=./uploads
PUBLIC_BASE=https://famquest.app
```

## API Usage Examples

### 1. AI Planner

**Request:**
```bash
POST /ai/plan
Authorization: Bearer {jwt_token}
Content-Type: application/json

{
  "weekContext": {
    "familyMembers": [
      {"id": "uuid-noah", "name": "Noah", "age": 10, "role": "child"},
      {"id": "uuid-luna", "name": "Luna", "age": 8, "role": "child"}
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
}
```

**Response (200 OK):**
```json
{
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
        },
        {
          "title": "Stofzuigen",
          "assignee": "uuid-luna",
          "assigneeName": "Luna",
          "due": "2025-11-17T18:00:00Z",
          "points": 15
        }
      ]
    }
  ],
  "fairness": {
    "distribution": {"Noah": 0.52, "Luna": 0.48},
    "notes": "Balanced distribution by age and availability"
  }
}
```

### 2. Vision Tips

**Request:**
```bash
POST /ai/vision-tips
Authorization: Bearer {jwt_token}
Content-Type: multipart/form-data

file: dirty_sink.jpg
description: "dirty sink with limescale and grease"
```

**Response (200 OK):**
```json
{
  "url": "https://famquest.app/uploads/abc123_dirty_sink.jpg",
  "tips": {
    "detected": {
      "surface": "porcelain sink",
      "stain": "limescale + grease"
    },
    "steps": [
      "Mix warm water with white vinegar (1:1 ratio)",
      "Apply baking soda paste on greasy areas",
      "Scrub with soft sponge in circular motions",
      "Rinse thoroughly with warm water",
      "Dry with microfiber cloth to prevent water spots"
    ],
    "warnings": [
      "Do not mix vinegar with bleach (toxic fumes)",
      "Ventilate the area well",
      "Wear gloves to protect skin"
    ],
    "estimatedMinutes": 15,
    "difficulty": 2
  }
}
```

### 3. Cost Monitoring Dashboard

**Request:**
```bash
GET /ai/costs?days=7
Authorization: Bearer {jwt_token}
```

**Response (200 OK):**
```json
{
  "total_cost_usd": 45.32,
  "total_requests": 1250,
  "cache_hit_rate_pct": 58.4,
  "cost_by_model": [
    {"model": "anthropic/claude-3.5-sonnet", "cost": 28.50, "count": 120},
    {"model": "anthropic/claude-3-haiku", "cost": 16.82, "count": 400},
    {"model": "cached", "cost": 0.0, "count": 730}
  ],
  "daily_breakdown": [
    {"date": "2025-11-11", "cost": 8.20, "requests": 180},
    {"date": "2025-11-12", "cost": 6.45, "requests": 175},
    {"date": "2025-11-13", "cost": 5.90, "requests": 170}
  ],
  "fallback_stats": {
    "tier_1": 120,
    "tier_2": 400,
    "tier_3": 0,
    "tier_4": 730
  },
  "cache_stats": {
    "keyspace_hits": 730,
    "keyspace_misses": 520,
    "total_keys": 1840
  },
  "period_days": 7
}
```

## Performance Metrics

### Response Time Targets

```yaml
ai_planner:
  p50: < 1.5s
  p95: < 3.0s
  p99: < 5.0s

vision_tips:
  p50: < 2.0s
  p95: < 4.0s
  p99: < 6.0s

cache_hit:
  p50: < 10ms
  p95: < 50ms
  p99: < 100ms

rule_based_fallback:
  p50: < 50ms
  p95: < 100ms
  p99: < 200ms
```

### Reliability Targets

```yaml
availability:
  tier_1_2_combined: 99.5% (OpenRouter uptime)
  tier_3_fallback: 99.99% (local Python execution)
  overall_system: 99.99% (with fallback)

error_rate:
  acceptable: < 0.1%
  critical_threshold: > 1%

cache_performance:
  hit_rate_month_1: 20-30%
  hit_rate_month_2: 40-50%
  hit_rate_month_3+: 55-65%
```

## Testing Strategy

### Unit Tests (`backend/tests/test_ai_client.py`)

- Mock OpenRouter success responses
- Test timeout handling (30s Tier 1, 15s Tier 2)
- Test HTTP error handling (500, 503, 429)
- Test 4-tier fallback progression
- Test cache hit/miss scenarios
- Test rule-based planner logic
- Test cost calculation accuracy
- Test response time performance

### Integration Tests

```bash
# Run all tests
pytest backend/tests/test_ai_client.py -v

# Run with coverage
pytest backend/tests/test_ai_client.py --cov=core.ai_client --cov-report=html

# Run performance tests
pytest backend/tests/test_ai_client.py -k performance
```

### Load Tests

```yaml
scenario_1_normal_load:
  families: 100
  concurrent_requests: 10
  duration: 5 minutes
  expected_success_rate: > 99%

scenario_2_peak_load:
  families: 500
  concurrent_requests: 50
  duration: 2 minutes
  expected_success_rate: > 95%

scenario_3_openrouter_outage:
  families: 100
  concurrent_requests: 10
  openrouter_available: false
  expected_tier_3_usage: 100%
  expected_success_rate: 100%
```

## Operational Runbooks

### Incident: High AI Costs

**Detection**: Slack alert "AI cost alert: $XXX exceeds weekly budget of $500"

**Investigation**:
1. Check `/ai/costs?days=7` dashboard
2. Identify cost spike in `daily_breakdown`
3. Check `cost_by_model` for unexpected Sonnet usage
4. Review `cache_hit_rate_pct` (should be >50%)

**Resolution**:
- If cache hit rate low: Review cache TTL settings
- If Sonnet overuse: Adjust model selection logic
- If legitimate spike: Increase weekly budget temporarily

### Incident: OpenRouter Outage

**Detection**: All Tier 1 and Tier 2 requests failing

**Expected Behavior**: Automatic fallback to Tier 3 (rule-based)

**Verification**:
1. Check `/ai/health` endpoint
2. Verify `fallback_stats` shows tier_3 usage
3. Test planner endpoint returns valid results

**No Action Required**: System continues operating with rule-based planner

### Incident: Redis Cache Down

**Detection**: Cache read/write errors in logs

**Expected Behavior**: Graceful degradation, AI calls still work

**Impact**: Higher AI costs due to no caching

**Resolution**:
1. Check Redis connection: `redis-cli ping`
2. Verify `REDIS_URL` environment variable
3. Restart Redis service if needed
4. Cache will automatically resume when Redis recovers

## Future Enhancements (Phase 2)

### Vision Enhancement
- Integrate GPT-4 Vision API for actual image analysis
- Add photo preprocessing (resize, compress)
- Support video frame analysis

### Voice NLU
- Implement STT (Speech-to-Text) via Whisper API
- Add intent parsing with slot extraction
- Support multi-language voice commands (NL/EN/DE/FR)

### Cost Optimization
- Implement request batching for multiple families
- Add model fine-tuning for cheaper inference
- Explore self-hosted LLM options (e.g., Llama 3)

### Advanced Caching
- Family-specific cache warming
- Predictive caching based on usage patterns
- Cache compression for storage efficiency

## Success Criteria

### Phase 1 (Week 2-3)

- ✅ 4-tier fallback system implemented
- ✅ All unit tests passing (>80% coverage)
- ✅ Cost monitoring dashboard operational
- ✅ Redis caching layer functional

### Phase 2 (Week 3-6)

- ⏳ Cache hit rate >50% after 30 days
- ⏳ Average cost <$100/week for 5K families
- ⏳ p95 response time <3s for planner
- ⏳ Zero critical incidents from AI failures

### Phase 3 (Month 3+)

- ⏳ Cache hit rate >60%
- ⏳ Annual cost <$15K (target achieved)
- ⏳ 99.99% availability with fallback
- ⏳ NPS >+45 for AI features

## References

- OpenRouter API Docs: https://openrouter.ai/docs
- Claude 3.5 Sonnet Pricing: https://www.anthropic.com/pricing
- Redis Caching Best Practices: https://redis.io/docs/manual/patterns/
- Executive Summary: `docs/research/EXECUTIVE_SUMMARY.md`
- PRD v2.1: `AI_Gezinsplanner_PRD_v2.1.md`

---

**Document Version**: 1.0
**Last Updated**: 2025-11-11
**Owner**: Backend Engineering Team
**Review Cycle**: Monthly
