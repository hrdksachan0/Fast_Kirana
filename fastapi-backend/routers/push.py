import os
import uuid
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Body, Request, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, delete

from database import get_db
from models import PushSubscription, PushNotification, FcmToken, User
from routers.auth import get_current_user, require_auth
from routers.fcm import send_fcm_notification
from config import settings

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Push Notifications"])


def generate_id(prefix: str = "push_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def check_admin_or_secret(request: Request, current_user: Optional[dict] = None) -> bool:
    api_secret = request.headers.get("x-api-secret")
    expected_secret = getattr(settings, "AUTH_SECRET", None) or getattr(settings, "JWT_SECRET", None)
    if api_secret and expected_secret and api_secret == expected_secret:
        return True
    if current_user and current_user.get("role") in ["ADMIN", "MANAGER"]:
        return True
    return False


# ─── PUSH NOTIFY BRIDGE ───

@router.post("/push/notify")
async def push_notify_bridge(
    request: Request,
    payload: Dict[str, Any] = Body(...),
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Direct bridge endpoint to send push notification to a user or specific roles.
    Protected by x-api-secret or Admin auth.
    """
    if not check_admin_or_secret(request, current_user):
        raise HTTPException(status_code=401, detail="Unauthorized")

    user_id = payload.get("userId")
    roles = payload.get("roles")
    title = payload.get("title")
    body = payload.get("body")
    data = payload.get("data") or {}

    if not title or not body:
        raise HTTPException(status_code=400, detail="Missing title or body")

    tokens_to_send: List[str] = []

    if user_id:
        stmt = select(FcmToken.token).where(FcmToken.userId == user_id)
        res = await db.execute(stmt)
        tokens_to_send.extend(res.scalars().all())
    elif roles and isinstance(roles, list):
        parsed_roles = [str(r).upper() for r in roles]
        user_stmt = select(User.id).where(User.role.in_(parsed_roles))
        user_res = await db.execute(user_stmt)
        user_ids = list(user_res.scalars().all())

        if user_ids:
            fcm_stmt = select(FcmToken.token).where(FcmToken.userId.in_(user_ids))
            fcm_res = await db.execute(fcm_stmt)
            tokens_to_send.extend(fcm_res.scalars().all())
    else:
        raise HTTPException(status_code=400, detail="Must provide either userId or roles")

    unique_tokens = list(set(tokens_to_send))
    if unique_tokens:
        await send_fcm_notification(unique_tokens, title, body, data)

    return {"success": True, "deliveredTokens": len(unique_tokens)}


# ─── PUSH SUBSCRIBE / UNSUBSCRIBE (WEB PUSH) ───

@router.post("/push/subscribe")
async def push_subscribe(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Register a browser Web Push subscription.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    sub_data = payload.get("subscription") or {}
    endpoint = sub_data.get("endpoint")
    keys = sub_data.get("keys") or {}
    p256dh = keys.get("p256dh")
    auth_key = keys.get("auth")

    if not endpoint or not p256dh or not auth_key:
        raise HTTPException(status_code=400, detail="Invalid subscription object")

    try:
        stmt = select(PushSubscription).where(PushSubscription.endpoint == endpoint)
        res = await db.execute(stmt)
        existing = res.scalars().first()

        if existing:
            existing.userId = user_id
            existing.p256dh = p256dh
            existing.auth = auth_key
            existing.updatedAt = datetime.utcnow()
        else:
            new_sub = PushSubscription(
                id=generate_id(),
                userId=user_id,
                endpoint=endpoint,
                p256dh=p256dh,
                auth=auth_key,
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow()
            )
            db.add(new_sub)

        await db.commit()
        return {"success": True}
    except Exception as e:
        await db.rollback()
        logger.error(f"Error subscribing push: {e}")
        raise HTTPException(status_code=500, detail="Failed to subscribe")


@router.delete("/push/subscribe")
async def push_unsubscribe(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a browser Web Push subscription.
    """
    endpoint = payload.get("endpoint")
    if not endpoint:
        raise HTTPException(status_code=400, detail="Endpoint is required")

    try:
        await db.execute(delete(PushSubscription).where(PushSubscription.endpoint == endpoint))
        await db.commit()
        return {"success": True}
    except Exception as e:
        await db.rollback()
        logger.error(f"Error unsubscribing push: {e}")
        raise HTTPException(status_code=500, detail="Failed to unsubscribe")


# ─── ADMIN PUSH NOTIFICATIONS ───

@router.get("/admin/push-notifications")
async def get_admin_push_notifications(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get push notification broadcast history and subscription count.
    """
    if current_user.get("role") not in ["ADMIN", "MANAGER"]:
        raise HTTPException(status_code=403, detail="Admin permissions required")

    try:
        notifs_stmt = select(PushNotification).order_by(PushNotification.sentAt.desc()).limit(100)
        notifs_res = await db.execute(notifs_stmt)
        notifications = notifs_res.scalars().all()

        sub_count_stmt = select(func.count(PushSubscription.id))
        sub_count_res = await db.execute(sub_count_stmt)
        subscription_count = sub_count_res.scalar() or 0

        return {
            "notifications": [
                {
                    "id": n.id,
                    "title": n.title,
                    "body": n.body,
                    "imageUrl": n.imageUrl,
                    "linkUrl": n.linkUrl,
                    "sentAt": n.sentAt.isoformat() if n.sentAt else None,
                    "successCount": n.successCount,
                    "failureCount": n.failureCount,
                }
                for n in notifications
            ],
            "subscriptionCount": subscription_count
        }
    except Exception as e:
        logger.error(f"Failed to fetch push notifications: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch notifications")


@router.post("/admin/push-notifications", status_code=status.HTTP_201_CREATED)
async def broadcast_admin_push_notification(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Broadcast a push notification to all users across Mobile FCM and Web Push.
    """
    if current_user.get("role") not in ["ADMIN", "MANAGER"]:
        raise HTTPException(status_code=403, detail="Admin permissions required")

    title = payload.get("title")
    body_text = payload.get("body")
    image_url = payload.get("imageUrl")
    link_url = payload.get("linkUrl")

    if not title or not body_text:
        raise HTTPException(status_code=400, detail="Title and body are required")

    # Multicast via FCM
    success_count = 0
    failure_count = 0

    try:
        tokens_stmt = select(FcmToken.token)
        tokens_res = await db.execute(tokens_stmt)
        tokens = list(set(tokens_res.scalars().all()))

        if tokens:
            data_dict = {
                "title": str(title),
                "body": str(body_text),
                "url": str(link_url or "/"),
                "category": "offer"
            }
            fcm_res = await send_fcm_notification(tokens, title, body_text, data_dict)
            success_count = fcm_res.get("sent_count", 0)
            failure_count = fcm_res.get("failure_count", 0)
    except Exception as e:
        logger.error(f"FCM broadcast error: {e}")

    try:
        new_notification = PushNotification(
            id=generate_id(),
            title=title,
            body=body_text,
            imageUrl=image_url,
            linkUrl=link_url,
            sentAt=datetime.utcnow(),
            successCount=success_count,
            failureCount=failure_count
        )
        db.add(new_notification)
        await db.commit()
        await db.refresh(new_notification)

        return {
            "id": new_notification.id,
            "title": new_notification.title,
            "body": new_notification.body,
            "imageUrl": new_notification.imageUrl,
            "linkUrl": new_notification.linkUrl,
            "sentAt": new_notification.sentAt.isoformat(),
            "successCount": new_notification.successCount,
            "failureCount": new_notification.failureCount,
        }
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to record push notification: {e}")
        raise HTTPException(status_code=500, detail="Failed to send push notification")
