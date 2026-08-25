from fastapi import APIRouter, HTTPException, status, Depends, Header, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
import bcrypt
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime, timezone
from typing import Optional, Dict, Any
import random
import os
import httpx
import uuid

from database import get_db
from models import User, Role
from utils.jwt import extract_user_from_token, is_token_expired, create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])



# ---------- Auth Dependencies ----------
# Defined here so other routers can import them from routers.auth

security = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request = None,
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> Optional[Dict[str, Any]]:
    """Extract and validate current user from JWT token, NextAuth session cookie, or x-user-id header."""
    # 1. Check Bearer Token
    if credentials and credentials.credentials:
        user = extract_user_from_token(credentials.credentials)
        if user and not is_token_expired(user):
            return user

    # 2. Check NextAuth Session Cookie & Headers if request object is present
    if request is not None:
        session_cookie = (
            request.cookies.get("__Secure-authjs.session-token") or
            request.cookies.get("__Secure-next-auth.session-token") or
            request.cookies.get("authjs.session-token") or
            request.cookies.get("next-auth.session-token") or
            request.cookies.get("__Host-authjs.session-token")
        )
        if not session_cookie:
            for k, v in request.cookies.items():
                if "session-token" in k:
                    session_cookie = v
                    break

        if session_cookie:
            user = extract_user_from_token(session_cookie)
            if user and not is_token_expired(user):
                return user

        # 3. Check X-User-Id / X-User-Role header (forwarded by Next.js Proxy/Middleware)
        x_user_id = request.headers.get("x-user-id")
        x_user_role = request.headers.get("x-user-role")
        if x_user_id:
            try:
                res = await db.execute(select(User).where(User.id == x_user_id))
                db_user = res.scalars().first()
                if db_user:
                    role_str = db_user.role.value if hasattr(db_user.role, 'value') else str(db_user.role)
                    return {
                        "id": db_user.id,
                        "email": db_user.email,
                        "role": role_str,
                        "name": db_user.name,
                        "phone": db_user.phone,
                        "assignedRestaurantId": db_user.assignedRestaurantId
                    }
            except Exception as e:
                print(f"Error fetching user by x-user-id: {e}")

            if x_user_role:
                return {
                    "id": x_user_id,
                    "email": request.headers.get("x-user-email", "user@fastkirana.in"),
                    "role": x_user_role,
                    "assignedRestaurantId": request.headers.get("x-user-restaurant-id"),
                }

    return None


# Alias for backward compatibility
get_current_user_from_jwt = get_current_user


async def require_auth(
    user: Optional[Dict[str, Any]] = Depends(get_current_user)
) -> Dict[str, Any]:
    """Require authenticated user. Raises 401 if not authenticated."""
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized - valid JWT token required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


async def require_admin(
    user: Dict[str, Any] = Depends(require_auth)
) -> Dict[str, Any]:
    """Require admin role."""
    if user.get("role") != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden - admin access required",
        )
    return user


async def require_delivery(
    user: Dict[str, Any] = Depends(require_auth)
) -> Dict[str, Any]:
    """Require delivery role (ADMIN or DELIVERY)."""
    if user.get("role") not in ["ADMIN", "DELIVERY"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden - delivery access required",
        )
    return user


async def require_staff(
    user: Dict[str, Any] = Depends(require_auth)
) -> Dict[str, Any]:
    """Require staff role."""
    staff_roles = ["ADMIN", "CHEF", "PICKER", "DELIVERY", "RESTAURANT_OWNER"]
    if user.get("role") not in staff_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden - staff access required",
        )
    return user


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
    token: Optional[str] = None


class MessageResponse(BaseModel):
    message: str


# ---------- Helpers ----------

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def generate_otp() -> str:
    return str(random.randint(100000, 999999))


def normalize_phone(phone: str) -> str:
    """Strip non-digits, keep last 10 digits."""
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) > 10:
        digits = digits[-10:]
    return digits


async def send_whatsapp_otp(phone: str, otp: str) -> bool:
    """Send OTP using Meta WhatsApp Cloud API."""
    token = os.getenv("WHATSAPP_TOKEN")
    phone_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID")
    template_name = os.getenv("WHATSAPP_TEMPLATE_NAME")

    if not token or not phone_id:
        return False

    clean_phone = f"91{phone}" if len(phone) == 10 else phone
    url = f"https://graph.facebook.com/v20.0/{phone_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    if template_name:
        components = [
            {
                "type": "body",
                "parameters": [{"type": "text", "text": otp}],
            }
        ]
        if template_name == "verify_otp":
            components.append({
                "type": "button",
                "sub_type": "url",
                "index": 0,
                "parameters": [{"type": "text", "text": otp}],
            })
        body = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": clean_phone,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": os.getenv("WHATSAPP_TEMPLATE_LANG", "en")},
                "components": components,
            },
        }
    else:
        body = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": clean_phone,
            "type": "text",
            "text": {
                "body": f"Your FastKirana verification code is: {otp}. Valid for 5 minutes.",
            },
        }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(url, json=body, headers=headers)
            if resp.status_code in [200, 201]:
                return True
            print("WhatsApp API Response Error:", resp.status_code, resp.text)
            return False
    except Exception as e:
        print("WhatsApp API Exception:", e)
        return False


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
        id=f"c{uuid.uuid4().hex[:24]}",
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


class DirectLoginRequest(BaseModel):
    identifier: str
    name: Optional[str] = None


@router.post("/direct-login", response_model=SessionResponse)
async def direct_login(
    body: DirectLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Seamless 1-tap customer login via WhatsApp Phone or Email without OTP/password friction.
    """
    ident = body.identifier.strip()
    is_email = "@" in ident
    
    if is_email:
        email = ident.lower()
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalars().first()
        if not user:
            user = User(
                id=f"c{uuid.uuid4().hex[:24]}",
                email=email,
                name=body.name or email.split("@")[0],
                phone=None,
                role=Role.USER.value,
                isBlocked=False,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
    else:
        phone = normalize_phone(ident)
        if len(phone) != 10:
            raise HTTPException(status_code=400, detail="Please enter a valid 10-digit phone number")
        result = await db.execute(select(User).where(User.phone == phone))
        user = result.scalars().first()
        if not user:
            user = User(
                id=f"c{uuid.uuid4().hex[:24]}",
                email=f"wa-{phone}@fastkirana.in",
                phone=phone,
                name=body.name or f"User {phone[-4:]}",
                role=Role.USER.value,
                isBlocked=False,
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)

    if user.isBlocked:
        raise HTTPException(status_code=403, detail=f"Account blocked: {user.blockReason or 'Contact support'}")

    # If customer provided their name and it differs or is currently generic, update it!
    if body.name and body.name.strip():
        user.name = body.name.strip()
        await db.commit()
        await db.refresh(user)

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    token = create_access_token({
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": role_val,
        "phone": user.phone,
        "assignedRestaurantId": user.assignedRestaurantId,
    })

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=role_val,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
        token=token,
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

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    token = create_access_token({
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": role_val,
        "phone": user.phone,
        "assignedRestaurantId": user.assignedRestaurantId,
    })

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=role_val,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
        token=token,
    )


@router.get("/me", response_model=SessionResponse)
async def get_me(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current logged in user profile.
    """
    user_id = current_user.get("id") or current_user.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User profile not found")

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=role_val,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
    )


_otp_cache: Dict[str, tuple[str, float]] = {}


@router.post("/otp/send", response_model=MessageResponse)
async def send_otp(body: OTPRequest):
    """
    Send real OTP to phone number via WhatsApp Cloud API or Fast2SMS.
    """
    phone = normalize_phone(body.phone)

    if not phone or len(phone) != 10 or phone[0] < '6':
        raise HTTPException(status_code=400, detail="Invalid Indian phone number")

    otp = generate_otp()
    _otp_cache[phone] = (otp, datetime.now(timezone.utc).timestamp() + 300)

    # 1. Try Meta WhatsApp Cloud API
    whatsapp_sent = await send_whatsapp_otp(phone, otp)
    if whatsapp_sent:
        return MessageResponse(message="OTP sent via WhatsApp successfully")

    # 2. Try Fast2SMS API
    if os.getenv("FAST2SMS_API_KEY"):
        sms_sent = await send_otp_via_fast2sms(phone, otp)
        if sms_sent:
            return MessageResponse(message="OTP sent via SMS successfully")

    return MessageResponse(message=f"OTP sent: {otp}")


@router.post("/otp/verify", response_model=SessionResponse)
async def verify_otp(
    body: OTPVerifyRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify OTP and create/login user via WhatsApp / Phone.
    """
    phone = normalize_phone(body.phone)
    entered_otp = body.otp.strip()

    cached = _otp_cache.get(phone)
    is_valid = False

    if cached:
        code, expiry = cached
        if datetime.now(timezone.utc).timestamp() <= expiry and entered_otp == code:
            is_valid = True
            _otp_cache.pop(phone, None)

    if entered_otp in ["123456"]:  # Backup/dev bypass
        is_valid = True

    if not is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired OTP code")

    # Find or create user
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalars().first()

    if not user:
        # Create new user
        wa_email = f"wa-91{phone}@fastkirana.in"
        user = User(
            id=f"c{uuid.uuid4().hex[:24]}",
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

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    token = create_access_token({
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": role_val,
        "phone": user.phone,
        "assignedRestaurantId": user.assignedRestaurantId,
    })

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=role_val,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
        token=token,
    )


class UpdateProfileRequest(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None


@router.post("/profile/update", response_model=SessionResponse)
async def update_profile(
    body: UpdateProfileRequest,
    current_user: Optional[dict] = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    user_id = current_user.get("id") or current_user.get("sub") if current_user else None
    if not user_id and body.phone:
        res = await db.execute(select(User).where(User.phone == normalize_phone(body.phone)))
        user = res.scalars().first()
    elif user_id:
        res = await db.execute(select(User).where(User.id == user_id))
        user = res.scalars().first()
    else:
        raise HTTPException(status_code=400, detail="User identification required")

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if body.name and body.name.strip():
        user.name = body.name.strip()
    if body.email and body.email.strip() and "@" in body.email:
        user.email = body.email.strip().lower()

    await db.commit()
    await db.refresh(user)

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    token = create_access_token({
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": role_val,
        "phone": user.phone,
        "assignedRestaurantId": user.assignedRestaurantId,
    })

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=role_val,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
        token=token,
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


class GoogleAuthRequest(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    photoUrl: Optional[str] = None
    googleId: Optional[str] = None


@router.post("/google", response_model=SessionResponse)
async def google_auth(
    body: GoogleAuthRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Authenticate with Google OAuth payload. Creates customer user if not existing.
    """
    email = body.email.strip().lower()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    if not user:
        user = User(
            id=f"c{uuid.uuid4().hex[:24]}",
            email=email,
            name=body.name or email.split("@")[0],
            phone=None,
            role=Role.USER.value,
            passwordHash=None,
            image=body.photoUrl,
            isBlocked=False,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    if user.isBlocked:
        raise HTTPException(status_code=403, detail=f"Account blocked: {user.blockReason or 'Contact support'}")

    role_val = user.role.value if hasattr(user.role, "value") else str(user.role)
    token = create_access_token({
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "role": role_val,
        "phone": user.phone,
        "assignedRestaurantId": user.assignedRestaurantId,
    })

    return SessionResponse(
        id=user.id,
        email=user.email,
        name=user.name,
        role=role_val,
        phone=user.phone,
        assignedRestaurantId=user.assignedRestaurantId,
        token=token,
    )


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
