import os
import logging
from typing import List, Union, Dict, Any
import httpx
from config import settings

logger = logging.getLogger(__name__)

async def broadcast_supabase_realtime(
    topics: Union[str, List[str]],
    event: str,
    payload: Dict[str, Any]
) -> bool:
    """
    Zero-latency, zero-DB-load Realtime Broadcast directly to Supabase Edge.
    Dispatches instant WebSockets to Admins, Riders, Kitchens, and Customers.
    """
    supabase_url = settings.NEXT_PUBLIC_SUPABASE_URL or os.getenv("NEXT_PUBLIC_SUPABASE_URL", "https://bberzasmxwioxjynbuaf.supabase.co")
    anon_key = settings.NEXT_PUBLIC_SUPABASE_ANON_KEY or os.getenv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "")
    service_key = settings.SUPABASE_SERVICE_ROLE_KEY or os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    key = service_key or anon_key
    if not supabase_url or not key:
        return False

    if isinstance(topics, str):
        topics = [topics]

    messages = []
    for t in topics:
        clean_topic = t.strip()
        if not clean_topic.startswith("realtime:"):
            clean_topic = f"realtime:{clean_topic}"
        messages.append({
            "topic": clean_topic,
            "event": event,
            "payload": payload
        })

    endpoint = f"{supabase_url.rstrip('/')}/realtime/v1/api/broadcast"
    headers = {
        "apikey": key,
        "Content-Type": "application/json"
    }
    if key.startswith("eyJ"):
        headers["Authorization"] = f"Bearer {key}"

    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            resp = await client.post(endpoint, headers=headers, json={"messages": messages})
            if resp.status_code in (200, 201, 202):
                return True
            else:
                logger.warning(f"[SupabaseBroadcast] Non-200 response: {resp.status_code} - {resp.text}")
                return False
    except Exception as e:
        logger.warning(f"[SupabaseBroadcast] Error broadcasting to {topics}: {e}")
        return False
