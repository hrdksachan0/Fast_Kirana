from pydantic import BaseModel, ConfigDict
from typing import Optional

class AddressCreate(BaseModel):
    label: str
    houseNo: str
    street: str
    area: str
    city: str = "Ghatampur"
    pincode: str = "209206"
    phone: str = ""
    lat: Optional[float] = None
    lng: Optional[float] = None
    isDefault: bool = False

class AddressUpdate(BaseModel):
    id: str
    label: Optional[str] = None
    houseNo: Optional[str] = None
    street: Optional[str] = None
    area: Optional[str] = None
    city: Optional[str] = None
    pincode: Optional[str] = None
    phone: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    isDefault: Optional[bool] = None

class AddressOut(BaseModel):
    id: str
    userId: str
    label: str
    houseNo: str
    street: str
    area: str
    city: str
    pincode: str
    phone: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    isDefault: bool = False

    model_config = ConfigDict(from_attributes=True)
