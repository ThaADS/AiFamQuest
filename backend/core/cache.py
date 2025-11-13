"""
Redis caching layer for AI responses
Implements 60% target cache hit rate with 7-day TTL
"""
import os
import json
import hashlib
from typing import Optional, Dict, Any
from redis.asyncio import Redis, from_url
from redis.exceptions import RedisError

# Redis connection
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
_redis_client: Optional[Redis] = None

async def get_redis() -> Redis:
    """Get or create Redis connection"""
    global _redis_client
    if _redis_client is None:
        _redis_client = from_url(REDIS_URL, encoding="utf-8", decode_responses=True)
    return _redis_client

def cache_key(prompt: str, model: str, temperature: float) -> str:
    """Generate cache key from prompt + model + temperature"""
    key_str = f"{prompt}|{model}|{temperature}"
    return f"ai:cache:{hashlib.sha256(key_str.encode()).hexdigest()}"

async def get_cached_response(prompt: str, model: str, temperature: float) -> Optional[Dict[str, Any]]:
    """
    Retrieve cached AI response
    Returns None if not found or Redis error
    """
    try:
        redis = await get_redis()
        key = cache_key(prompt, model, temperature)
        cached = await redis.get(key)
        if cached:
            return json.loads(cached)
    except (RedisError, json.JSONDecodeError) as e:
        # Log error but don't crash
        print(f"Cache read error: {e}")
    return None

async def set_cached_response(
    prompt: str,
    model: str,
    temperature: float,
    response: Dict[str, Any],
    ttl_seconds: int = 604800  # 7 days default
) -> bool:
    """
    Cache AI response with TTL
    Returns True if successful, False otherwise
    """
    try:
        redis = await get_redis()
        key = cache_key(prompt, model, temperature)
        await redis.setex(key, ttl_seconds, json.dumps(response))
        return True
    except RedisError as e:
        # Log error but don't crash
        print(f"Cache write error: {e}")
        return False

async def invalidate_family_cache(family_id: str) -> int:
    """
    Invalidate all AI caches for a family (on settings change)
    Returns number of keys deleted
    """
    try:
        redis = await get_redis()
        # Family-specific cache invalidation pattern
        pattern = f"ai:cache:family:{family_id}:*"
        keys = []
        async for key in redis.scan_iter(match=pattern):
            keys.append(key)
        if keys:
            return await redis.delete(*keys)
        return 0
    except RedisError as e:
        print(f"Cache invalidation error: {e}")
        return 0

async def get_cache_stats() -> Dict[str, int]:
    """Get cache statistics"""
    try:
        redis = await get_redis()
        info = await redis.info("stats")
        return {
            "keyspace_hits": info.get("keyspace_hits", 0),
            "keyspace_misses": info.get("keyspace_misses", 0),
            "total_keys": await redis.dbsize()
        }
    except RedisError as e:
        print(f"Cache stats error: {e}")
        return {"keyspace_hits": 0, "keyspace_misses": 0, "total_keys": 0}

async def close_redis():
    """Close Redis connection (call on shutdown)"""
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
