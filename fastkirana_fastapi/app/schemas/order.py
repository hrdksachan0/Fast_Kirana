from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Any
from datetime import datetime

class OrderItemIn(BaseModel):
    productId: Optional[str] = None
    name: str
    price: float
    quantity: int
    imageUrl: Optional[str] = None
    selectedVariant: Optional[str] = None
    notes: Optional[str] = None

class OrderCreateIn(BaseModel):
    addressId: str
    orderType: str = "GROCERY"
    restaurantId: Optional[str] = None
    paymentMethod: str = "COD"
    deliveryMethod: str = "DELIVERY"
    notes: Optional[str] = None
    couponCode: Optional[str] = None
    items: List[OrderItemIn] = []

class OrderItemOut(BaseModel):
    id: str
    productId: Optional[str] = None
    name: str
    price: float
    quantity: int
    imageUrl: Optional[str] = None
    selectedVariant: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class OrderOut(BaseModel):
    id: str
    readableId: Optional[str] = None
    userId: str
    addressId: str
    restaurantId: Optional[str] = None
    orderType: str
    status: str
    subtotal: float
    discount: float = 0.0
    deliveryFee: float = 0.0
    total: float
    paymentMethod: str
    paymentStatus: str
    deliveryMethod: str
    notes: Optional[str] = None
    couponCode: Optional[str] = None
    createdAt: datetime
    items: List[OrderItemOut] = []

    model_config = ConfigDict(from_attributes=True)
