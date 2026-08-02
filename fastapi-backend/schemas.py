from pydantic import BaseModel, Field, EmailStr, ConfigDict
from typing import Optional, List, Any
from datetime import datetime
from models import Role, OrderStatus, PaymentStatus, PaymentMethod, OrderType

# --- User Schemas ---
class UserBase(BaseModel):
    name: Optional[str] = None
    email: EmailStr
    phone: Optional[str] = None
    role: Role = Role.USER

class UserOut(UserBase):
    id: str
    isBlocked: bool = False
    assignedStoreId: Optional[str] = None
    assignedRestaurantId: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

# --- Category Schemas ---
class CategoryOut(BaseModel):
    id: str
    name: str
    slug: str
    imageUrl: Optional[str] = None
    parentId: Optional[str] = None
    sortOrder: int = 0

    model_config = ConfigDict(from_attributes=True)

# --- Product Schemas ---
class ProductBase(BaseModel):
    name: str
    slug: str
    description: Optional[str] = None
    imageUrl: Optional[str] = None
    categoryId: str
    restaurantId: Optional[str] = None
    mrp: float
    price: float
    discount: float = 0.0
    unit: str
    stock: int = 0
    isAvailable: bool = True
    minStock: int = 10
    costPrice: float = 0.0
    isFlashDeal: bool = False
    isTopPick: bool = False
    isBestSeller: bool = False

class ProductOut(ProductBase):
    id: str
    readableId: Optional[int] = None
    category: Optional[CategoryOut] = None
    createdAt: datetime

    model_config = ConfigDict(from_attributes=True)

# --- Order Schemas ---
class OrderItemOut(BaseModel):
    id: str
    productId: str
    name: str
    price: float
    mrp: float
    quantity: int
    image: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class OrderOut(BaseModel):
    id: str
    readableId: Optional[int] = None
    userId: str
    addressId: str
    combinedId: Optional[str] = None
    restaurantId: Optional[str] = None
    orderType: OrderType
    status: OrderStatus
    subtotal: float
    discount: float = 0.0
    deliveryFee: float = 0.0
    taxes: float = 0.0
    miscFee: float = 0.0
    total: float
    paymentMethod: PaymentMethod
    paymentStatus: PaymentStatus
    deliveryUserId: Optional[str] = None
    shopName: Optional[str] = None
    createdAt: datetime
    deliveredAt: Optional[datetime] = None
    items: List[OrderItemOut] = []
    companionOrder: Optional[Any] = None

    model_config = ConfigDict(from_attributes=True)

# --- Rider Wallet & Cash Schemas ---
class RiderWalletOut(BaseModel):
    cashInHand: float
    cashLimit: float
    totalCollected: float
    totalDeposited: float
    isLocked: bool
    isWarning: bool
    remainingLimit: float

class CashDepositRequest(BaseModel):
    riderId: str
    amount: float
    notes: Optional[str] = "Daily Cash Deposit to Admin"

class CashDepositLogOut(BaseModel):
    id: str
    riderName: str
    riderPhone: str
    adminName: str
    amount: float
    notes: Optional[str] = None
    createdAt: datetime

# --- Financial Summary Schemas ---
class FinancialSummaryOut(BaseModel):
    onlineRevenueToday: float
    deliveredCodToday: float
    counterCashToday: float
    totalCashDepositedToday: float
    pendingRiderCash: float
    activeRidersCount: int
