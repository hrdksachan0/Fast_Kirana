from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Any
import uuid

from database import get_db
from models import FcmToken
from routers.auth import require_auth

router = APIRouter(prefix="/fcm", tags=["FCM Push Tokens"])


def generate_id(prefix: str = "fcm_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def get_user_id(user: Dict[str, Any]) -> str:
    return user.get("id") or user.get("sub") or ""


@router.post("/register", status_code=status.HTTP_200_OK)
async def register_fcm_token(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Register or update an FCM device token for the current user.
    """
    user_id = get_user_id(current_user)
    token = payload.get("token")
    device_type = payload.get("deviceType")

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
            return {"success": True, "message": "FCM token updated successfully", "id": existing_token.id}
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
            return {"success": True, "message": "FCM token registered successfully", "id": new_fcm.id}
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register token: {str(e)}"
        )
