import os
import time
import logging
from typing import Any, Optional, Union
from config import settings

try:
    import orjson
    def _json_dumps(obj: Any) -> str:
        return orjson.dumps(obj).decode("utf-8")
    def _json_loads(s: str) -> Any:
        return orjson.loads(s)
except ImportError:
    import json
    def _json_dumps(obj: Any) -> str:
        return json.dumps(obj, default=str)
    def _json_loads(s: str) -> Any:
        return json.loads(s)

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
                return _json_loads(val)
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
        serialized = _json_dumps(value)
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
    await invalidate_cache_pattern("product_detail:*")
    await invalidate_cache_pattern("categories:*")
    await invalidate_cache_pattern("banners:*")
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


# ─── Atomic Lua Script for Inventory Pre-Reservation ───────────────────────────
# KEYS[1] = Stock Key (e.g. stock:hub-209206:prod_123 or stock:global:prod_123)
# ARGV[1] = Requested Quantity
# ARGV[2] = Initial Stock if key does not exist yet (seed value from DB)
_ATOMIC_RESERVE_STOCK_LUA = """
local current = redis.call('get', KEYS[1])
if not current then
    if ARGV[2] and ARGV[2] ~= '' then
        current = tonumber(ARGV[2])
        redis.call('set', KEYS[1], current, 'EX', 86400)
    else
        return -2 -- Key missing and no seed provided
    end
else
    current = tonumber(current)
end

local requested = tonumber(ARGV[1])
if current >= requested then
    local remaining = current - requested
    redis.call('set', KEYS[1], remaining, 'KEEPTTL')
    return remaining
else
    return -1 -- Insufficient stock
end
"""

_ATOMIC_RELEASE_STOCK_LUA = """
local current = redis.call('get', KEYS[1])
if current then
    local updated = tonumber(current) + tonumber(ARGV[1])
    redis.call('set', KEYS[1], updated, 'KEEPTTL')
    return updated
end
return 0
"""


async def atomic_reserve_inventory(
    stock_key: str,
    requested_qty: int,
    initial_seed_stock: Optional[int] = None
) -> int:
    """
    Atomically pre-reserves inventory in Redis using an ACID Lua script.
    Returns:
      >= 0 : Remaining stock after successful deduction
        -1 : Insufficient stock
        -2 : Stock key uninitialized (caller should fallback to DB lock)
    If Redis is down or unavailable, returns -2 gracefully for DB fallback.
    """
    try:
        redis = await get_redis_connection()
    except Exception:
        return -2

    if not redis:
        return -2

    try:
        res = await redis.eval(
            _ATOMIC_RESERVE_STOCK_LUA,
            1,
            stock_key,
            str(requested_qty),
            str(initial_seed_stock) if initial_seed_stock is not None else ""
        )
        return int(res)
    except Exception as e:
        logger.warning(f"[Cache] Redis Lua inventory reservation notice for {stock_key}: {e}")
        return -2


async def release_reserved_inventory(stock_key: str, quantity_to_refund: int) -> int:
    """
    Atomically refunds pre-reserved stock in Redis if subsequent DB transaction fails.
    """
    try:
        redis = await get_redis_connection()
    except Exception:
        return 0

    if not redis:
        return 0

    try:
        res = await redis.eval(
            _ATOMIC_RELEASE_STOCK_LUA,
            1,
            stock_key,
            str(quantity_to_refund)
        )
        return int(res)
    except Exception as e:
        logger.warning(f"[Cache] Redis Lua inventory refund notice for {stock_key}: {e}")
        return 0


# Backward-compatible function aliases
get_cache = get_cached
set_cache = set_cached


