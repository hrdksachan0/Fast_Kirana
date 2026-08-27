import os
import uuid
import logging
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

import firebase_admin
from firebase_admin import credentials, messaging

from database import get_db
from models import FcmToken, User
from routers.auth import require_auth, get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/fcm", tags=["FCM Push Tokens"])

# ─── FIREBASE ADMIN INITIALIZATION ───
FIREBASE_INIT_SUCCESS = False
try:
    cred_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "firebase-credentials.json")
    if os.path.exists(cred_path):
        if not firebase_admin._apps:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        FIREBASE_INIT_SUCCESS = True
        logger.info("✅ Firebase Admin SDK initialized successfully in FastAPI.")
    else:
        logger.warning(f"⚠️ Firebase credentials file not found at {cred_path}")
except Exception as e:
    logger.error(f"❌ Failed to initialize Firebase Admin SDK: {e}")


def generate_id(prefix: str = "fcm_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def get_user_id(user: Dict[str, Any]) -> str:
    return user.get("id") or user.get("sub") or ""


async def send_fcm_notification(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None
) -> Dict[str, Any]:
    """
    Dispatch push notification to one or multiple FCM tokens using Firebase Admin SDK.
    """
    if not FIREBASE_INIT_SUCCESS or not tokens:
        logger.warning("FCM notification skipped (Firebase not initialized or empty tokens).")
        return {"success": False, "sent_count": 0, "failure_count": len(tokens)}

    # Ensure all data values are strings (FCM requirement)
    clean_data = {str(k): str(v) for k, v in (data or {}).items()}

    valid_tokens = [t for t in tokens if t and isinstance(t, str) and len(t) > 10]
    if not valid_tokens:
        return {"success": False, "sent_count": 0, "failure_count": 0}

    try:
        message = messaging.MulticastMessage(
            tokens=valid_tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=clean_data,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    icon="ic_launcher",
                    color="#E20A22",
                    sound="default",
                    channel_id="fastkirana_alerts"
                )
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            )
        )

        response = messaging.send_each_for_multicast(message)
        logger.info(f"🚀 FCM Multicast sent: {response.success_count} success, {response.failure_count} failure(s)")
        return {
            "success": response.success_count > 0,
            "sent_count": response.success_count,
            "failure_count": response.failure_count
        }
    except Exception as e:
        logger.error(f"❌ Error sending FCM notification: {e}")
        return {"success": False, "error": str(e), "sent_count": 0, "failure_count": len(valid_tokens)}


@router.post("/register", status_code=status.HTTP_200_OK)
async def register_fcm_token(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Register or update an FCM device token for the authenticated user.
    """
    user_id = get_user_id(current_user)
    token = payload.get("token")
    device_type = payload.get("deviceType", "android")

    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="FCM Token is required"
        )

    try:
        # Check if the token already exists in db
        stmt = select(FcmToken).where(FcmToken.token == token)
        result = await db.execute(stmt)
        existing_token = result.scalars().first()

        if existing_token:
            # If it exists, update the user mapping and device type
            existing_token.userId = user_id
            if device_type:
                existing_token.deviceType = device_type
            await db.commit()
            return {
                "success": True,
                "message": "FCM token updated successfully",
                "id": existing_token.id,
                "userId": user_id
            }
        else:
            # Otherwise, insert a new record
            new_fcm = FcmToken(
                id=generate_id(),
                userId=user_id,
                token=token,
                deviceType=device_type
            )
            db.add(new_fcm)
            await db.commit()
            return {
                "success": True,
                "message": "FCM token registered successfully",
                "id": new_fcm.id,
                "userId": user_id
            }
    except Exception as e:
        await db.rollback()
        logger.error(f"Error registering FCM token: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register token: {str(e)}"
        )


@router.post("/send", status_code=status.HTTP_200_OK)
async def send_test_push_notification(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Send a test or targeted push notification to a user or specific token.
    """
    user_role = current_user.get("role", "USER")
    if user_role not in ["ADMIN", "MANAGER"]:
        raise HTTPException(status_code=403, detail="Admin permissions required to send broadcasts.")

    target = payload.get("target", "userId") # 'userId', 'token', 'all'
    target_user_id = payload.get("userId")
    direct_token = payload.get("token")
    title = payload.get("title", "⚡ FastKirana Express")
    body = payload.get("body", "Your fresh order is on its way in Ghatampur!")
    data = payload.get("data", {})

    tokens_to_send: List[str] = []

    if target == "token" and direct_token:
        tokens_to_send = [direct_token]
    elif target == "userId" and target_user_id:
        stmt = select(FcmToken.token).where(FcmToken.userId == target_user_id)
        res = await db.execute(stmt)
        tokens_to_send = list(res.scalars().all())
    elif target == "all":
        stmt = select(FcmToken.token)
        res = await db.execute(stmt)
        tokens_to_send = list(res.scalars().all())

    if not tokens_to_send:
        return {"success": False, "message": "No active device tokens found for target."}

    result = await send_fcm_notification(
        tokens=tokens_to_send,
        title=title,
        body=body,
        data=data
    )
    return result
