from fastapi import Header, HTTPException, Depends
from sqlalchemy.orm import Session
from .database import get_db
from .config import settings

class CurrentUser:
    def __init__(self, id: str, email: str, role: str, name: str = None, phone: str = None):
        self.id = id
        self.email = email
        self.role = role
        self.name = name
        self.phone = phone

async def get_current_user(
    x_user_id: str = Header(None),
    x_user_email: str = Header(None),
    x_user_role: str = Header(None),
    x_user_name: str = Header(None),
    x_user_phone: str = Header(None),
    authorization: str = Header(None),
    db: Session = Depends(get_db)
) -> CurrentUser:
    # 1. Direct header identification
    if x_user_id:
        return CurrentUser(
            id=x_user_id,
            email=x_user_email or "user@fastkirana.com",
            role=x_user_role or "USER",
            name=x_user_name,
            phone=x_user_phone
        )
    
    # 2. Bearer token fallback / Default Admin
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ")[1]
        # In mobile development / admin, resolve to admin ID
        return CurrentUser(
            id=settings.ADMIN_USER_ID,
            email="admin@fastkirana.com",
            role="ADMIN",
            name="FastKirana Admin",
            phone="+917054470303"
        )

    # 3. Default fallback for express checkout/browsing
    return CurrentUser(
        id=settings.ADMIN_USER_ID,
        email="admin@fastkirana.com",
        role="ADMIN",
        name="FastKirana Admin",
        phone="+917054470303"
    )
