from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import desc
from typing import List, Optional, Dict, Any
import uuid

from database import get_db
from models import Address, User
from routers.auth import require_auth

router = APIRouter(prefix="/addresses", tags=["User Addresses"])


def generate_id(prefix: str = "addr_") -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def get_user_id(user: Dict[str, Any]) -> str:
    return user.get("id") or user.get("sub") or ""


@router.get("")
async def get_user_addresses(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all saved addresses for current authenticated user.
    """
    user_id = get_user_id(current_user)
    stmt = select(Address).where(Address.userId == user_id).order_by(desc(Address.isDefault))
    result = await db.execute(stmt)
    addresses = result.scalars().all()
    return addresses


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_address(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new address for current user.
    Accepts addressLine or houseNo/street/area fields.
    """
    user_id = get_user_id(current_user)

    label = payload.get("label", "Home")
    address_line = payload.get("addressLine", "")
    house_no = payload.get("houseNo", address_line or "123")
    street = payload.get("street", address_line or "Main St")
    area = payload.get("area", payload.get("city", "City Area"))
    city = payload.get("city", "Bangalore")
    pincode = payload.get("pincode", "560001")
    phone = payload.get("phone", current_user.get("phone", ""))
    lat = payload.get("lat")
    lng = payload.get("lng")
    is_default = bool(payload.get("isDefault", False))

    # If this address is set as default, unset other default addresses for user
    if is_default:
        existing_defaults = await db.execute(
            select(Address).where(Address.userId == user_id, Address.isDefault == True)
        )
        for addr in existing_defaults.scalars().all():
            addr.isDefault = False

    new_address = Address(
        id=generate_id("cmr"),
        userId=user_id,
        label=label,
        houseNo=house_no,
        street=street,
        area=area,
        city=city,
        pincode=pincode,
        phone=phone,
        lat=lat,
        lng=lng,
        isDefault=is_default,
    )
    db.add(new_address)
    await db.commit()
    await db.refresh(new_address)
    return new_address


@router.patch("/{address_id}")
async def update_address(
    address_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update an existing address.
    """
    user_id = get_user_id(current_user)
    stmt = select(Address).where(Address.id == address_id, Address.userId == user_id)
    result = await db.execute(stmt)
    address = result.scalars().first()

    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    if "label" in payload:
        address.label = payload["label"]
    if "addressLine" in payload:
        address.street = payload["addressLine"]
    if "houseNo" in payload:
        address.houseNo = payload["houseNo"]
    if "street" in payload:
        address.street = payload["street"]
    if "area" in payload:
        address.area = payload["area"]
    if "city" in payload:
        address.city = payload["city"]
    if "pincode" in payload:
        address.pincode = payload["pincode"]
    if "phone" in payload:
        address.phone = payload["phone"]
    if "lat" in payload:
        address.lat = payload["lat"]
    if "lng" in payload:
        address.lng = payload["lng"]

    if payload.get("isDefault"):
        existing_defaults = await db.execute(
            select(Address).where(Address.userId == user_id, Address.isDefault == True)
        )
        for addr in existing_defaults.scalars().all():
            addr.isDefault = False
        address.isDefault = True

    await db.commit()
    await db.refresh(address)
    return address


@router.delete("/{address_id}")
async def delete_address(
    address_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete an address.
    """
    user_id = get_user_id(current_user)
    stmt = select(Address).where(Address.id == address_id, Address.userId == user_id)
    result = await db.execute(stmt)
    address = result.scalars().first()

    if not address:
        raise HTTPException(status_code=404, detail="Address not found")

    await db.delete(address)
    await db.commit()
    return {"success": True, "message": "Address deleted successfully"}
