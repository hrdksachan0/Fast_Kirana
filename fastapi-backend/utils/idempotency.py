import hashlib
import time
import threading
from typing import Dict, Any, Optional, Tuple

# Thread-safe in-memory idempotency locks
_lock = threading.Lock()
_memory_locks: Dict[str, Dict[str, Any]] = {}


def _cleanup_expired():
    now = time.time()
    expired_keys = [k for k, v in _memory_locks.items() if v.get("expires_at", 0) <= now]
    for k in expired_keys:
        _memory_locks.pop(k, None)


def generate_order_cart_signature(
    buyer_id: str,
    items: list,
    address_id: Optional[str] = None,
    payment_method: Optional[str] = None
) -> str:
    """
    Generate a deterministic SHA256 cart signature for order idempotency.
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


def acquire_idempotency_lock(key: str, ttl_seconds: int = 60) -> Tuple[bool, bool, Optional[dict]]:
    """
    Attempt to acquire an atomic lock for order creation.
    Returns: (is_duplicate: bool, is_processing: bool, cached_response: Optional[dict])
    """
    with _lock:
        _cleanup_expired()
        full_key = f"idempotency:order:{key}"
        now = time.time()

        entry = _memory_locks.get(full_key)
        if entry and entry.get("expires_at", 0) > now:
            if entry.get("status") == "PROCESSING":
                return True, True, None
            return True, False, entry.get("response")

        _memory_locks[full_key] = {
            "status": "PROCESSING",
            "expires_at": now + ttl_seconds
        }
        return False, False, None


def save_idempotency_response(key: str, response: dict, ttl_seconds: int = 120) -> None:
    """
    Cache the successful order creation response for subsequent replay attempts.
    """
    with _lock:
        full_key = f"idempotency:order:{key}"
        now = time.time()
        _memory_locks[full_key] = {
            "status": "COMPLETED",
            "response": response,
            "expires_at": now + ttl_seconds
        }


def release_idempotency_lock(key: str) -> None:
    """
    Release an idempotency lock early if order creation fails before DB commit.
    """
    with _lock:
        full_key = f"idempotency:order:{key}"
        _memory_locks.pop(full_key, None)
