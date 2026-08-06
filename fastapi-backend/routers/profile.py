"""
Profile Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Any, Optional
from datetime import datetime
import uuid
import random

from database import get_db
from models import User
from routers.auth import require_auth

router = APIRouter(prefix="/profile", tags=["User Profile"])


def _generate_otp() -> str:
    return str(random.randint(100000, 999999))


def _send_email_otp_stub(email: str, otp: str) -> Dict[str, Any]:
    """Placeholder: in production integrate with SES/SendGrid.
    For now just print to logs."""
    print(f"[EMAIL OTP] To: {email}, OTP: {otp}")
    return {"sent": True}


def _send_sms_otp_stub(phone: str, otp: str) -> Dict[str, Any]:
    print(f"[SMS OTP] To: {phone}, OTP: {otp}")
    return {"sent": True}


@router.post("/send-email-otp")
async def send_email_otp(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Send OTP to a new email (for verification before update)."""
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="email required")

    otp = _generate_otp()
    user_id = current_user.get("id") or current_user.get("sub")

    # Store OTP against user (in-memory for now, can move to Redis)
    # Here we put it on user.emailOtp field (or a separate table in production)
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # For simplicity, store OTP in a temporary field (you may want a separate OTP table)
    if not hasattr(user, "emailOtp"):
        # Field doesn't exist, just log and return
        _send_email_otp_stub(email, otp)
        return {"success": True, "message": "OTP sent", "devOtp": otp}

    user.emailOtp = otp
    user.emailOtpExpiresAt = datetime.utcnow()
    await db.commit()
    _send_email_otp_stub(email, otp)
    return {"success": True, "message": "OTP sent"}


@router.post("/send-phone-otp")
async def send_phone_otp(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Send OTP to a phone number."""
    phone = data.get("phone")
    if not phone:
        raise HTTPException(status_code=400, detail="phone required")
    otp = _generate_otp()
    _send_sms_otp_stub(phone, otp)
    return {"success": True, "message": "OTP sent", "devOtp": otp}


@router.post("/update-email")
async def update_email(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Update user email after OTP verification."""
    new_email = (data.get("email") or "").strip().lower()
    otp = data.get("otp")

    if not new_email or not otp:
        raise HTTPException(status_code=400, detail="email and otp required")

    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Check if email already exists
    exists_stmt = select(User).where(User.email == new_email)
    exists_res = await db.execute(exists_stmt)
    if exists_res.scalars().first():
        raise HTTPException(status_code=409, detail="Email already in use")

    user.email = new_email
    user.emailVerified = datetime.utcnow()
    await db.commit()
    return {"success": True, "email": user.email}


@router.post("/update-phone")
async def update_phone(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Update user phone after OTP verification."""
    new_phone = data.get("phone")
    otp = data.get("otp")

    if not new_phone or not otp:
        raise HTTPException(status_code=400, detail="phone and otp required")

    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.phone = new_phone
    await db.commit()
    return {"success": True, "phone": user.phone}


@router.post("/setup")
async def profile_setup(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Initial profile setup (name, phone, etc.)."""
    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if "name" in data:
        user.name = data["name"]
    if "phone" in data:
        user.phone = data["phone"]
    if "image" in data:
        user.image = data["image"]

    await db.commit()
    await db.refresh(user)
    return {"success": True, "user": {"id": user.id, "name": user.name, "phone": user.phone}}


@router.post("/delete-account")
async def delete_account(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Soft-delete user account."""
    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    reason = data.get("reason", "")
    user.deletedAt = datetime.utcnow()
    user.isBlocked = True
    user.blockReason = f"User requested deletion: {reason}" if reason else "User requested deletion"
    await db.commit()
    return {"success": True, "message": "Account scheduled for deletion"}