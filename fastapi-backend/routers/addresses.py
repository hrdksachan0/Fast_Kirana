from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, not_
from typing import Dict, Any, Optional
import uuid

from database import get_db
from models import Address, Order
from routers.auth import require_auth


router = APIRouter(prefix="/addresses", tags=["Addresses"])


def get_last_10_digits(phone: str) -> str:
    """Normalize phone number to return last 10 digits."""
    digits = "".join(c for c in str(phone) if c.isdigit())
    return digits[-10:] if len(digits) >= 10 else digits


def get_user_id(user: dict) -> str:
    return user.get("id") or user.get("sub") or ""


def resolve_fallback_coordinates(lat, lng, pincode, city, street="", area=""):
    try:
        if lat is not None and lng is not None:
            f_lat = float(lat)
            f_lng = float(lng)
            if f_lat != 0.0 or f_lng != 0.0:
                return f_lat, f_lng
    except (ValueError, TypeError):
        pass

    pin = str(pincode or "").strip()
    c = str(city or "").lower().strip()
    s = str(street or "").lower().strip()
    a = str(area or "").lower().strip()

    if pin == "209206" or "ghatampur" in c or "ghatampur" in s or "ghatampur" in a:
        return 26.1534185, 80.1714024
    if pin == "224122" or "akbarpur" in c or "akbarpur" in s:
        return 26.4289124, 82.5399322
    if pin == "816101" or "barharwa" in c or "barharwa" in s or "barharwa" in a:
        return 24.857140, 87.778952
    if pin == "816107" or "pakur" in c or "pakur" in s:
        return 24.857778, 87.774167

    return None, None


@router.get("")
async def get_addresses(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all delivery addresses for the current user (excluding pickup stores).
    """
    user_id = get_user_id(current_user)
    try:
        stmt = select(Address).where(
            Address.userId == user_id,
            not_(Address.label.startswith('STORE_PICKUP'))
        ).order_by(Address.isDefault.desc())
        
        res = await db.execute(stmt)
        return res.scalars().all()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch addresses: {str(e)}"
        )


@router.post("")
async def create_address(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new delivery address.
    """
    user_id = get_user_id(current_user)
    label = payload.get("label")
    house_no = payload.get("houseNo")
    street = payload.get("street")
    area = payload.get("area")
    city = payload.get("city")
    pincode = payload.get("pincode")
    phone = payload.get("phone")
    is_default = payload.get("isDefault", False)
    lat = payload.get("lat")
    lng = payload.get("lng")

    if not all([label, house_no, street, area, city, pincode, phone]):
        raise HTTPException(status_code=400, detail="Missing required fields")

    clean_phone = get_last_10_digits(str(phone))
    if len(clean_phone) != 10:
        raise HTTPException(status_code=400, detail="Mobile number must be a valid 10-digit number")

    try:
        # If setting default, clear other defaults first
        if is_default:
            await db.execute(
                select(Address).where(Address.userId == user_id).with_for_update()
            )
            # Update all to false
            await db.execute(
                Address.__table__.update().where(Address.userId == user_id).values(isDefault=False)
            )

        final_lat, final_lng = resolve_fallback_coordinates(lat, lng, pincode, city, street, area)

        address = Address(
            id=f"addr_{uuid.uuid4().hex[:16]}",
            userId=user_id,
            label=label,
            houseNo=house_no,
            street=street,
            area=area,
            city=city,
            pincode=str(pincode).strip(),
            phone=clean_phone,
            isDefault=bool(is_default),
            lat=final_lat,
            lng=final_lng
        )

        db.add(address)
        await db.commit()
        await db.refresh(address)
        return address
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create address: {str(e)}"
        )


@router.put("")
async def update_address(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update an existing delivery address.
    """
    user_id = get_user_id(current_user)
    address_id = payload.get("id")
    label = payload.get("label")
    house_no = payload.get("houseNo")
    street = payload.get("street")
    area = payload.get("area")
    city = payload.get("city")
    pincode = payload.get("pincode")
    phone = payload.get("phone")
    is_default = payload.get("isDefault", False)
    lat = payload.get("lat")
    lng = payload.get("lng")

    if not all([address_id, label, house_no, street, area, city, pincode, phone]):
        raise HTTPException(status_code=400, detail="Missing required fields")

    clean_phone = get_last_10_digits(str(phone))
    if len(clean_phone) != 10:
        raise HTTPException(status_code=400, detail="Mobile number must be a valid 10-digit number")

    try:
        stmt = select(Address).where(Address.id == address_id)
        res = await db.execute(stmt)
        address = res.scalars().first()

        if not address or address.userId != user_id:
            raise HTTPException(status_code=404, detail="Address not found or unauthorized")

        # If setting default, reset other defaults
        if is_default:
            await db.execute(
                Address.__table__.update().where(Address.userId == user_id).values(isDefault=False)
            )

        address.label = label
        address.houseNo = house_no
        address.street = street
        address.area = area
        address.city = city
        address.pincode = str(pincode).strip()
        address.phone = clean_phone
        address.isDefault = bool(is_default)
        final_lat, final_lng = resolve_fallback_coordinates(lat, lng, pincode, city, street, area)
        address.lat = final_lat
        address.lng = final_lng

        await db.commit()
        await db.refresh(address)
        return address
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update address: {str(e)}"
        )


@router.patch("")
async def update_address_coordinates(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Partially update coordinates (lat/lng) of an address.
    """
    user_id = get_user_id(current_user)
    address_id = payload.get("id")
    lat = payload.get("lat")
    lng = payload.get("lng")

    if not address_id:
        raise HTTPException(status_code=400, detail="Address ID is required")

    try:
        stmt = select(Address).where(Address.id == address_id)
        res = await db.execute(stmt)
        address = res.scalars().first()

        if not address or address.userId != user_id:
            raise HTTPException(status_code=404, detail="Address not found or unauthorized")

        final_lat, final_lng = resolve_fallback_coordinates(lat, lng, pincode, city, street, area)
        address.lat = final_lat
        address.lng = final_lng

        await db.commit()
        await db.refresh(address)
        return address
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update address coordinates: {str(e)}"
        )


@router.delete("")
async def delete_address(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete a delivery address. Validates that the user keeps at least one delivery address,
    and that the address is not linked to any active orders.
    """
    user_id = get_user_id(current_user)
    address_id = payload.get("id")

    if not address_id:
        raise HTTPException(status_code=400, detail="Address ID is required")

    try:
        stmt = select(Address).where(Address.id == address_id)
        res = await db.execute(stmt)
        address = res.scalars().first()

        if not address or address.userId != user_id:
            raise HTTPException(status_code=404, detail="Address not found or unauthorized")

        # 1. Enforce: user must keep at least 1 delivery address
        count_stmt = select(func.count(Address.id)).where(
            Address.userId == user_id,
            not_(Address.label.startswith('STORE_PICKUP'))
        )
        count_res = await db.execute(count_stmt)
        user_address_count = count_res.scalar()

        if user_address_count <= 1:
            raise HTTPException(
                status_code=400,
                detail="You must keep at least one delivery address. Add a new address before deleting this one."
            )

        # 2. Check if this address is linked to any existing orders
        order_stmt = select(func.count(Order.id)).where(Order.addressId == address_id)
        order_res = await db.execute(order_stmt)
        linked_orders_count = order_res.scalar()

        if linked_orders_count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"This address is linked to {linked_orders_count} order(s) and cannot be deleted."
            )

        await db.delete(address)
        await db.commit()
        return {"message": "Address deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete address: {str(e)}"
        )
