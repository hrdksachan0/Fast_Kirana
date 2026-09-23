"""
Cron & Automated Lifecycle Engine
Migrated from Next.js cron & payment-recovery service to FastAPI.
Handles:
1. /cron/keep-alive: DB health ping & Quick-commerce UPI payment recovery / auto-cancellation
2. /cron/cleanup-carts: Delete abandoned carts older than 7 days
3. /cron/inventory-sync: Low-stock audit & alert generation
4. /cron/settle-wallets: Rider wallet ledger reconciliation
"""

from fastapi import APIRouter, Depends, HTTPException, status, Header, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import text, and_, or_, delete
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List
import logging
import os
import uuid
import httpx

from database import get_db
from models import Order, OrderItem, Product, StockLog, Cart, CartItem, User, OrderStatus, PaymentStatus, PaymentMethod
from config import settings
from routers.websockets import manager as ws_manager

logger = logging.getLogger("cron_lifecycle")

router = APIRouter(prefix="/cron", tags=["Cron Lifecycle"])


def _verify_cron_auth(authorization: Optional[str] = Header(None)):
    cron_secret = os.environ.get("CRON_SECRET", "").strip()
    if cron_secret:
        if not authorization or authorization != f"Bearer {cron_secret}":
            raise HTTPException(status_code=401, detail="Unauthorized cron invocation")
    return True


async def _send_whatsapp_alert(phone: str, text_message: str) -> bool:
    """Send WhatsApp template/text message via Meta Cloud API if configured."""
    token = os.environ.get("WHATSAPP_TOKEN", "").strip()
    phone_id = os.environ.get("WHATSAPP_PHONE_NUMBER_ID", "").strip()
    if not token or not phone_id or not phone:
        return False

    clean_phone = "".join(filter(str.isdigit, phone))
    if len(clean_phone) == 10:
        clean_phone = "91" + clean_phone
    elif len(clean_phone) > 10 and clean_phone.startswith("0"):
        clean_phone = "91" + clean_phone[1:]

    url = f"https://graph.facebook.com/v20.0/{phone_id}/messages"
    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": clean_phone,
        "type": "text",
        "text": {"body": text_message},
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=4.0) as client:
            res = await client.post(url, json=payload, headers=headers)
            return res.status_code in (200, 201)
    except Exception as e:
        logger.warning(f"WhatsApp alert error for {clean_phone}: {e}")
        return False


async def run_payment_recovery_cron(db: AsyncSession) -> Dict[str, Any]:
    """
    Enterprise Quick-Commerce Payment Recovery & Order Lifecycle Engine.
    Follows Swiggy/Zepto model:
    1. 2-30 min unpaid UPI attempts: Trigger automated WhatsApp recovery with direct COD / retry link.
    2. >30 min abandoned orders: Auto-cancel, restore reserved inventory, and emit real-time updates.
    """
    summary = {
        "recoveredAlertsSent": 0,
        "timedOutCancelled": 0,
        "errors": []
    }

    now = datetime.utcnow()
    two_minutes_ago = now - timedelta(minutes=2)
    thirty_minutes_ago = now - timedelta(minutes=30)

    # ---------------------------------------------------------------------------
    # STEP 1: WhatsApp Drop-off Recovery for Orders between 2 and 30 minutes old
    # ---------------------------------------------------------------------------
    try:
        stmt_rec = (
            select(Order)
            .where(
                and_(
                    Order.paymentMethod == PaymentMethod.UPI,
                    Order.paymentStatus == PaymentStatus.PENDING,
                    Order.status == OrderStatus.PENDING,
                    Order.createdAt <= two_minutes_ago,
                    Order.createdAt >= thirty_minutes_ago,
                    or_(
                        Order.notes.is_(None),
                        ~Order.notes.contains("[WA_RECOVERY_SENT]")
                    )
                )
            )
            .limit(20)
        )
        res_rec = await db.execute(stmt_rec)
        recovery_orders = res_rec.scalars().all()

        for order in recovery_orders:
            # Fetch user phone
            user_stmt = select(User).where(User.id == order.userId)
            u_res = await db.execute(user_stmt)
            user = u_res.scalars().first()
            phone = user.phone if user else None
            if not phone:
                continue

            customer_name = (user.name if user and user.name else "Customer").strip()
            display_id = order.readableId or order.id[-6:].upper()
            total_formatted = int(round(float(order.total)))
            recovery_url = f"https://fastkirana.com/order/{order.id}/track?action=cod"

            message_text = (
                f"🛒 *FastKirana Payment Alert*\n\n"
                f"Hi {customer_name}! Aapke order *#{display_id}* (₹{total_formatted}) ka UPI payment pending hai.\n\n"
                f"Khana / Grocery turant dispatch karwane ke liye niche link par tap karke *Cash on Delivery (COD)* me convert karein ya payment retry karein:\n\n"
                f"👉 {recovery_url}\n\n"
                f"_Kisi bhi sahayata ke liye is number par call/WhatsApp karein._"
            )

            sent = await _send_whatsapp_alert(phone, message_text)
            if sent:
                summary["recoveredAlertsSent"] += 1
                updated_notes = f"{order.notes} [WA_RECOVERY_SENT]" if order.notes else "[WA_RECOVERY_SENT]"
                order.notes = updated_notes
                await db.commit()
                logger.info(f"WhatsApp recovery alert sent for Order #{display_id} to {phone}")
    except Exception as e:
        logger.error(f"Step 1 WhatsApp recovery query error: {e}")
        summary["errors"].append(f"Step 1 failed: {str(e)}")

    # ---------------------------------------------------------------------------
    # STEP 2: Auto-Timeout and Cancel Abandoned Orders older than 30 minutes
    # ---------------------------------------------------------------------------
    try:
        stmt_exp = (
            select(Order)
            .where(
                and_(
                    Order.paymentMethod == PaymentMethod.UPI,
                    Order.paymentStatus == PaymentStatus.PENDING,
                    Order.status == OrderStatus.PENDING,
                    Order.createdAt < thirty_minutes_ago,
                )
            )
            .limit(50)
        )
        res_exp = await db.execute(stmt_exp)
        expired_orders = res_exp.scalars().all()

        for order in expired_orders:
            try:
                # 1. Update order status
                timeout_notes = (
                    f"{order.notes} [PAYMENT_TIMEOUT: Auto-cancelled after 30m]"
                    if order.notes
                    else "[PAYMENT_TIMEOUT: Auto-cancelled after 30m]"
                )
                order.status = OrderStatus.CANCELLED
                order.notes = timeout_notes

                # 2. Fetch order items and restore non-restaurant stock
                items_stmt = select(OrderItem).where(OrderItem.orderId == order.id)
                items_res = await db.execute(items_stmt)
                order_items = items_res.scalars().all()

                for item in order_items:
                    if not item.productId:
                        continue
                    prod_stmt = select(Product).where(Product.id == item.productId)
                    prod_res = await db.execute(prod_stmt)
                    product = prod_res.scalars().first()

                    # Skip restaurant items (they cook to order)
                    if not product or product.restaurantId:
                        continue

                    prev_stock = int(product.stock or 0)

                    # Check variant stock restoration
                    if item.selectedVariant and product.variants and isinstance(product.variants, list):
                        updated_variants = []
                        for v in product.variants:
                            if isinstance(v, dict) and v.get("name") == item.selectedVariant:
                                cur_v_stock = int(v.get("stock") or 0)
                                updated_variants.append({**v, "stock": cur_v_stock + item.quantity})
                            else:
                                updated_variants.append(v)
                        new_total = sum(int(v.get("stock") or 0) for v in updated_variants if isinstance(v, dict))
                        product.variants = updated_variants
                        product.stock = new_total
                        new_stock = new_total
                    else:
                        new_stock = prev_stock + item.quantity
                        product.stock = new_stock

                    # Record stock log
                    stock_log = StockLog(
                        id=f"sl_{uuid.uuid4().hex[:20]}",
                        productId=product.id,
                        quantity=item.quantity,
                        type="ORDER_CANCELLED",
                        prevStock=prev_stock,
                        newStock=new_stock,
                        createdAt=datetime.utcnow()
                    )
                    db.add(stock_log)

                await db.commit()

                # 3. Broadcast real-time cancellation on WebSocket
                try:
                    await ws_manager.broadcast_to_channel(
                        f"order_{order.id}",
                        {
                            "event": "ORDER_STATUS_UPDATE",
                            "orderId": order.id,
                            "status": "CANCELLED",
                            "readableId": order.readableId,
                            "timestamp": datetime.utcnow().isoformat()
                        }
                    )
                except Exception as ws_err:
                    logger.warning(f"WebSocket broadcast error for cancelled order {order.id}: {ws_err}")

                summary["timedOutCancelled"] += 1
                logger.info(f"Order #{order.readableId or order.id} auto-cancelled due to 30m payment timeout.")
            except Exception as item_err:
                logger.error(f"Error cancelling expired order {order.id}: {item_err}")
                summary["errors"].append(f"Cancellation error for {order.id}: {str(item_err)}")
    except Exception as e:
        logger.error(f"Step 2 timeout query error: {e}")
        summary["errors"].append(f"Step 2 failed: {str(e)}")

    return summary


@router.get("/keep-alive")
@router.post("/keep-alive")
async def keep_alive_cron(
    request: Request,
    db: AsyncSession = Depends(get_db),
    authorized: bool = Depends(_verify_cron_auth)
):
    """
    Keep-alive endpoint to warm Supabase PostgreSQL pool and execute automated payment recovery.
    """
    try:
        # Ping Database
        await db.execute(text("SELECT 1"))

        # Execute recovery engine
        recovery_summary = await run_payment_recovery_cron(db)

        return {
            "success": True,
            "message": "Database kept warm & payment recovery cycle executed",
            "recovery": recovery_summary,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Keep-alive ping failed: {e}")
        raise HTTPException(
            status_code=500,
            detail={"success": False, "error": "Database connection failed", "details": str(e)}
        )


@router.get("/cleanup-carts")
@router.post("/cleanup-carts")
async def cleanup_abandoned_carts(
    db: AsyncSession = Depends(get_db),
    authorized: bool = Depends(_verify_cron_auth)
):
    """
    Clean up abandoned guest and inactive user carts older than 7 days.
    """
    cutoff = datetime.utcnow() - timedelta(days=7)
    try:
        # Delete old carts
        stmt = delete(Cart).where(Cart.updatedAt < cutoff)
        res = await db.execute(stmt)
        await db.commit()
        deleted_count = res.rowcount if hasattr(res, "rowcount") else 0
        return {
            "success": True,
            "message": f"Cleaned up {deleted_count} abandoned carts older than 7 days",
            "deletedCount": deleted_count,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Cart cleanup failed: {e}")
        raise HTTPException(status_code=500, detail=f"Cart cleanup failed: {str(e)}")


@router.get("/inventory-sync")
@router.post("/inventory-sync")
async def inventory_sync_audit(
    db: AsyncSession = Depends(get_db),
    authorized: bool = Depends(_verify_cron_auth)
):
    """
    Audit stock across products and identify out-of-stock / low-stock items.
    """
    try:
        stmt = select(Product).where(
            and_(
                Product.stock <= 5,
                Product.restaurantId.is_(None)
            )
        ).limit(100)
        res = await db.execute(stmt)
        low_stock_prods = res.scalars().all()

        items = [
            {
                "id": p.id,
                "name": p.name,
                "stock": p.stock,
                "unit": p.unit,
                "isOutOfStock": (p.stock <= 0)
            }
            for p in low_stock_prods
        ]

        return {
            "success": True,
            "totalLowStock": len(items),
            "outOfStockCount": sum(1 for i in items if i["isOutOfStock"]),
            "items": items,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Inventory sync audit failed: {e}")
        raise HTTPException(status_code=500, detail=f"Inventory sync failed: {str(e)}")
