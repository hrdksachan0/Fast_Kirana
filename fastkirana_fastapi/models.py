from typing import Optional
from datetime import datetime
from sqlmodel import SQLModel, Field

class User(SQLModel, table=True):
    __tablename__ = "User"

    id: str = Field(default=None, primary_key=True)
    name: Optional[str] = Field(default=None)
    email: str = Field(unique=True, index=True)
    emailVerified: Optional[datetime] = Field(default=None)
    image: Optional[str] = Field(default=None)
    phone: Optional[str] = Field(default=None)
    passwordHash: Optional[str] = Field(default=None)
    role: str = Field(default="USER") # USER, PICKER, CHEF, DELIVERY, ADMIN
    assignedStoreId: Optional[str] = Field(default=None)
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)

class Address(SQLModel, table=True):
    __tablename__ = "addresses"

    id: str = Field(default=None, primary_key=True)
    userId: str = Field(foreign_key="User.id", index=True)
    label: str
    houseNo: str
    street: str
    area: str
    city: str
    pincode: str
    phone: str = Field(default="")
    lat: Optional[float] = Field(default=None)
    lng: Optional[float] = Field(default=None)
    isDefault: bool = Field(default=False)

class Category(SQLModel, table=True):
    __tablename__ = "categories"

    id: str = Field(default=None, primary_key=True)
    name: str
    slug: str = Field(unique=True, index=True)
    imageUrl: Optional[str] = Field(default=None)
    parentId: Optional[str] = Field(default=None)
    sortOrder: int = Field(default=0)

class Product(SQLModel, table=True):
    __tablename__ = "products"

    id: str = Field(default=None, primary_key=True)
    readableId: Optional[int] = Field(default=None, unique=True)
    name: str = Field(index=True)
    slug: str = Field(unique=True, index=True)
    description: Optional[str] = Field(default=None)
    imageUrl: Optional[str] = Field(default=None)
    categoryId: str = Field(foreign_key="categories.id", index=True)
    mrp: float
    price: float
    discount: float = Field(default=0.0)
    unit: str
    stock: int = Field(default=0)
    isAvailable: bool = Field(default=True, index=True)
    minStock: int = Field(default=10)
    expiryDate: Optional[datetime] = Field(default=None)
    costPrice: float = Field(default=0.0)
    location: Optional[str] = Field(default=None)
    isFlashDeal: bool = Field(default=False, index=True)
    isTopPick: bool = Field(default=False, index=True)
    isBestSeller: bool = Field(default=False, index=True)
    sortOrder: int = Field(default=0)
    createdAt: datetime = Field(default_factory=datetime.utcnow, index=True)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)
    barcode: Optional[str] = Field(default=None, unique=True)

class ProductBatch(SQLModel, table=True):
    __tablename__ = "product_batches"

    id: str = Field(default=None, primary_key=True)
    productId: str = Field(foreign_key="products.id", index=True)
    batchCode: str
    quantity: int
    initialQty: int
    costPrice: float
    expiryDate: datetime = Field(index=True)
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)

class StockLog(SQLModel, table=True):
    __tablename__ = "stock_logs"

    id: str = Field(default=None, primary_key=True)
    productId: str = Field(foreign_key="products.id", index=True)
    quantity: int
    type: str  # "INWARD_GRN", "RETAIL_POS", "ONLINE_ORDER", "MANUAL_ADJUST", "BULK_IMPORT"
    prevStock: int
    newStock: int
    createdAt: datetime = Field(default_factory=datetime.utcnow, index=True)

class Order(SQLModel, table=True):
    __tablename__ = "orders"

    id: str = Field(default=None, primary_key=True)
    readableId: Optional[int] = Field(default=None, unique=True)
    userId: str = Field(index=True)
    addressId: str
    combinedId: Optional[str] = Field(default=None, index=True)
    status: str = Field(default="PENDING", index=True)  # PENDING, CONFIRMED, PACKED, SHIPPED, DELIVERED, CANCELLED
    subtotal: float
    discount: float = Field(default=0.0)
    deliveryFee: float = Field(default=0.0)
    taxes: float = Field(default=0.0)
    miscFee: float = Field(default=0.0)
    total: float
    paymentMethod: str = Field(default="COD")  # COD, UPI, CARD, WALLET
    paymentStatus: str = Field(default="PENDING")  # PENDING, PAID, FAILED, REFUNDED
    estimatedDelivery: Optional[datetime] = Field(default=None)
    deliveryPhoto: Optional[str] = Field(default=None)
    deliveryLat: Optional[float] = Field(default=None)
    deliveryLng: Optional[float] = Field(default=None)
    deliveryMethod: str = Field(default="DELIVERY")
    isB2B: bool = Field(default=False)
    shopName: Optional[str] = Field(default=None)
    shopPhone: Optional[str] = Field(default=None)
    storeId: Optional[str] = Field(default=None, index=True)
    createdAt: datetime = Field(default_factory=datetime.utcnow, index=True)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)
    confirmedAt: Optional[datetime] = Field(default=None)
    packedAt: Optional[datetime] = Field(default=None)
    shippedAt: Optional[datetime] = Field(default=None)
    deliveredAt: Optional[datetime] = Field(default=None)
    notes: Optional[str] = Field(default=None)
    couponCode: Optional[str] = Field(default=None)
    deliveryUserId: Optional[str] = Field(default=None, index=True)
    assignedPickerId: Optional[str] = Field(default=None, index=True)
    assignedChefId: Optional[str] = Field(default=None, index=True)

class OrderItem(SQLModel, table=True):
    __tablename__ = "order_items"

    id: str = Field(default=None, primary_key=True)
    orderId: str = Field(foreign_key="orders.id")
    productId: Optional[str] = Field(default=None)
    name: str
    price: float
    quantity: int
    imageUrl: Optional[str] = Field(default=None)
    selectedVariant: Optional[str] = Field(default=None)
    costPrice: float = Field(default=0.0)

class StoreSetting(SQLModel, table=True):
    __tablename__ = "store_settings"

    id: str = Field(default=None, primary_key=True)
    key: str = Field(unique=True, index=True)
    value: str
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    updatedAt: datetime = Field(default_factory=datetime.utcnow)
