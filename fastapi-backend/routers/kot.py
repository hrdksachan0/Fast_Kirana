from fastapi import APIRouter, HTTPException, status, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import text, or_
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import time
import json
import logging
import asyncio
import httpx
import websockets
from datetime import datetime, timezone, timedelta

from database import get_db
from models import Order, Restaurant, User
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


async def send_supabase_realtime_broadcast(topics: List[str], event_name: str, payload: dict) -> bool:
    """
    Direct WebSocket connection to Supabase Realtime (Phoenix channel protocol).
    Dispatches instantaneous zero-latency broadcast events to all listening kitchen devices & printer bridges.
    """
    supabase_url = settings.NEXT_PUBLIC_SUPABASE_URL or "https://bberzasmxwioxjynbuaf.supabase.co"
    anon_key = settings.NEXT_PUBLIC_SUPABASE_ANON_KEY or "sb_publishable_txJDOmH1qWQuOLCKrnV69A_RQ1XS4o-"

    ws_base = supabase_url.replace("https://", "wss://").replace("http://", "ws://").rstrip("/")
    ws_uri = f"{ws_base}/realtime/v1/websocket?apikey={anon_key}&vsn=1.0.0"

    try:
        async with websockets.connect(ws_uri, close_timeout=2.0) as ws:
            for idx, topic in enumerate(topics, start=1):
                # 1. Join topic channel
                join_msg = {
                    "topic": topic,
                    "event": "phx_join",
                    "payload": {"config": {"broadcast": {"self": True}}},
                    "ref": str(idx * 2)
                }
                await ws.send(json.dumps(join_msg))

                # 2. Broadcast event
                bcast_msg = {
                    "topic": topic,
                    "event": "broadcast",
                    "payload": {
                        "type": "broadcast",
                        "event": event_name,
                        "payload": payload
                    },
                    "ref": str(idx * 2 + 1)
                }
                await ws.send(json.dumps(bcast_msg))

            await asyncio.sleep(0.3)
            logger.info(f"[KOT Broadcast] ⚡ Realtime broadcast delivered to {len(topics)} topics")
            return True
    except Exception as e:
        logger.warning(f"[KOT Broadcast] Supabase Realtime WebSocket broadcast note: {e}")
        return False


def generate_standard_kot_text(
    order_id_text: str,
    customer_name: str,
    delivery_method: str,
    items: List[dict],
    shop_name: Optional[str] = None,
    notes: Optional[str] = None
) -> str:
    ist = timezone(timedelta(hours=5, minutes=30))
    now_ist_time = datetime.now(ist).strftime("%d-%b-%Y, %I:%M %p")
    line_len = 39
    thick = "=" * line_len

    token = order_id_text.strip().lstrip("#")
    mode = (delivery_method or "DELIVERY").strip().upper()
    left_header = f"#{token} [{mode}]"
    right_header = now_ist_time

    brand_or_shop = shop_name.strip() if shop_name else "FastKirana"
    cust = (customer_name or "Customer").strip()
    sub_header = f"{brand_or_shop}  • {cust}"

    lines = [thick]
    if len(left_header) + len(right_header) + 1 <= line_len:
        lines.append(left_header.ljust(line_len - len(right_header)) + right_header)
    else:
        lines.append(left_header)
        lines.append(right_header.rjust(line_len))
    lines.extend([
        sub_header,
        thick,
    ])

    total_qty = 0
    for it in (items or []):
        qty = int(it.get("quantity") or 1)
        total_qty += qty
        name = (it.get("name") or "Item").strip()
        variant = it.get("selectedVariant")
        var_text = f" ({variant})" if variant else ""

        lines.append(f"[ ]  {qty} x {name}{var_text}")
        item_note = it.get("notes")
        if item_note:
            lines.append(f"     -> Note: {item_note.strip()}")

    lines.append(thick)
    clean_note = ""
    if notes and notes.strip():
        clean_note = notes.replace("✨ Note: ", "").replace("Note: ", "").replace("✨", "").strip()
    lines.append(f"Note: {clean_note}")
    lines.append(thick)
    lines.extend(["\r\n\r\n\r\n"])
    return "\r\n".join(lines)


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
    # Only manual dispatch from Admin Orders Tab, Order Modal, Kitchen Console, or authorized Staff is permitted.
    header_role = (request.headers.get("x-user-role") or "").upper()
    header_phone = request.headers.get("x-user-phone") or ""
    is_admin_or_staff = (
        header_role in ["ADMIN", "RESTAURANT_OWNER", "CHEF", "SUPER_ADMIN", "SUPERADMIN"] or
        "8112849854" in header_phone
    )
    is_manual_admin_dispatch = bool(
        req.manual is True or
        req.source in ["orders_tab", "order_modal", "admin_console", "kitchen_console", "orders_tab_fallback", "flutter_app"] or
        (req.kotText and "FASTKIRANA KOT" in req.kotText)
    )

    if not is_admin_or_staff and not is_manual_admin_dispatch:
        logger.info(f"[KOT Broadcast API] 🛡️ Ignored checkout auto-KOT for Order #{clean_readable or clean_id}")
        return {"success": True, "ignored": True, "reason": "Auto-KOT on checkout disabled"}

    # Dynamic debounce window: 15 seconds to prevent multiple slips on multi-tap / slow internet
    cooldown_window = 15.0
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
    target_readable = clean_readable
    target_items = req.items or []
    customer_name = req.customerName
    delivery_method = req.deliveryMethod or "DELIVERY"
    shop_name = req.shopName
    notes = req.notes

    # If missing details (restaurantId, items, customerName, etc.), enrich from DB
    try:
        stmt = (
            select(Order)
            .options(selectinload(Order.items), selectinload(Order.user))
            .where(or_(Order.id == clean_id, Order.readableId == (clean_readable or clean_id)))
        )
        res = await db.execute(stmt)
        order_obj = res.scalar_one_or_none()
        if order_obj:
            if not target_restaurant_id:
                target_restaurant_id = order_obj.restaurantId
            if not target_readable:
                target_readable = order_obj.readableId
            if not customer_name:
                customer_name = order_obj.userName or (order_obj.user.name if order_obj.user else None) or "Customer"
            if not delivery_method:
                delivery_method = order_obj.deliveryMethod or "DELIVERY"
            if not shop_name and order_obj.restaurantId:
                r_stmt = select(Restaurant.name).where(Restaurant.id == order_obj.restaurantId)
                r_res = await db.execute(r_stmt)
                shop_name = r_res.scalar_one_or_none() or "Restaurant"
            if not notes:
                notes = order_obj.notes
            if not target_items and order_obj.items:
                target_items = [
                    {
                        "id": it.id,
                        "name": it.name,
                        "quantity": it.quantity,
                        "price": it.price,
                        "selectedVariant": it.selectedVariant,
                        "notes": it.notes,
                        "restaurantId": target_restaurant_id,
                        "isRestaurantItem": True,
                        "type": "RESTAURANT"
                    }
                    for it in order_obj.items
                ]
    except Exception as e:
        logger.warning(f"[KOT Broadcast] DB order enrichment note: {e}")

    # Strict Restaurant Items Filter:
    # Under no circumstances should grocery products (atta, dal, oil, soap, etc.) be printed on kitchen KOT!
    cooked_food_whitelist = [
        'dosa', 'burger', 'pizza', 'sandwich', 'roll', 'frankie', 'chowmein', 'noodles',
        'fried rice', 'paneer', 'manchurian', 'shake', 'cold coffee', 'tea', 'chai', 'coffee',
        'pasta', 'thali', 'roti', 'naan', 'gravy', 'curry', 'biryani', 'pav bhaji', 'fries',
        'momos', 'samosa', 'maggi', 'soup', 'tikka', 'chole', 'bhature', 'kulcha', 'raita',
        'sweet', 'gulab jamun', 'rasgulla', 'ice cream', 'beverage', 'mocktail', 'combo'
    ]
    pure_grocery_keywords = [
        'atta', 'raw rice', 'dal', 'mustard oil', 'refined oil', 'ghee', 'washing powder',
        'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner',
        'harpic', 'vim bar', 'rin', 'tide', 'surf', 'namkeen packet', 'chips packet',
        'biscuit', 'sugar', 'salt', 'masala packet', 'spices', 'refill', 'packet', 'pouch'
    ]

    enriched_items = []
    for it in target_items:
        it_copy = dict(it)
        name_lower = (it_copy.get("name") or "").lower().strip()
        is_rest = bool(
            it_copy.get("restaurantId") or
            it_copy.get("isRestaurantItem") is True or
            it_copy.get("type") == "RESTAURANT" or
            any(cw in name_lower for cw in cooked_food_whitelist)
        )
        is_grocery = any(gw in name_lower for gw in pure_grocery_keywords)

        # Skip grocery items unless explicitly assigned to this restaurant
        if is_grocery and not it_copy.get("restaurantId"):
            continue

        if is_rest or not pure_grocery_keywords:
            if target_restaurant_id and not it_copy.get("restaurantId"):
                it_copy["restaurantId"] = target_restaurant_id
            it_copy["isRestaurantItem"] = True
            it_copy["type"] = "RESTAURANT"
            enriched_items.append(it_copy)

    # Fallback: if list is empty, take target_items but filter out groceries
    if not enriched_items:
        for it in target_items:
            name_lower = (it.get("name") or "").lower().strip()
            if not any(gw in name_lower for gw in pure_grocery_keywords):
                it_copy = dict(it, isRestaurantItem=True, type="RESTAURANT", restaurantId=target_restaurant_id)
                enriched_items.append(it_copy)

    final_readable = target_readable or clean_readable or clean_id
    kot_text = req.kotText
    if not kot_text or kot_text.strip() == "FASTKIRANA KOT" or len(kot_text.strip()) < 20:
        kot_text = generate_standard_kot_text(
            order_id_text=final_readable,
            customer_name=customer_name or "Customer",
            delivery_method=delivery_method,
            items=enriched_items,
            shop_name=shop_name or "Restaurant Kitchen",
            notes=notes
        )

    payload = {
        "orderId": clean_id,
        "readableId": final_readable,
        "restaurantId": target_restaurant_id,
        "kotText": kot_text,
        "items": enriched_items,
        "notes": notes,
        "customerName": customer_name or "Customer",
        "deliveryMethod": delivery_method,
        "shopName": shop_name or "Kitchen",
        "printedAt": req.printedAt or datetime.now(timezone.utc).isoformat(),
        "manual": True,
        "source": req.source or "orders_tab",
        "timestamp": int(now * 1000)
    }

    # 1. Enqueue to PostgreSQL table kitchen_kot_queue (Always mark PENDING for print)
    try:
        query_check = text(
            "SELECT id FROM kitchen_kot_queue WHERE (order_id = :oid OR readable_id = :rid) LIMIT 1"
        )
        res = await db.execute(query_check, {"oid": clean_id, "rid": final_readable})
        existing = res.mappings().first()

        if existing:
            update_query = text(
                "UPDATE kitchen_kot_queue SET payload = CAST(:payload AS jsonb), readable_id = :rid, restaurant_id = :rest_id, status = 'PENDING', created_at = NOW() WHERE id = :id"
            )
            await db.execute(update_query, {
                "payload": json.dumps(payload),
                "rid": final_readable,
                "rest_id": target_restaurant_id,
                "id": existing["id"]
            })
            await db.commit()
            logger.info(f"[KOT Broadcast] Updated KOT queue row to PENDING for #{final_readable}")
        else:
            insert_query = text(
                "INSERT INTO kitchen_kot_queue (order_id, readable_id, restaurant_id, payload, status, created_at) "
                "VALUES (:oid, :rid, :rest_id, CAST(:payload AS jsonb), 'PENDING', NOW())"
            )
            await db.execute(insert_query, {
                "oid": clean_id,
                "rid": final_readable,
                "rest_id": target_restaurant_id,
                "payload": json.dumps(payload)
            })
            await db.commit()
            logger.info(f"[KOT Broadcast] Enqueued KOT as PENDING for #{final_readable}")
    except Exception as db_err:
        logger.warning(f"[KOT Broadcast] Database queue note: {db_err}")
        await db.rollback()

    # 2. Supabase Realtime WebSocket Broadcast (Direct zero-latency delivery to PC Printer Bridge & Web KDS)
    topics_to_send = [
        "realtime:restaurant-orders-live",
        "restaurant-orders-live",
    ]
    if target_restaurant_id:
        topics_to_send.extend([
            f"realtime:restaurant-orders-{target_restaurant_id}",
            f"restaurant-orders-{target_restaurant_id}",
            f"realtime:restaurant_{target_restaurant_id}",
            f"restaurant_{target_restaurant_id}",
        ])

    asyncio.create_task(send_supabase_realtime_broadcast(topics_to_send, "reprint-kot", payload))

    # 3. Broadcast via internal FastAPI WebSockets
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
            await manager.broadcast_to_channel(f"kitchen_{target_restaurant_id}", kot_evt)
        await manager.broadcast_to_channel("restaurant-orders-live", kot_evt)
        await manager.broadcast(kot_evt)
    except Exception as ws_err:
        logger.warning(f"[KOT Broadcast] Internal WebSocket broadcast note: {ws_err}")

    # 4. Supabase REST API persistent queue fallback
    supabase_url = settings.NEXT_PUBLIC_SUPABASE_URL
    anon_key = settings.NEXT_PUBLIC_SUPABASE_ANON_KEY
    if supabase_url and anon_key:
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                await client.post(
                    f"{supabase_url.rstrip('/')}/rest/v1/kitchen_kot_queue",
                    headers={
                        "apikey": anon_key,
                        "Authorization": f"Bearer {anon_key}",
                        "Content-Type": "application/json",
                        "Prefer": "resolution=merge-duplicates"
                    },
                    json={
                        "order_id": clean_id,
                        "readable_id": final_readable,
                        "restaurant_id": target_restaurant_id,
                        "payload": payload,
                        "status": "PENDING"
                    }
                )
        except Exception as rest_err:
            logger.debug(f"[KOT Broadcast] Supabase REST queue fallback note: {rest_err}")

    return {
        "success": True,
        "orderId": clean_id,
        "readableId": final_readable,
        "restaurantId": target_restaurant_id
    }
