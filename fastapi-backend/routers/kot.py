from fastapi import APIRouter, HTTPException, status, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import time
import json
import logging
import httpx

from database import get_db
from models import Order
from config import settings
from routers.websockets import manager

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Kitchen & KOT Thermal Print"])

recent_broadcast_timestamps: Dict[str, float] = {}


class KotBroadcastRequest(BaseModel):
    orderId: str
    readableId: Optional[str] = None
    restaurantId: Optional[str] = None
    kotText: Optional[str] = None
    items: Optional[List[Dict[str, Any]]] = None
    notes: Optional[str] = None
    customerName: Optional[str] = None
    deliveryMethod: Optional[str] = None
    shopName: Optional[str] = None
    printedAt: Optional[str] = None
    manual: Optional[bool] = None
    source: Optional[str] = None


@router.post("/kot-broadcast")
@router.post("/api/kot-broadcast")
async def broadcast_kot(
    req: KotBroadcastRequest,
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    if not req.orderId:
        raise HTTPException(status_code=400, detail="orderId is required")

    clean_id = req.orderId.strip().lstrip("#")
    clean_readable = (req.readableId or "").strip().lstrip("#")
    import re
    base_readable = re.sub(r"-[GR\d]+$", "", clean_readable, flags=re.IGNORECASE) if clean_readable else ""
    now = time.time()

    # 🛡️ Legacy Checkout Auto-KOT Interceptor:
    # Do NOT trigger kitchen prints from automated customer checkouts!
    # Only manual dispatch from Admin Orders Tab, Kitchen Console, or authorized Staff is permitted.
    header_role = (request.headers.get("x-user-role") or "").upper()
    header_phone = request.headers.get("x-user-phone") or ""
    is_admin_or_staff = header_role in ["ADMIN", "RESTAURANT_OWNER", "CHEF", "SUPER_ADMIN", "SUPERADMIN"] or "8112849854" in header_phone
    is_manual_admin_dispatch = bool(
        req.manual is True or
        req.source in ["orders_tab", "admin_console", "kitchen_console", "orders_tab_fallback"] or
        (req.kotText and "FASTKIRANA KOT" in req.kotText)
    )

    if not is_admin_or_staff and not is_manual_admin_dispatch:
        logger.info(f"[KOT Broadcast API] 🛡️ Ignored checkout auto-KOT for Order #{clean_readable or clean_id}")
        return {"success": True, "ignored": True, "reason": "Auto-KOT on checkout disabled"}

    # Dynamic debounce window: 2s for manual admin dispatches, 10s for others
    cooldown_window = 2.0 if is_manual_admin_dispatch else 10.0
    last_broadcast = max(
        recent_broadcast_timestamps.get(clean_id, 0),
        recent_broadcast_timestamps.get(clean_readable, 0) if clean_readable else 0,
        recent_broadcast_timestamps.get(base_readable, 0) if (base_readable and base_readable != "FK") else 0
    )

    if last_broadcast > 0 and (now - last_broadcast) < cooldown_window:
        logger.info(f"[KOT Broadcast] Deduplicated order #{clean_readable or clean_id}")
        return {"success": True, "orderId": clean_id, "deduped": True}

    recent_broadcast_timestamps[clean_id] = now
    if clean_readable:
        recent_broadcast_timestamps[clean_readable] = now
    if base_readable and base_readable != "FK":
        recent_broadcast_timestamps[base_readable] = now

    target_restaurant_id = req.restaurantId
    if not target_restaurant_id and clean_id:
        try:
            stmt = select(Order.restaurantId).where(Order.id == clean_id)
            res = await db.execute(stmt)
            rest_id = res.scalar_one_or_none()
            if rest_id:
                target_restaurant_id = rest_id
        except Exception as e:
            logger.warning(f"Failed to lookup order restaurantId: {e}")

    payload = {
        "orderId": clean_id,
        "readableId": clean_readable or clean_id,
        "restaurantId": target_restaurant_id,
        "kotText": req.kotText,
        "items": req.items,
        "notes": req.notes,
        "customerName": req.customerName,
        "deliveryMethod": req.deliveryMethod or "DELIVERY",
        "shopName": req.shopName,
        "printedAt": req.printedAt,
        "manual": req.manual,
        "source": req.source,
        "timestamp": int(now * 1000)
    }

    # 1. Enqueue to PostgreSQL table kitchen_kot_queue
    try:
        query_check = text(
            "SELECT id FROM kitchen_kot_queue WHERE (order_id = :oid OR readable_id = :rid) AND status = 'PENDING' LIMIT 1"
        )
        res = await db.execute(query_check, {"oid": clean_id, "rid": clean_readable or clean_id})
        existing = res.mappings().first()

        if existing:
            update_query = text(
                "UPDATE kitchen_kot_queue SET payload = :payload::jsonb, readable_id = :rid, restaurant_id = :rest_id, created_at = NOW() WHERE id = :id"
            )
            await db.execute(update_query, {
                "payload": json.dumps(payload),
                "rid": clean_readable or clean_id,
                "rest_id": target_restaurant_id,
                "id": existing["id"]
            })
            await db.commit()
            logger.info(f"[KOT Broadcast] Updated existing pending KOT in queue for #{clean_readable or clean_id}")
        else:
            insert_query = text(
                "INSERT INTO kitchen_kot_queue (order_id, readable_id, restaurant_id, payload, status, created_at) "
                "VALUES (:oid, :rid, :rest_id, :payload::jsonb, 'PENDING', NOW())"
            )
            await db.execute(insert_query, {
                "oid": clean_id,
                "rid": clean_readable or clean_id,
                "rest_id": target_restaurant_id,
                "payload": json.dumps(payload)
            })
            await db.commit()
            logger.info(f"[KOT Broadcast] Enqueued KOT for #{clean_readable or clean_id}")
    except Exception as db_err:
        logger.warning(f"[KOT Broadcast] Database queue note: {db_err}")
        await db.rollback()

    # 2. Native PostgreSQL Supabase Realtime Broadcast (realtime.send)
    try:
        topics_to_send = ["restaurant-orders-live"]
        if target_restaurant_id:
            topics_to_send.append(f"restaurant-orders-{target_restaurant_id}")
        for t in topics_to_send:
            await db.execute(
                text("SELECT realtime.send(:payload::jsonb, 'reprint-kot', :topic, false)"),
                {"payload": json.dumps(payload), "topic": t}
            )
        await db.commit()
        logger.info(f"[KOT Broadcast] Sent Postgres realtime.send broadcast for #{clean_readable or clean_id}")
    except Exception as pg_rt_err:
        logger.warning(f"[KOT Broadcast] Postgres realtime.send note: {pg_rt_err}")

    # 3. Broadcast via internal WebSockets
    try:
        kot_evt = {
            "event": "reprint-kot",
            "type": "broadcast",
            "orderId": clean_id,
            "restaurantId": target_restaurant_id,
            "payload": payload
        }
        if target_restaurant_id:
            await manager.broadcast_to_channel(f"restaurant_{target_restaurant_id}", kot_evt)
            await manager.broadcast_to_channel(f"restaurant-orders-{target_restaurant_id}", kot_evt)
        await manager.broadcast_to_channel("restaurant-orders-live", kot_evt)
        await manager.broadcast(kot_evt)

        # Also emit legacy event name for backward compatibility
        legacy_evt = {
            "event": "kot_broadcast",
            "orderId": clean_id,
            "restaurantId": target_restaurant_id,
            "payload": payload
        }
        await manager.broadcast(legacy_evt)
    except Exception as ws_err:
        logger.warning(f"[KOT Broadcast] WebSocket broadcast note: {ws_err}")

    # 3. Broadcast to Supabase Realtime channel if configured
    supabase_url = settings.NEXT_PUBLIC_SUPABASE_URL
    supabase_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.NEXT_PUBLIC_SUPABASE_ANON_KEY
    if supabase_url and supabase_key:
        try:
            base_sb_url = supabase_url.rstrip('/')
            topics = ["restaurant-orders-live", "realtime:restaurant-orders-live"]
            if target_restaurant_id:
                topics.extend([
                    f"restaurant-orders-{target_restaurant_id}",
                    f"realtime:restaurant-orders-{target_restaurant_id}"
                ])

            messages = [
                {
                    "topic": t,
                    "event": "reprint-kot",
                    "payload": payload
                }
                for t in topics
            ]

            async with httpx.AsyncClient(timeout=4.0) as client:
                # 3a. Supabase Realtime Broadcast REST API
                try:
                    await client.post(
                        f"{base_sb_url}/realtime/v1/api/broadcast",
                        headers={
                            "apikey": supabase_key,
                            "Authorization": f"Bearer {supabase_key}",
                            "Content-Type": "application/json"
                        },
                        json={"messages": messages}
                    )
                    logger.info(f"[KOT Broadcast] Successfully pushed Realtime broadcast to Supabase for #{clean_readable or clean_id}")
                except Exception as r_err:
                    logger.debug(f"[KOT Broadcast] Supabase Realtime HTTP broadcast note: {r_err}")

                # 3b. Push to persistent queue table
                try:
                    await client.post(
                        f"{base_sb_url}/rest/v1/kitchen_kot_queue",
                        headers={
                            "apikey": supabase_key,
                            "Authorization": f"Bearer {supabase_key}",
                            "Content-Type": "application/json",
                            "Prefer": "resolution=merge-duplicates"
                        },
                        json={
                            "order_id": clean_id,
                            "readable_id": clean_readable or clean_id,
                            "restaurant_id": target_restaurant_id,
                            "payload": payload,
                            "status": "PENDING"
                        }
                    )
                except Exception as rest_err:
                    logger.debug(f"[KOT Broadcast] Supabase REST queue note: {rest_err}")
        except Exception as sb_err:
            logger.debug(f"[KOT Broadcast] Supabase push note: {sb_err}")

    return {
        "success": True,
        "orderId": clean_id,
        "restaurantId": target_restaurant_id
    }
