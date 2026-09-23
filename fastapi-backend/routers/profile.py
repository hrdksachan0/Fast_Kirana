from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import text, delete
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
import random
import uuid
import logging

from database import get_db
from models import User, OtpToken
from routers.auth import require_auth, normalize_phone, send_whatsapp_otp

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/profile", tags=["User Profile"])


def get_user_id(user: Dict[str, Any]) -> str:
    return user.get("id") or user.get("sub") or ""


@router.get("/setup")
async def get_profile_setup(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get profile data (name and phone) for current user.
    """
    user_id = get_user_id(current_user)
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalars().first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    return {"name": user.name, "phone": user.phone}


@router.post("/setup")
async def setup_profile(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Set up profile name and phone.
    """
    user_id = get_user_id(current_user)
    name = payload.get("name")
    phone = payload.get("phone")

    if not name or not isinstance(name, str) or not name.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Full name is required"
        )

    if not phone or not isinstance(phone, str) or len(phone.strip()) < 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please enter a valid mobile number (at least 10 digits)"
        )

    try:
        stmt = select(User).where(User.id == user_id)
        result = await db.execute(stmt)
        user = result.scalars().first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        trimmed_name = name.strip()
        normalized_phone = normalize_phone(phone)

        # Check if phone is already registered to another user
        stmt_phone = select(User).where(User.phone == normalized_phone, User.id != user_id)
        result_phone = await db.execute(stmt_phone)
        existing_phone = result_phone.scalars().first()

        if existing_phone:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This phone number is already registered to another account"
            )

        user.name = trimmed_name
        user.phone = normalized_phone
        await db.commit()

        return {"success": True, "message": "Profile updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to setup profile: {str(e)}"
        )


@router.post("/update-name")
async def update_name(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update name.
    """
    user_id = get_user_id(current_user)
    name = payload.get("name")

    if not name or not isinstance(name, str) or not name.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name cannot be empty"
        )

    trimmed_name = name.strip()
    if len(trimmed_name) > 60:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name is too long (maximum 60 characters)"
        )

    try:
        stmt = select(User).where(User.id == user_id)
        result = await db.execute(stmt)
        user = result.scalars().first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        user.name = trimmed_name
        await db.commit()

        return {
            "success": True,
            "name": trimmed_name,
            "message": "Name updated successfully"
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update name: {str(e)}"
        )


@router.post("/send-phone-otp")
async def send_phone_otp(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Generate and send OTP to phone number via WhatsApp for profile update.
    """
    try:
        user_id = get_user_id(current_user)
        phone = payload.get("phone")
        if not phone or not isinstance(phone, str):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mobile number is required"
            )

        normalized_phone = normalize_phone(phone)
        if len(normalized_phone) != 10:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please enter a valid 10-digit mobile number"
            )

        # Check if another user has this phone number already
        stmt_user = select(User).where(User.phone == normalized_phone)
        res_user = await db.execute(stmt_user)
        existing_user = res_user.scalars().first()

        if existing_user and existing_user.id != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This phone number is already registered to another account"
            )

        # Generate 6-digit OTP & 5 min expiry
        otp = str(random.randint(100000, 999999))
        expires_at = datetime.utcnow() + timedelta(minutes=5)
        token_key = f"phone-verify-{normalized_phone}"

        # Delete any existing OTP tokens for this phone verification
        stmt_del = delete(OtpToken).where(OtpToken.email == token_key)
        await db.execute(stmt_del)

        new_otp = OtpToken(
            id=str(uuid.uuid4()),
            email=token_key,
            token=otp,
            expiresAt=expires_at
        )
        db.add(new_otp)
        await db.commit()

        # Dispatch OTP via WhatsApp
        try:
            await send_whatsapp_otp(normalized_phone, otp)
        except Exception as we:
            logger.warning(f"Failed to send WhatsApp OTP: {we}")

        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Send Phone OTP error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification code"
        )


@router.post("/send-email-otp")
async def send_email_otp(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Generate and send OTP to email for profile update.
    """
    try:
        user_id = get_user_id(current_user)
        email = payload.get("email")
        if not email or not isinstance(email, str) or "@" not in email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please enter a valid email address"
            )

        normalized_email = email.strip().lower()

        # Check if another user has this email already
        stmt_user = select(User).where(User.email == normalized_email)
        res_user = await db.execute(stmt_user)
        existing_user = res_user.scalars().first()

        if existing_user and existing_user.id != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This email is already registered to another account"
            )

        # Generate 6-digit OTP & 5 min expiry
        otp = str(random.randint(100000, 999999))
        expires_at = datetime.utcnow() + timedelta(minutes=5)

        # Clear existing OTP tokens for this email
        stmt_del = delete(OtpToken).where(OtpToken.email == normalized_email)
        await db.execute(stmt_del)

        new_otp = OtpToken(
            id=str(uuid.uuid4()),
            email=normalized_email,
            token=otp,
            expiresAt=expires_at
        )
        db.add(new_otp)
        await db.commit()

        logger.info(f"Verification OTP for {normalized_email}: {otp}")
        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"Send Email OTP error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification code"
        )


@router.post("/update-phone")
async def update_phone(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update user's phone number after OTP verification.
    """
    user_id = get_user_id(current_user)
    phone = payload.get("phone")
    otp = payload.get("otp")

    if not phone or not otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number and verification code are required"
        )

    normalized_phone = normalize_phone(phone)
    if len(normalized_phone) != 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid mobile number"
        )

    token_key = f"phone-verify-{normalized_phone}"

    try:
        # Find and verify OTP token
        stmt_otp = select(OtpToken).where(
            OtpToken.email == token_key,
            OtpToken.token == otp,
            OtpToken.expiresAt > datetime.utcnow()
        )
        result_otp = await db.execute(stmt_otp)
        otp_record = result_otp.scalars().first()

        if not otp_record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification code"
            )

        # Check if phone number is taken
        stmt_phone = select(User).where(User.phone == normalized_phone, User.id != user_id)
        result_phone = await db.execute(stmt_phone)
        existing_phone = result_phone.scalars().first()

        if existing_phone:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This phone number is already registered to another account"
            )

        # Update phone
        stmt_user = select(User).where(User.id == user_id)
        result_user = await db.execute(stmt_user)
        user = result_user.scalars().first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        user.phone = normalized_phone

        # Delete OTP record
        await db.delete(otp_record)
        await db.commit()

        return {"success": True, "message": "Phone number updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update phone: {str(e)}"
        )


@router.post("/update-email")
async def update_email(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update user's email address after OTP verification.
    """
    user_id = get_user_id(current_user)
    email = payload.get("email")
    otp = payload.get("otp")

    if not email or not otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email and verification code are required"
        )

    normalized_email = email.strip().lower()

    try:
        # Find and verify OTP token
        stmt_otp = select(OtpToken).where(
            OtpToken.email == normalized_email,
            OtpToken.token == otp,
            OtpToken.expiresAt > datetime.utcnow()
        )
        result_otp = await db.execute(stmt_otp)
        otp_record = result_otp.scalars().first()

        if not otp_record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification code"
            )

        # Check if email is taken
        stmt_email = select(User).where(User.email == normalized_email, User.id != user_id)
        result_email = await db.execute(stmt_email)
        existing_email = result_email.scalars().first()

        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This email is already registered to another account"
            )

        # Update email
        stmt_user = select(User).where(User.id == user_id)
        result_user = await db.execute(stmt_user)
        user = result_user.scalars().first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        user.email = normalized_email

        # Delete OTP record
        await db.delete(otp_record)
        await db.commit()

        return {"success": True, "message": "Email address updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update email: {str(e)}"
        )


@router.delete("/delete-account")
async def delete_account(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Anonymize and soft-delete user account data.
    """
    user_id = get_user_id(current_user)

    try:
        stmt = select(User).where(User.id == user_id)
        result = await db.execute(stmt)
        user = result.scalars().first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        # 1. Delete associated session/token tables via raw SQL
        await db.execute(text("DELETE FROM push_subscriptions WHERE \"userId\" = :user_id"), {"user_id": user_id})
        await db.execute(text("DELETE FROM fcm_tokens WHERE \"userId\" = :user_id"), {"user_id": user_id})
        await db.execute(text("DELETE FROM addresses WHERE \"userId\" = :user_id"), {"user_id": user_id})
        await db.execute(text("DELETE FROM accounts WHERE \"userId\" = :user_id"), {"user_id": user_id})
        await db.execute(text("DELETE FROM sessions WHERE \"userId\" = :user_id"), {"user_id": user_id})

        # 2. Anonymize user record
        user.name = "Deleted User"
        user.email = f"deleted-{user_id[:8]}@anonymized.local"
        user.phone = None
        user.image = None
        user.passwordHash = None
        user.isBlocked = True
        user.blockReason = "User requested account deletion"
        user.blockedAt = datetime.utcnow()

        await db.commit()

        return {
            "success": True,
            "message": "Account personal data anonymized and deleted successfully."
        }
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete account: {str(e)}"
        )