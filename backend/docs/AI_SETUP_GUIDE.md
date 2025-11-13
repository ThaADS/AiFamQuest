# FamQuest AI System Setup Guide

## Quick Start

This guide walks you through setting up the FamQuest AI system with 4-tier fallback, caching, and cost monitoring.

## Prerequisites

- Python 3.11+
- Redis 7.0+
- PostgreSQL 15+
- OpenRouter API key (https://openrouter.ai)

## Installation Steps

### 1. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Set Up Redis

**Option A: Local Redis (Development)**
```bash
# macOS
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis

# Windows
# Download from https://github.com/microsoftarchive/redis/releases
redis-server.exe
```

**Option B: Redis Cloud (Production)**
```bash
# Sign up at https://redis.com/try-free/
# Get connection string: redis://default:password@host:port
```

**Verify Redis:**
```bash
redis-cli ping
# Should return: PONG
```

### 3. Configure Environment Variables

Create `.env` file in `backend/` directory:

```bash
# Database
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/famquest

# AI Services
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxx

# Redis Cache
REDIS_URL=redis://localhost:6379/0

# Cost Monitoring
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx/yyy/zzz

# File Storage
MEDIA_DIR=./uploads
PUBLIC_BASE=http://localhost:8000

# Security
JWT_SECRET=your-secret-key-change-in-production
```

### 4. Run Database Migrations

```bash
# Apply all migrations including ai_usage_log table
alembic upgrade head
```

**Verify migration:**
```bash
# Connect to PostgreSQL
psql -U user -d famquest

# Check table exists
\dt ai_usage_log

# Should show:
#  Schema |     Name      | Type  | Owner
# --------+---------------+-------+-------
#  public | ai_usage_log  | table | user
```

### 5. Start the Server

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 6. Verify Installation

**Test health endpoint:**
```bash
curl http://localhost:8000/ai/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "services": {
    "openrouter": "configured",
    "redis": "configured"
  },
  "fallback_tiers": {
    "tier_1": "OpenRouter Claude Sonnet (primary)",
    "tier_2": "OpenRouter Claude Haiku (fallback)",
    "tier_3": "Rule-based planner (deterministic)",
    "tier_4": "Cached responses (Redis)"
  }
}
```

## Testing the AI System

### 1. Unit Tests

```bash
# Run all AI client tests
pytest backend/tests/test_ai_client.py -v

# Run with coverage
pytest backend/tests/test_ai_client.py --cov=core.ai_client --cov-report=html

# View coverage report
open htmlcov/index.html
```

**Expected output:**
```
test_call_openrouter_success PASSED
test_call_openrouter_timeout PASSED
test_call_openrouter_http_error PASSED
test_fallback_tier1_success PASSED
test_fallback_tier2_haiku PASSED
test_fallback_tier4_cache PASSED
test_planner_tier1_success PASSED
test_planner_tier3_rule_based PASSED
...
======================== 15 passed in 2.34s ========================
```

### 2. Integration Tests

**Test AI Planner (requires API key):**

```bash
# Create test user and get JWT token first
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@famquest.app",
    "password": "testpass123"
  }'

# Save token
export JWT_TOKEN="eyJ..."

# Test AI planner
curl -X POST http://localhost:8000/ai/plan \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "weekContext": {
      "familyMembers": [
        {"id": "uuid-noah", "name": "Noah", "age": 10, "role": "child"},
        {"id": "uuid-luna", "name": "Luna", "age": 8, "role": "child"}
      ],
      "tasks": [
        {"title": "Vaatwasser", "points": 10, "frequency": "daily"}
      ],
      "calendar": [],
      "constraints": {"maxTasksPerDay": 3}
    }
  }'
```

**Expected response:**
```json
{
  "weekPlan": [
    {
      "date": "2025-11-17",
      "tasks": [...]
    }
  ],
  "fairness": {
    "distribution": {...}
  }
}
```

### 3. Test Fallback Behavior

**Test Tier 3 fallback (without API key):**

```bash
# Temporarily remove API key
unset OPENROUTER_API_KEY

# Restart server and test
curl -X POST http://localhost:8000/ai/plan \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"weekContext": {...}}'

# Should still return valid plan using rule-based planner
```

## Monitoring and Debugging

### 1. View AI Costs

```bash
# Get cost metrics for last 7 days
curl http://localhost:8000/ai/costs?days=7 \
  -H "Authorization: Bearer $JWT_TOKEN"
```

**Response:**
```json
{
  "total_cost_usd": 12.45,
  "total_requests": 450,
  "cache_hit_rate_pct": 62.3,
  "cost_by_model": [
    {"model": "anthropic/claude-3.5-sonnet", "cost": 8.20, "count": 50},
    {"model": "anthropic/claude-3-haiku", "cost": 4.25, "count": 120},
    {"model": "cached", "cost": 0.0, "count": 280}
  ],
  "daily_breakdown": [...]
}
```

### 2. Check Redis Cache

```bash
# Connect to Redis
redis-cli

# View cache stats
INFO stats

# Check cached keys
KEYS ai:cache:*

# View specific cached response
GET ai:cache:abc123...

# Monitor cache operations in real-time
MONITOR
```

### 3. Check Database Logs

```sql
-- View recent AI usage
SELECT
  timestamp,
  model,
  endpoint,
  cost_usd,
  cache_hit,
  fallback_tier,
  response_time_ms
FROM ai_usage_log
ORDER BY timestamp DESC
LIMIT 20;

-- Weekly cost summary
SELECT
  DATE_TRUNC('week', timestamp) as week,
  SUM(cost_usd) as weekly_cost,
  COUNT(*) as requests,
  AVG(CASE WHEN cache_hit THEN 1 ELSE 0 END) as cache_hit_rate
FROM ai_usage_log
WHERE timestamp >= NOW() - INTERVAL '30 days'
GROUP BY week
ORDER BY week DESC;

-- Fallback tier distribution
SELECT
  fallback_tier,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as percentage
FROM ai_usage_log
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY fallback_tier
ORDER BY fallback_tier;
```

## Performance Tuning

### 1. Redis Optimization

**Edit redis.conf:**
```conf
# Increase max memory
maxmemory 2gb

# Eviction policy (remove least recently used keys)
maxmemory-policy allkeys-lru

# Enable RDB snapshots for persistence
save 900 1
save 300 10
save 60 10000

# Enable AOF for durability (optional)
appendonly yes
```

### 2. Cache TTL Tuning

**Adjust cache TTL in code:**

```python
# backend/core/cache.py

# Longer TTL for vision tips (change less frequently)
await set_cached_response(prompt, model, temperature, response, ttl_seconds=1209600)  # 14 days

# Shorter TTL for planner (family dynamics change)
await set_cached_response(prompt, model, temperature, response, ttl_seconds=259200)  # 3 days
```

### 3. Model Selection Strategy

**Adjust model usage in code:**

```python
# backend/core/ai_client.py

# For simple planning scenarios, prefer Haiku
if task_complexity < 0.5:
    model = MODEL_HAIKU  # 10x cheaper
else:
    model = MODEL_SONNET  # Higher quality
```

## Troubleshooting

### Issue: High AI Costs

**Symptom:** Slack alert "AI cost alert: $XXX exceeds weekly budget"

**Diagnosis:**
```bash
# Check cache hit rate
curl http://localhost:8000/ai/costs?days=7 | jq '.cache_hit_rate_pct'

# Should be >50% after week 1
```

**Solutions:**
1. If cache hit rate <30%: Check Redis connection
2. If Sonnet usage >20%: Review prompt complexity
3. If legitimate spike: Increase weekly budget in monitoring.py

### Issue: OpenRouter API Errors

**Symptom:** HTTP 429 (rate limit) or 503 (service unavailable)

**Diagnosis:**
```sql
SELECT error, COUNT(*)
FROM ai_usage_log
WHERE timestamp >= NOW() - INTERVAL '1 hour'
  AND error IS NOT NULL
GROUP BY error;
```

**Solutions:**
1. HTTP 429: Implement request queuing
2. HTTP 503: Fallback working correctly (check tier_3 usage)
3. HTTP 401: Check OPENROUTER_API_KEY

### Issue: Slow Response Times

**Symptom:** API responses >5s

**Diagnosis:**
```sql
SELECT
  endpoint,
  AVG(response_time_ms) as avg_ms,
  MAX(response_time_ms) as max_ms,
  COUNT(*) as requests
FROM ai_usage_log
WHERE timestamp >= NOW() - INTERVAL '1 hour'
GROUP BY endpoint;
```

**Solutions:**
1. If avg_ms >3000: Reduce timeout or prefer Haiku
2. If max_ms >10000: Check network latency to OpenRouter
3. Implement timeout warnings in application logs

### Issue: Redis Connection Failures

**Symptom:** Logs show "Cache read error" or "Cache write error"

**Diagnosis:**
```bash
# Test Redis connection
redis-cli ping

# Check Redis logs
tail -f /var/log/redis/redis-server.log
```

**Solutions:**
1. Verify REDIS_URL environment variable
2. Check Redis service status: `systemctl status redis`
3. Verify Redis authentication if using password
4. System continues working (graceful degradation)

## Production Deployment Checklist

### Pre-deployment

- [ ] Set strong JWT_SECRET
- [ ] Configure Redis with authentication
- [ ] Set up Slack webhook for cost alerts
- [ ] Configure file storage (S3 or CDN)
- [ ] Set PUBLIC_BASE to production domain
- [ ] Enable SSL/TLS for Redis connection
- [ ] Run database migrations on staging
- [ ] Load test with 1000 concurrent requests

### Deployment

- [ ] Deploy Redis (ElastiCache or Redis Cloud)
- [ ] Deploy PostgreSQL (RDS or managed service)
- [ ] Deploy FastAPI backend (ECS, App Engine, or K8s)
- [ ] Configure environment variables
- [ ] Run Alembic migrations
- [ ] Verify health endpoint
- [ ] Test AI planner endpoint
- [ ] Monitor first 100 requests

### Post-deployment

- [ ] Monitor cost dashboard daily for first week
- [ ] Check cache hit rate (should reach 50% by week 2)
- [ ] Set up CloudWatch/Datadog alerts
- [ ] Schedule weekly cost review meetings
- [ ] Review error logs for API failures
- [ ] Optimize prompts based on usage patterns

## Cost Management Best Practices

### Week 1-2: Monitoring Phase

- Check `/ai/costs` daily
- Target: <$150/week for 1K families
- Cache hit rate: 20-30% (warming up)

### Week 3-4: Optimization Phase

- Analyze high-cost requests
- Adjust model selection logic
- Target: <$100/week for 1K families
- Cache hit rate: 40-50%

### Month 2+: Steady State

- Weekly cost reviews
- Target: <$80/week for 5K families
- Cache hit rate: 55-65%
- Alert threshold: $500/week

## Support and Resources

- Architecture Documentation: `backend/docs/ai_architecture.md`
- PRD Reference: `AI_Gezinsplanner_PRD_v2.1.md`
- Executive Summary: `docs/research/EXECUTIVE_SUMMARY.md`
- OpenRouter Docs: https://openrouter.ai/docs
- Redis Best Practices: https://redis.io/docs/manual/patterns/

## Questions?

Contact: backend-team@famquest.app

---

**Last Updated**: 2025-11-11
**Version**: 1.0
