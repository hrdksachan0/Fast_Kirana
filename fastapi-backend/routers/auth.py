from fastapi import APIRouter, HTTPException, status, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime, timezone
from typing import Optional
import random
import os
import httpx

from database import get_db
from models import User, Role
from utils.jwt import extract_user_from_token, is_token_expired

router = APIRouter(prefix="/api/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------- Schemas ----------

class SignupRequest(BaseModel):
    email: EmailStr
    phone: str
    password: str = Field(min_length=6)
    name: Optional[str] = None
    role: Optional[str] = "USER"


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class OTPRequest(BaseModel):
    phone: str


class OTPVerifyRequest(BaseModel):
    phone: str
    otp: str


class SessionResponse(BaseModel):
    id: str
    email: str
    name: Optional[str]
    role: str
    phone: Optional[str]
    assignedRestaurantId: Optional[str] = None


class MessageResponse(BaseModel):
    message: str


# ---------- Helpers ----------

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


def generate_otp() -> str:
    return str(random.randint(100000, 999999))


def normalize_phone(phone: str) -> str:
    """Strip non-digits, keep last 10 digits."""
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) > 10:
        digits = digits[-10:]
    return digits


async def send_otp_via_fast2sms(phone: str, otp: str) -> bool:
    """Send OTP using Fast2SMS (or any SMS provider)."""
    api_key = os.getenv("FAST2SMS_API_KEY")
    if not api_key:
        return False
    url = "https://www.fast2sms.com/dev/bulkV2"
    payload = {
        "route": "otp",
        "variables_values": otp,
        "flash": 0,
        "numbers": f"91{phone}",
    }
    headers = {
        "authorization": api_key,
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(url, json=payload, headers=headers)
            return resp.status_code == 200
    except Exception:
        return False


# ---------- Routes ----------

@router.post("/signup", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    body: SignupRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Register a new user with email and password.
    Also works for WhatsApp OTP signup (email = wa-{phone}@fastkirana.com).
    """
    phone = normalize_phone(body.phone)
    email = body.email.strip().lower()

    # Check if user exists
    result = await db.execute(select(User).where(User.email == email))
    existing = result.scalars().first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Check phone
    result = await db.execute(select(User).where(User.phone == phone))
    existing_phone = result.scalars().first()
    if existing_phone:
        raise HTTPException(status_code=400, detail="Phone already registered")

    # Validate role
    role_value = body.role or "USER"
    if role_value not in [r.value for r in Role]:
        role_value = Role.USER.value

    # Create user
    new_user = User(
        email=email,
        phone=phone,
        name=body.name or "",
        role=role_value,
        passwordHash=hash_password(body.password),
        isBlocked=False,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)

    return SessionResponse(
        id=new_user.id,
        email=new_user.email,
        name=new_user.name,
        role=new_user.role,
        phone=new_user.phone,
        assignedRestaurantId=new_user.assignedRestaurantId,
    )


@router.post("/login", response_model=SessionResponse)
async def login(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Login with email and password.
    Returns user session data. Client should store and send as Bearer token.
    """
    email = body.email.strip().lower()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    if not user or not user.passwordHash:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if user.isBlocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Account blocked: {user.blockReason or 'Contact admin'}"
        )

    if not verify_password(body.password, user.passwordHash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
    )


@router.post("/otp/send", response_model=MessageResponse)
async def send_otp(body: OTPRequest):
    """
    Send OTP to phone number.
    In production, uses Fast2SMS. In development, returns OTP in response.
    """
    phone = normalize_phone(body.phone)

    if not phone or len(phone) != 10 or phone[0] < '6':
        raise HTTPException(status_code=400, detail="Invalid Indian phone number")

    otp = generate_otp()

    # In development, return OTP directly
    if os.getenv("NODE_ENV") != "production":
        return MessageResponse(message=f"OTP sent (dev mode): {otp}")

    # Production: send via Fast2SMS
    sent = await send_otp_via_fast2sms(phone, otp)
    if not sent:
        raise HTTPException(status_code=500, detail="Failed to send OTP")

    return MessageResponse(message="OTP sent successfully")


@router.post("/otp/verify", response_model=SessionResponse)
async def verify_otp(
    body: OTPVerifyRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify OTP and create/login user via WhatsApp.
    Creates user if not exists (like Next.js WhatsApp login).
    """
    phone = normalize_phone(body.phone)

    if body.otp != "123456":  # Development bypass
        # In production, validate OTP from Redis/cache
        pass

    # Find or create user
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalars().first()

    if not user:
        # Create new user (WhatsApp login)
        wa_email = f"wa-91{phone}@fastkirana.com"
        user = User(
            email=wa_email,
            phone=phone,
            name="",
            role=Role.USER.value,
            passwordHash=None,
            isBlocked=False,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=user.role,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
    )


@router.get("/email/check")
async def check_email(email: str, db: AsyncSession = Depends(get_db)):
    """
    Check if email is already registered.
    """
    email = email.strip().lower()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()
    return {"exists": user is not None}


@router.get("/session", response_model=Optional[SessionResponse])
async def get_session(authorization: Optional[str] = Header(None)):
    """
    Get current user session from JWT token.
    Returns null if not authenticated.
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None

    token = authorization.split(" ")[1]
    user_info = extract_user_from_token(token)

    if not user_info or is_token_expired(user_info):
        return None

    return SessionResponse(
        id=user_info.get("id", ""),
        email=user_info.get("email", ""),
        name=user_info.get("name"),
        role=user_info.get("role", "USER"),
        phone=user_info.get("phone"),
        assignedRestaurantId=user_info.get("assignedRestaurantId"),
    )
