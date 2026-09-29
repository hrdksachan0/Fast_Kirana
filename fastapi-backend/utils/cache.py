import os
import json
import time
import logging
from typing import Any, Optional, Union
from config import settings

logger = logging.getLogger(__name__)

# In-Memory Cache Fallback Storage
_LOCAL_CACHE = {}
_LOCAL_CACHE_EXPIRY = {}
_MAX_LOCAL_ENTRIES = 5000

# Redis Client Instance
_redis_client = None
_redis_initialized = False


async def get_redis_connection():
    """
    Asynchronously initialize or return active Redis connection pool.
    Supports Upstash Redis (rediss://) or standard redis (redis://).
    """
    global _redis_client, _redis_initialized
    if _redis_initialized:
        return _redis_client

    redis_url = settings.REDIS_URL or os.getenv("REDIS_URL", "")
    if redis_url:
        try:
            import redis.asyncio as aioredis
            _redis_client = aioredis.from_url(
                redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_timeout=2.0,
                socket_connect_timeout=2.0
            )
            # Test ping
            await _redis_client.ping()
            logger.info("[Cache] Connected successfully to Redis server.")
        except Exception as e:
            logger.warning(f"[Cache] Redis connection failed ({e}). Falling back to fast In-Memory cache.")
            _redis_client = None
    else:
        _redis_client = None

    _redis_initialized = True
    return _redis_client


async def get_cached(key: str) -> Optional[Any]:
    """
    Retrieve cached data by key.
    Checks Redis first if available, then fallback memory cache.
    """
    redis = await get_redis_connection()
    if redis:
        try:
            val = await redis.get(key)
            if val is not None:
                return json.loads(val)
        except Exception as e:
            logger.debug(f"[Cache] Redis get error: {e}")

    # Fallback to local memory cache
    now = time.time()
    if key in _LOCAL_CACHE:
        if _LOCAL_CACHE_EXPIRY.get(key, 0) > now:
            return _LOCAL_CACHE[key]
        else:
            _LOCAL_CACHE.pop(key, None)
            _LOCAL_CACHE_EXPIRY.pop(key, None)

    return None


async def set_cached(key: str, value: Any, ttl_seconds: int = 60) -> bool:
    """
    Store serialized JSON value in cache with TTL expiry.
    """
    serialized = None
    try:
        serialized = json.dumps(value, default=str)
    except Exception as e:
        logger.debug(f"[Cache] JSON serialization failed: {e}")
        return False

    redis = await get_redis_connection()
    if redis:
        try:
            await redis.setex(key, ttl_seconds, serialized)
            return True
        except Exception as e:
            logger.debug(f"[Cache] Redis set error: {e}")

    # Fallback to local memory cache
    now = time.time()
    if len(_LOCAL_CACHE) > _MAX_LOCAL_ENTRIES:
        # Prune expired keys
        expired_keys = [k for k, exp in _LOCAL_CACHE_EXPIRY.items() if exp <= now]
        for k in expired_keys:
            _LOCAL_CACHE.pop(k, None)
            _LOCAL_CACHE_EXPIRY.pop(k, None)
        # If still full, pop 20% oldest entries
        if len(_LOCAL_CACHE) > _MAX_LOCAL_ENTRIES:
            for k in list(_LOCAL_CACHE.keys())[:1000]:
                _LOCAL_CACHE.pop(k, None)
                _LOCAL_CACHE_EXPIRY.pop(k, None)

    _LOCAL_CACHE[key] = value
    _LOCAL_CACHE_EXPIRY[key] = now + ttl_seconds
    return True


async def delete_cached(key: str) -> bool:
    """
    Remove key from cache.
    """
    redis = await get_redis_connection()
    if redis:
        try:
            await redis.delete(key)
        except Exception:
            pass

    _LOCAL_CACHE.pop(key, None)
    _LOCAL_CACHE_EXPIRY.pop(key, None)
    return True


async def invalidate_cache_pattern(pattern: str) -> int:
    """
    Invalidate all keys matching a prefix or wildcard pattern (e.g. 'catalog:*', 'search:*').
    """
    count = 0
    redis = await get_redis_connection()
    if redis:
        try:
            keys = await redis.keys(pattern)
            if keys:
                await redis.delete(*keys)
                count += len(keys)
        except Exception as e:
            logger.debug(f"[Cache] Redis pattern delete error: {e}")

    # Invalidate in local memory cache
    prefix = pattern.replace("*", "")
    to_delete = [k for k in list(_LOCAL_CACHE.keys()) if k.startswith(prefix)]
    for k in to_delete:
        _LOCAL_CACHE.pop(k, None)
        _LOCAL_CACHE_EXPIRY.pop(k, None)
        count += 1

    return count


async def invalidate_catalog_cache():
    """
    Convenience method to clear catalog, product, category, and search caches after modifications.
    """
    await invalidate_cache_pattern("catalog:*")
    await invalidate_cache_pattern("products:*")
    await invalidate_cache_pattern("categories:*")
    await invalidate_cache_pattern("search:*")
    logger.info("[Cache] Catalog cache invalidated across Redis & Memory.")


async def acquire_lock(key: str, ttl_seconds: int = 3600) -> bool:
    """
    Acquire an atomic distributed lock using Redis SET NX EX.
    Guarantees that across multiple processes and servers, only 1 caller can acquire
    the lock for the given duration. Returns True if acquired, False otherwise.
    Falls back gracefully to local memory cache if Redis is not connected.
    """
    redis = await get_redis_connection()
    if redis:
        try:
            # set(name, value, nx=True, ex=ttl_seconds) returns True if set, None if already exists
            res = await redis.set(key, "1", nx=True, ex=ttl_seconds)
            return bool(res)
        except Exception as e:
            logger.warning(f"[Cache] Redis acquire_lock error for {key}: {e}")

    # Fallback to local memory lock
    now = time.time()
    if key in _LOCAL_CACHE:
        if _LOCAL_CACHE_EXPIRY.get(key, 0) > now:
            return False
        else:
            _LOCAL_CACHE.pop(key, None)
            _LOCAL_CACHE_EXPIRY.pop(key, None)

    _LOCAL_CACHE[key] = "1"
    _LOCAL_CACHE_EXPIRY[key] = now + ttl_seconds
    return True

