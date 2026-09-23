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


@router.post("/kot-broadcast")
@router.post("/api/kot-broadcast")
async def broadcast_kot(
    req: KotBroadcastRequest,
    db: AsyncSession = Depends(get_db)
):
    if not req.orderId:
        raise HTTPException(status_code=400, detail="orderId is required")

    clean_id = req.orderId.strip().lstrip("#")
    clean_readable = (req.readableId or "").strip().lstrip("#")
    # C12 FIX: Strip suborder suffix (-R, -G, -1) rather than splitting on first hyphen
    # which collapsed all FK-* orders to "FK"
    import re
    base_readable = re.sub(r"-[GR\d]+$", "", clean_readable, flags=re.IGNORECASE) if clean_readable else ""
    now = time.time()

    # 10-second deduplication
    last_broadcast = max(
        recent_broadcast_timestamps.get(clean_id, 0),
        recent_broadcast_timestamps.get(clean_readable, 0) if clean_readable else 0,
        recent_broadcast_timestamps.get(base_readable, 0) if (base_readable and base_readable != "FK") else 0
    )

    if last_broadcast > 0 and (now - last_broadcast) < 10.0:
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
        "timestamp": int(now * 1000)
    }

    # 1. Enqueue to PostgreSQL table kitchen_kot_queue if table exists
    try:
        query_check = text(
            "SELECT id FROM kitchen_kot_queue WHERE (order_id = :oid OR readable_id = :rid) AND status = 'PENDING' LIMIT 1"
        )
        res = await db.execute(query_check, {"oid": clean_id, "rid": clean_readable or clean_id})
        existing = res.mappings().first()

        if existing:
            update_query = text(
                "UPDATE kitchen_kot_queue SET payload = :payload, readable_id = :rid, restaurant_id = :rest_id, created_at = NOW() WHERE id = :id"
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
                "VALUES (:oid, :rid, :rest_id, :payload, 'PENDING', NOW())"
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
        logger.warning(f"[KOT Broadcast] Database queue note (table may not exist yet): {db_err}")
        await db.rollback()

    # 2. Broadcast via internal WebSockets
    try:
        await manager.broadcast({
            "event": "kot_broadcast",
            "orderId": clean_id,
            "restaurantId": target_restaurant_id,
            "payload": payload
        })
    except Exception as ws_err:
        logger.warning(f"[KOT Broadcast] WebSocket broadcast note: {ws_err}")

    # 3. Broadcast to Supabase Realtime channel if configured
    supabase_url = settings.NEXT_PUBLIC_SUPABASE_URL
    supabase_key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.NEXT_PUBLIC_SUPABASE_ANON_KEY
    if supabase_url and supabase_key:
        try:
            channel_name = f"restaurant-orders-{target_restaurant_id}" if target_restaurant_id else "restaurant-orders-live"
            async with httpx.AsyncClient(timeout=4.0) as client:
                await client.post(
                    f"{supabase_url.rstrip('/')}/rest/v1/kitchen_kot_queue",
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
        except Exception as sb_err:
            logger.debug(f"[KOT Broadcast] Supabase REST push note: {sb_err}")

    return {
        "success": True,
        "orderId": clean_id,
        "restaurantId": target_restaurant_id
    }
