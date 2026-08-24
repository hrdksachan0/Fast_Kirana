from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from .product import ProductOut

class CartItemIn(BaseModel):
    productId: str
    quantity: int = 1
    selectedVariant: Optional[str] = None
    notes: Optional[str] = None

class CartSyncIn(BaseModel):
    items: List[CartItemIn] = []

class CartItemOut(BaseModel):
    id: str
    productId: str
    quantity: int
    selectedVariant: Optional[str] = None
    notes: Optional[str] = None
    product: Optional[ProductOut] = None

    model_config = ConfigDict(from_attributes=True)

class CartOut(BaseModel):
    id: str
    userId: str
    items: List[CartItemOut] = []
    subtotal: float = 0.0
    totalItems: int = 0

    model_config = ConfigDict(from_attributes=True)
