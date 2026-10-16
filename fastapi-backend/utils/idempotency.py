import hashlib
import time
import threading
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Tuple
from fastapi import HTTPException

logger = logging.getLogger(__name__)

# Thread-safe in-memory idempotency locks
_lock = threading.Lock()
_memory_locks: Dict[str, Dict[str, Any]] = {}


def _cleanup_expired():
    now = time.time()
    expired_keys = [k for k, v in _memory_locks.items() if v.get("expires_at", 0) <= now]
    for k in expired_keys:
        _memory_locks.pop(k, None)


def compute_request_fingerprint(
    items: Any = None,
    address_id: Optional[str] = None,
    payment_method: Optional[str] = None,
    coupon_code: Optional[str] = None,
    tip_amount: Optional[float] = None,
    user_id: Optional[str] = None,
    **kwargs
) -> str:
    """
    Compute a deterministic canonical SHA-256 fingerprint of the order creation request payload.
    Used to detect and reject idempotency key reuse with mismatched payloads.
    Supports both (items, ...) and (user_id, items, ...) signatures.
    """
    if isinstance(items, str) and (address_id is None or isinstance(address_id, list)):
        user_id = items
        items = address_id or []
        address_id = payment_method
        payment_method = coupon_code
        coupon_code = tip_amount
        tip_amount = kwargs.get("tip_amount") or 0.0

    if user_id is None:
        user_id = kwargs.get("user_id")

    normalized_items = []
    for it in (items or []):
        if not isinstance(it, dict):
            continue
        prod = it.get("product") if isinstance(it.get("product"), dict) else {}
        pid = str(prod.get("id") or it.get("productId") or it.get("id") or "")
        qty = int(it.get("quantity") or 1)
        var_name = str(it.get("selectedVariant") or "")
        price = float(it.get("price") or 0.0)
        normalized_items.append({"pid": pid, "var": var_name, "qty": qty, "price": round(price, 2)})

    normalized_items.sort(key=lambda x: (x["pid"], x["var"]))
    payload = {
        "user_id": str(user_id or ""),
        "items": normalized_items,
        "address": str(address_id or ""),
        "payment": str(payment_method or ""),
        "coupon": str(coupon_code or "").upper().strip(),
        "tip": round(float(tip_amount or 0.0), 2)
    }
    raw = json.dumps(payload, sort_keys=True)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def generate_order_cart_signature(
    buyer_id: str,
    items: list,
    address_id: Optional[str] = None,
    payment_method: Optional[str] = None
) -> str:
    """
    Generate a deterministic SHA256 cart signature for order idempotency fallback.
    Combines buyer ID, sorted items (productId:variant:qty), address, and payment method.
    """
    normalized_items = []
    for it in (items or []):
        if not isinstance(it, dict):
            continue
        prod = it.get("product") if isinstance(it.get("product"), dict) else {}
        pid = prod.get("id") or it.get("productId") or it.get("id") or ""
        qty = it.get("quantity") or 1
        var_name = it.get("selectedVariant") or ""
        normalized_items.append(f"{pid}:{var_name}:{qty}")

    normalized_items.sort()
    items_str = "|".join(normalized_items)
    raw = f"{str(buyer_id).strip()}#{items_str}#{address_id or 'STORE_PICKUP'}#{payment_method or 'COD'}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]


def get_scoped_idempotency_key(key: str, user_id: Optional[str] = None, operation: str = "checkout") -> str:
    """
    Scope idempotency key by verified buyer ID and operation namespace.
    Prevents cross-user replay or collision when clients provide raw keys.
    """
    uid = str(user_id).strip() if user_id else "anon"
    op = str(operation).strip() if operation else "checkout"
    clean_k = str(key).strip()
    return f"{uid}:{op}:{clean_k}"


def acquire_idempotency_lock(
    key: str,
    ttl_seconds: int = 60,
    user_id: Optional[str] = None,
    request_hash: Optional[str] = None
) -> Tuple[bool, bool, Optional[dict]]:
    """
    Process-local thread-safe idempotency lock.
    """
    with _lock:
        _cleanup_expired()
        scoped_key = get_scoped_idempotency_key(key, user_id)
        now = time.time()

        entry = _memory_locks.get(scoped_key)
        if entry and entry.get("expires_at", 0) > now:
            rec_uid = entry.get("userId")
            if rec_uid and user_id and str(rec_uid) != str(user_id):
                raise HTTPException(status_code=403, detail="Forbidden: Idempotency key belongs to another user")
            rec_hash = entry.get("requestHash")
            if rec_hash and request_hash and rec_hash != request_hash:
                raise HTTPException(status_code=409, detail="Idempotency key already used with different request payload")
            if entry.get("status") == "PROCESSING":
                return True, True, None
            return True, False, entry.get("response")

        _memory_locks[scoped_key] = {
            "status": "PROCESSING",
            "userId": user_id,
            "requestHash": request_hash,
            "expires_at": now + ttl_seconds
        }
        return False, False, None


def save_idempotency_response(
    key: str,
    response: dict,
    ttl_seconds: int = 120,
    user_id: Optional[str] = None,
    request_hash: Optional[str] = None
) -> None:
    with _lock:
        scoped_key = get_scoped_idempotency_key(key, user_id)
        now = time.time()
        _memory_locks[scoped_key] = {
            "status": "COMPLETED",
            "userId": user_id,
            "requestHash": request_hash,
            "response": response,
            "expires_at": now + ttl_seconds
        }


def release_idempotency_lock(key: str, user_id: Optional[str] = None, operation: str = "checkout") -> None:
    with _lock:
        scoped_key = get_scoped_idempotency_key(key, user_id, operation)
        _memory_locks.pop(scoped_key, None)
        _memory_locks.pop(key, None)


async def acquire_idempotency_lock_async(
    key: str,
    ttl_seconds: int = 60,
    db: Any = None,
    user_id: Optional[str] = None,
    request_hash: Optional[str] = None,
    operation: str = "checkout"
) -> Tuple[bool, bool, Optional[dict]]:
    """
    Distributed atomic lock using Redis SET NX EX across server instances,
    with durable PostgreSQL/database persistence independent of Redis restarts/outages,
    and scoped by verified buyer and operation to prevent cross-user replay.
    """
    scoped_key = get_scoped_idempotency_key(key, user_id, operation)
    redis_key = f"idempotency:order:{scoped_key}"
    redis_acquired = False
    now = time.time()

    # ── 1. DISTRIBUTED REDIS LAYER ──
    try:
        from utils.cache import get_redis_connection, _json_dumps, _json_loads
        redis = await get_redis_connection()
        if redis:
            cached_raw = await redis.get(redis_key)
            if cached_raw:
                cached_data = _json_loads(cached_raw)
                if isinstance(cached_data, dict):
                    # Verify ownership
                    rec_uid = cached_data.get("userId")
                    if rec_uid and user_id and str(rec_uid) != str(user_id):
                        raise HTTPException(status_code=403, detail="Forbidden: Idempotency key belongs to another user")

                    # Check expiry
                    exp = cached_data.get("expiresAt")
                    if exp and float(exp) < now:
                        # Expired record -> proceed to re-acquire
                        pass
                    else:
                        # Verify request fingerprint
                        rec_hash = cached_data.get("requestHash")
                        if rec_hash and request_hash and rec_hash != request_hash:
                            raise HTTPException(status_code=409, detail="Idempotency key already used with different request payload")
                        if cached_data.get("status") == "COMPLETED" and "response" in cached_data:
                            return True, False, cached_data.get("response")
                        elif cached_data.get("status") == "PROCESSING":
                            return True, True, None

            # Attempt atomic SET NX EX
            proc_val = _json_dumps({
                "status": "PROCESSING",
                "userId": user_id,
                "requestHash": request_hash,
                "created_at": now,
                "expiresAt": now + ttl_seconds
            })
            acquired = await redis.set(redis_key, proc_val, nx=True, ex=ttl_seconds)
            if not acquired:
                # Key already exists in Redis: concurrent worker acquired
                return True, True, None

            redis_acquired = True
            # Directly register ownership in memory lock without double-acquiring
            with _lock:
                _memory_locks[scoped_key] = {
                    "status": "PROCESSING",
                    "userId": user_id,
                    "requestHash": request_hash,
                    "expires_at": now + ttl_seconds
                }
    except HTTPException:
        raise
    except Exception:
        # Redis failure/restart/outage: Fall back gracefully to local mutex & durable database
        pass

    # ── 2. PROCESS MUTEX (Used if Redis is absent or failed) ──
    if not redis_acquired:
        with _lock:
            _cleanup_expired()
            entry = _memory_locks.get(scoped_key)
            if entry and entry.get("expires_at", 0) > now:
                rec_uid = entry.get("userId")
                if rec_uid and user_id and str(rec_uid) != str(user_id):
                    raise HTTPException(status_code=403, detail="Forbidden: Idempotency key belongs to another user")
                rec_hash = entry.get("requestHash")
                if rec_hash and request_hash and rec_hash != request_hash:
                    raise HTTPException(status_code=409, detail="Idempotency key already used with different request payload")
                if entry.get("status") == "PROCESSING":
                    return True, True, None
                return True, False, entry.get("response")

            _memory_locks[scoped_key] = {
                "status": "PROCESSING",
                "userId": user_id,
                "requestHash": request_hash,
                "expires_at": now + ttl_seconds
            }

    # ── 3. DURABLE DATABASE LOCKING (Independent of Redis, survives restarts) ──
    if db is not None:
        try:
            from models import IdempotencyRecord
            from sqlalchemy.future import select
            now_dt = datetime.utcnow()
            stmt = select(IdempotencyRecord).where(
                (IdempotencyRecord.key == scoped_key) | (IdempotencyRecord.key == key)
            )
            res = await db.execute(stmt)
            record = res.scalars().first()

            if record:
                # Check ownership
                if record.userId and user_id and str(record.userId) != str(user_id):
                    raise HTTPException(status_code=403, detail="Forbidden: Idempotency key belongs to another user")

                # Check fingerprint (active unexpired records reject payload mismatch; expired records permit takeover)
                if record.expiresAt and record.expiresAt >= now_dt:
                    if record.requestHash and request_hash and record.requestHash != request_hash:
                        raise HTTPException(status_code=409, detail="Idempotency key already used with different request payload")

                if record.status == "COMPLETED":
                    # Check expiry: completed records older than expiresAt do not replay indefinitely
                    if record.expiresAt and record.expiresAt < now_dt:
                        from sqlalchemy import update
                        stmt_takeover = (
                            update(IdempotencyRecord)
                            .where(
                                IdempotencyRecord.key == record.key,
                                IdempotencyRecord.expiresAt < now_dt
                            )
                            .values(
                                status="PROCESSING",
                                userId=user_id,
                                requestHash=request_hash,
                                response=None,
                                orderId=None,
                                expiresAt=now_dt + timedelta(seconds=ttl_seconds)
                            )
                        )
                        takeover_res = await db.execute(stmt_takeover)
                        if getattr(takeover_res, "rowcount", 0) > 0:
                            await db.flush()
                            return False, False, None
                        else:
                            return True, True, None

                    cached = record.response
                    if isinstance(cached, str):
                        try:
                            cached = json.loads(cached)
                        except Exception:
                            pass
                    return True, False, cached or {}

                elif record.status == "PROCESSING":
                    if record.expiresAt > now_dt:
                        return True, True, None
                    else:
                        # Expired lock: take over ownership atomically
                        from sqlalchemy import update
                        stmt_takeover = (
                            update(IdempotencyRecord)
                            .where(
                                IdempotencyRecord.key == record.key,
                                IdempotencyRecord.expiresAt < now_dt
                            )
                            .values(
                                status="PROCESSING",
                                userId=user_id,
                                requestHash=request_hash,
                                expiresAt=now_dt + timedelta(seconds=ttl_seconds)
                            )
                        )
                        takeover_res = await db.execute(stmt_takeover)
                        if getattr(takeover_res, "rowcount", 0) > 0:
                            await db.flush()
                            return False, False, None
                        else:
                            return True, True, None
            else:
                try:
                    dialect_name = ""
                    try:
                        bind = db.get_bind()
                        dialect_name = bind.dialect.name if bind else ""
                    except Exception:
                        pass

                    new_rec = IdempotencyRecord(
                        key=scoped_key,
                        userId=user_id,
                        requestHash=request_hash,
                        status="PROCESSING",
                        createdAt=now_dt,
                        expiresAt=now_dt + timedelta(seconds=ttl_seconds)
                    )
                    if dialect_name == "sqlite":
                        db.add(new_rec)
                        await db.flush()
                    else:
                        async with db.begin_nested():
                            db.add(new_rec)
                            await db.flush()
                    return False, False, None
                except Exception:
                    # Concurrently inserted by another worker; check record state
                    try:
                        stmt2 = select(IdempotencyRecord).where(
                            (IdempotencyRecord.key == scoped_key) | (IdempotencyRecord.key == key)
                        )
                        res2 = await db.execute(stmt2)
                        rec2 = res2.scalars().first()
                        if rec2:
                            if rec2.userId and user_id and str(rec2.userId) != str(user_id):
                                raise HTTPException(status_code=403, detail="Forbidden: Idempotency key belongs to another user")
                            if rec2.requestHash and request_hash and rec2.requestHash != request_hash:
                                raise HTTPException(status_code=409, detail="Idempotency key already used with different request payload")
                            if rec2.status == "COMPLETED":
                                if rec2.expiresAt and rec2.expiresAt < now_dt:
                                    return True, True, None
                                cached = rec2.response
                                if isinstance(cached, str):
                                    try:
                                        cached = json.loads(cached)
                                    except Exception:
                                        pass
                                return True, False, cached or {}
                    except HTTPException:
                        raise
                    except Exception:
                        pass
                    return True, True, None
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"[Idempotency] Database locking error: {e}")
            raise HTTPException(status_code=503, detail="Idempotency lock service temporarily unavailable")

    return False, False, None


async def record_idempotency_result_db_async(
    key: str,
    response: dict,
    ttl_seconds: int = 86400,
    db: Any = None,
    user_id: Optional[str] = None,
    request_hash: Optional[str] = None,
    order_id: Optional[str] = None,
    operation: str = "checkout"
) -> None:
    """
    Persist the completed idempotency record into the durable database transaction.
    Must be called BEFORE db.commit(). Does NOT publish to Redis or local cache
    so uncommitted orders are never observable by other requests.
    """
    if db is None:
        return

    scoped_key = get_scoped_idempotency_key(key, user_id, operation)
    resp_obj = response
    if isinstance(resp_obj, str):
        try:
            resp_obj = json.loads(resp_obj)
        except Exception:
            pass
    oid = order_id or (response.get("id") if isinstance(response, dict) else None) or ((response.get("order") if isinstance(response, dict) else {}) or {}).get("id")
    now_dt = datetime.utcnow()
    exp_dt = now_dt + timedelta(seconds=ttl_seconds)

    from models import IdempotencyRecord
    from sqlalchemy.future import select
    stmt = select(IdempotencyRecord).where(
        (IdempotencyRecord.key == scoped_key) | (IdempotencyRecord.key == key)
    )
    res = await db.execute(stmt)
    record = res.scalars().first()

    if record:
        record.status = "COMPLETED"
        record.response = resp_obj
        record.orderId = oid
        record.userId = user_id or record.userId
        record.requestHash = request_hash or record.requestHash
        record.expiresAt = exp_dt
    else:
        new_rec = IdempotencyRecord(
            key=scoped_key,
            userId=user_id,
            requestHash=request_hash,
            status="COMPLETED",
            response=resp_obj,
            orderId=oid,
            createdAt=now_dt,
            expiresAt=exp_dt
        )
        db.add(new_rec)
    await db.flush()


async def publish_idempotency_cache_async(
    key: str,
    response: dict,
    ttl_seconds: int = 86400,
    user_id: Optional[str] = None,
    request_hash: Optional[str] = None,
    order_id: Optional[str] = None,
    operation: str = "checkout"
) -> None:
    """
    Publish completed idempotency result to Redis and local memory cache.
    MUST be called ONLY after db.commit() successfully commits the business order!
    """
    scoped_key = get_scoped_idempotency_key(key, user_id, operation)
    redis_key = f"idempotency:order:{scoped_key}"
    oid = order_id or response.get("id") or (response.get("order") or {}).get("id")

    # 1. Redis Acceleration Layer
    try:
        from utils.cache import get_redis_connection, _json_dumps
        redis = await get_redis_connection()
        if redis:
            payload = _json_dumps({
                "status": "COMPLETED",
                "userId": user_id,
                "requestHash": request_hash,
                "orderId": oid,
                "response": response,
                "expiresAt": time.time() + ttl_seconds
            })
            await redis.set(redis_key, payload, ex=ttl_seconds)
    except Exception:
        pass

    # 2. Local In-Memory Cache
    save_idempotency_response(key, response, ttl_seconds, user_id=user_id, request_hash=request_hash)


async def save_idempotency_response_async(
    key: str,
    response: dict,
    ttl_seconds: int = 86400,
    db: Any = None,
    user_id: Optional[str] = None,
    request_hash: Optional[str] = None,
    order_id: Optional[str] = None,
    operation: str = "checkout",
    publish_cache: bool = True
) -> None:
    """
    Durable record + cache publisher helper.
    When db is provided and publish_cache=False, stages DB record only.
    """
    if db is not None:
        await record_idempotency_result_db_async(
            key, response, ttl_seconds, db=db, user_id=user_id,
            request_hash=request_hash, order_id=order_id, operation=operation
        )
    if publish_cache or db is None:
        await publish_idempotency_cache_async(
            key, response, ttl_seconds, user_id=user_id,
            request_hash=request_hash, order_id=order_id, operation=operation
        )


async def release_idempotency_lock_async(
    key: str,
    db: Any = None,
    user_id: Optional[str] = None,
    operation: str = "checkout"
) -> None:
    """
    Release distributed, durable DB, & local idempotency lock early if order creation fails before DB commit.
    """
    scoped_key = get_scoped_idempotency_key(key, user_id, operation)
    redis_key = f"idempotency:order:{scoped_key}"
    legacy_redis_key = f"idempotency:{operation}:{user_id or 'anon'}:{key}"
    try:
        from utils.cache import get_redis_connection
        redis = await get_redis_connection()
        if redis:
            await redis.delete(redis_key, legacy_redis_key)
    except Exception:
        pass

    if db is not None:
        try:
            from models import IdempotencyRecord
            from sqlalchemy import delete
            stmt = delete(IdempotencyRecord).where(
                (IdempotencyRecord.key == scoped_key) | (IdempotencyRecord.key == key),
                IdempotencyRecord.status == "PROCESSING"
            )
            if user_id:
                stmt = stmt.where(IdempotencyRecord.userId == user_id)
            await db.execute(stmt)
            await db.flush()
        except Exception:
            pass

    release_idempotency_lock(key, user_id=user_id, operation=operation)
