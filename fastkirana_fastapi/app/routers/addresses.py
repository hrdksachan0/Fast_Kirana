from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from typing import List, Dict, Any
import uuid
from ..core.database import get_db
from ..core.security import get_current_user, CurrentUser
from ..models.address import Address
from ..schemas.address import AddressCreate, AddressUpdate, AddressOut

router = APIRouter(prefix="/addresses", tags=["Addresses"])

@router.get("", response_model=List[AddressOut])
def get_addresses(
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    addresses = db.query(Address).filter(
        Address.userId == user.id,
        ~Address.label.in_(["STORE_PICKUP", "STORE_PICKUP_RESTAURANT", "STORE_PICKUP_CAFE"])
    ).order_by(Address.isDefault.desc()).all()
    return addresses

@router.post("", response_model=AddressOut)
def create_address(
    data: AddressCreate,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if data.isDefault:
        db.query(Address).filter(Address.userId == user.id).update({"isDefault": False})

    new_addr = Address(
        id=f"addr_{uuid.uuid4().hex[:16]}",
        userId=user.id,
        label=data.label,
        houseNo=data.houseNo,
        street=data.street,
        area=data.area,
        city=data.city,
        pincode=data.pincode,
        phone=data.phone or (user.phone or ""),
        lat=data.lat,
        lng=data.lng,
        isDefault=data.isDefault
    )
    db.add(new_addr)
    db.commit()
    db.refresh(new_addr)
    return new_addr

@router.delete("")
def delete_address(
    body: Dict[str, Any] = Body(...),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    addr_id = body.get("id")
    if not addr_id:
        raise HTTPException(status_code=400, detail="Address ID required")

    addr = db.query(Address).filter(Address.id == addr_id, Address.userId == user.id).first()
    if not addr:
        raise HTTPException(status_code=404, detail="Address not found")

    db.delete(addr)
    db.commit()
    return {"success": True, "message": "Address deleted"}
