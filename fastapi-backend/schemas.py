"""
Pydantic schemas for FastAPI request/response validation.
Provides type-safe, self-documenting API contracts.
"""

from pydantic import BaseModel, Field, EmailStr, validator, constr
from typing import Optional, List, Dict, Any
from datetime import datetime


# ============================================================
# AUTH SCHEMAS
# ============================================================

class OTPRequest(BaseModel):
    email: str = Field(..., description="Email or 10-digit phone number")

class OTPVerify(BaseModel):
    email: str = Field(..., description="Email or phone used for OTP")
    otp: str = Field(..., min_length=6, max_length=6, description="6-digit OTP")

class LoginRequest(BaseModel):
    email: str = Field(..., description="Email or phone number")
    password: Optional[str] = Field(None, description="Password for password login")

class SignupRequest(BaseModel):
    email: EmailStr
    name: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=15)

class UserOut(BaseModel):
    id: str
    name: Optional[str]
    email: str
    phone: Optional[str]
    role: str
    image: Optional[str]
    assignedRestaurantId: Optional[str]

    class Config:
        from_attributes = True


# ============================================================
# PRODUCT SCHEMAS
# ============================================================

class ProductCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    slug: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=2000)
    categoryId: str = Field(..., min_length=1)
    mrp: float = Field(..., gt=0, le=100000)
    price: float = Field(..., gt=0, le=100000)
    discount: float = Field(default=0, ge=0, le=100)
    unit: str = Field(..., min_length=1, max_length=50)
    stock: int = Field(default=0, ge=0)
    isAvailable: bool = Field(default=True)
    tags: List[str] = Field(default_factory=list)
    variants: Optional[List[Dict[str, Any]]] = None
    minStock: int = Field(default=10, ge=0)
    costPrice: float = Field(default=0, ge=0)
    imageUrl: Optional[str] = None
    isFlashDeal: bool = Field(default=False)
    isTopPick: bool = Field(default=False)
    isBestSeller: bool = Field(default=False)
    sortOrder: int = Field(default=0)
    availableStartTime: Optional[str] = None
    availableEndTime: Optional[str] = None
    barcode: Optional[str] = None

    @validator('price')
    def price_less_than_mrp(cls, v, values):
        if 'mrp' in values and v > values['mrp']:
            raise ValueError('Selling price cannot exceed MRP')
        return v

    @validator('name')
    def name_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Product name is required')
        return v.strip()

class ProductUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    slug: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=2000)
    categoryId: Optional[str] = None
    mrp: Optional[float] = Field(None, gt=0, le=100000)
    price: Optional[float] = Field(None, gt=0, le=100000)
    discount: Optional[float] = Field(None, ge=0, le=100)
    unit: Optional[str] = Field(None, min_length=1, max_length=50)
    stock: Optional[int] = Field(None, ge=0)
    isAvailable: Optional[bool] = None
    tags: Optional[List[str]] = None
    variants: Optional[List[Dict[str, Any]]] = None
    minStock: Optional[int] = Field(None, ge=0)
    costPrice: Optional[float] = Field(None, ge=0)
    imageUrl: Optional[str] = None
    isFlashDeal: Optional[bool] = None
    isTopPick: Optional[bool] = None
    isBestSeller: Optional[bool] = None
    sortOrder: Optional[int] = None
    availableStartTime: Optional[str] = None
    availableEndTime: Optional[str] = None
    barcode: Optional[str] = None


# ============================================================
# ORDER SCHEMAS
# ============================================================

class OrderItem(BaseModel):
    productId: str
    quantity: int = Field(..., gt=0)
    notes: Optional[str] = None

class OrderCreate(BaseModel):
    addressId: str = Field(..., min_length=1)
    paymentMethod: str = Field(..., description="COD, ONLINE, or UPI")
    items: List[OrderItem] = Field(..., min_items=1)
    couponCode: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = Field(None, max_length=500)

    @validator('paymentMethod')
    def valid_payment_method(cls, v):
        allowed = ['COD', 'ONLINE', 'UPI']
        if v.upper() not in allowed:
            raise ValueError(f'Payment method must be one of: {", ".join(allowed)}')
        return v.upper()

class OrderStatusUpdate(BaseModel):
    status: str = Field(..., description="New order status")
    notes: Optional[str] = Field(None, max_length=500)

    @validator('status')
    def valid_status(cls, v):
        allowed = ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED']
        if v.upper() not in allowed:
            raise ValueError(f'Status must be one of: {", ".join(allowed)}')
        return v.upper()


# ============================================================
# ADDRESS SCHEMAS
# ============================================================

class AddressCreate(BaseModel):
    label: Optional[str] = Field(None, max_length=50, description="Home, Work, etc.")
    houseNo: Optional[str] = Field(None, max_length=50)
    street: Optional[str] = Field(None, max_length=200)
    area: Optional[str] = Field(None, max_length=200)
    city: Optional[str] = Field(None, max_length=100)
    pincode: Optional[str] = Field(None, pattern=r'^\d{6}$', description="6-digit PIN")
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    isDefault: bool = Field(default=False)

class AddressUpdate(BaseModel):
    label: Optional[str] = Field(None, max_length=50)
    houseNo: Optional[str] = Field(None, max_length=50)
    street: Optional[str] = Field(None, max_length=200)
    area: Optional[str] = Field(None, max_length=200)
    city: Optional[str] = Field(None, max_length=100)
    pincode: Optional[str] = Field(None, pattern=r'^\d{6}$')
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    isDefault: Optional[bool] = None


# ============================================================
# COUPON SCHEMAS
# ============================================================

class CouponValidateRequest(BaseModel):
    code: str = Field(..., min_length=1, max_length=50)
    subtotal: float = Field(..., gt=0)
    items: List[Dict[str, Any]] = Field(default_factory=list)

class CouponCreate(BaseModel):
    code: str = Field(..., min_length=1, max_length=50)
    discountType: str = Field(..., description="FLAT or PERCENT")
    value: float = Field(..., gt=0)
    minOrder: float = Field(default=0, ge=0)
    maxDiscount: Optional[float] = Field(None, gt=0)
    categoryId: Optional[str] = None
    restaurantId: Optional[str] = None
    oncePerCustomer: bool = Field(default=False)
    maxUses: Optional[int] = Field(None, gt=0)
    expiresAt: Optional[datetime] = None
    isActive: bool = Field(default=True)

    @validator('discountType')
    def valid_discount_type(cls, v):
        if v.upper() not in ['FLAT', 'PERCENT']:
            raise ValueError('discountType must be FLAT or PERCENT')
        return v.upper()


# ============================================================
# CATEGORY SCHEMAS
# ============================================================

class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    slug: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    imageUrl: Optional[str] = None
    parentId: Optional[str] = None
    sortOrder: int = Field(default=0)
    isActive: bool = Field(default=True)

class CategoryUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    slug: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    imageUrl: Optional[str] = None
    parentId: Optional[str] = None
    sortOrder: Optional[int] = None
    isActive: Optional[bool] = None


# ============================================================
# SETTINGS SCHEMAS
# ============================================================

class SettingsUpdate(BaseModel):
    groceryMartOpen: Optional[bool] = None
    cafeOpen: Optional[bool] = None
    restaurantOpen: Optional[bool] = None
    groceryFreeDeliveryThreshold: Optional[float] = Field(None, ge=0)
    cafeFreeDeliveryThreshold: Optional[float] = Field(None, ge=0)
    combinedFreeDeliveryThreshold: Optional[float] = Field(None, ge=0)
    deliveryFee: Optional[float] = Field(None, ge=0)
    taxRate: Optional[float] = Field(None, ge=0, le=100)
    miscFee: Optional[float] = Field(None, ge=0)
    miscFeeLabel: Optional[str] = Field(None, max_length=100)
