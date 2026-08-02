import enum
from datetime import datetime
from typing import Optional, List
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, ForeignKey, 
    Text, JSON
)
from sqlalchemy.orm import relationship, Mapped, mapped_column
from database import Base

# Python enums for validation only (NOT mapped as PostgreSQL enum types)
class Role(str, enum.Enum):
    USER = "USER"
    PICKER = "PICKER"
    CHEF = "CHEF"
    RESTAURANT_OWNER = "RESTAURANT_OWNER"
    DELIVERY = "DELIVERY"
    ADMIN = "ADMIN"

class OrderStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    PACKED = "PACKED"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"

class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"

class PaymentMethod(str, enum.Enum):
    COD = "COD"
    UPI = "UPI"
    CARD = "CARD"
    WALLET = "WALLET"

class OrderType(str, enum.Enum):
    GROCERY = "GROCERY"
    RESTAURANT = "RESTAURANT"

# All enum columns use String type since Prisma stores enums as text in PostgreSQL

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    passwordHash: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    image: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    role: Mapped[str] = mapped_column(String, default="USER", index=True)
    assignedStoreId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    assignedRestaurantId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isBlocked: Mapped[bool] = mapped_column(Boolean, default=False)
    liveLat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    liveLng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    orders = relationship("Order", foreign_keys="[Order.userId]", back_populates="user")
    deliveryOrders = relationship("Order", foreign_keys="[Order.deliveryUserId]", back_populates="deliveryUser")
    riderWallet = relationship("RiderWallet", uselist=False, back_populates="user")

class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String)
    slug: Mapped[str] = mapped_column(String, unique=True)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    parentId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("categories.id"), nullable=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0, index=True)

    products = relationship("Product", back_populates="category")

class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    readableId: Mapped[Optional[int]] = mapped_column(Integer, unique=True, nullable=True)
    name: Mapped[str] = mapped_column(String, index=True)
    slug: Mapped[str] = mapped_column(String, unique=True, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    categoryId: Mapped[str] = mapped_column(String, ForeignKey("categories.id"), index=True)
    restaurantId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    mrp: Mapped[float] = mapped_column(Float)
    price: Mapped[float] = mapped_column(Float)
    discount: Mapped[float] = mapped_column(Float, default=0.0)
    unit: Mapped[str] = mapped_column(String)
    stock: Mapped[int] = mapped_column(Integer, default=0)
    isAvailable: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    tags: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    minStock: Mapped[int] = mapped_column(Integer, default=10)
    costPrice: Mapped[float] = mapped_column(Float, default=0.0)
    isFlashDeal: Mapped[bool] = mapped_column(Boolean, default=False)
    isTopPick: Mapped[bool] = mapped_column(Boolean, default=False)
    isBestSeller: Mapped[bool] = mapped_column(Boolean, default=False)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    category = relationship("Category", back_populates="products")

class Address(Base):
    __tablename__ = "addresses"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    label: Mapped[str] = mapped_column(String)
    houseNo: Mapped[str] = mapped_column(String)
    street: Mapped[str] = mapped_column(String)
    area: Mapped[str] = mapped_column(String)
    city: Mapped[str] = mapped_column(String)
    pincode: Mapped[str] = mapped_column(String)
    phone: Mapped[str] = mapped_column(String, default="")
    lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    isDefault: Mapped[bool] = mapped_column(Boolean, default=False)

class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    readableId: Mapped[Optional[int]] = mapped_column(Integer, unique=True, nullable=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    addressId: Mapped[str] = mapped_column(String, ForeignKey("addresses.id"))
    combinedId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    restaurantId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    orderType: Mapped[str] = mapped_column(String, default="GROCERY")
    status: Mapped[str] = mapped_column(String, default="PENDING")
    subtotal: Mapped[float] = mapped_column(Float)
    discount: Mapped[float] = mapped_column(Float, default=0.0)
    deliveryFee: Mapped[float] = mapped_column(Float, default=0.0)
    taxes: Mapped[float] = mapped_column(Float, default=0.0)
    miscFee: Mapped[float] = mapped_column(Float, default=0.0)
    total: Mapped[float] = mapped_column(Float)
    paymentMethod: Mapped[str] = mapped_column(String, default="COD")
    paymentStatus: Mapped[str] = mapped_column(String, default="PENDING")
    deliveryMethod: Mapped[str] = mapped_column(String, default="DELIVERY")
    deliveryUserId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.id"), nullable=True)
    deliveryPhoto: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    deliveryLat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    deliveryLng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    shopName: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    confirmedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    packedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    shippedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    deliveredAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    cashSettledToAdmin: Mapped[bool] = mapped_column(Boolean, default=False)
    cashSettledAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    user = relationship("User", foreign_keys=[userId], back_populates="orders")
    deliveryUser = relationship("User", foreign_keys=[deliveryUserId], back_populates="deliveryOrders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    address = relationship("Address")

class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    orderId: Mapped[str] = mapped_column(String, ForeignKey("orders.id", ondelete="CASCADE"))
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id"))
    name: Mapped[str] = mapped_column(String)
    price: Mapped[float] = mapped_column(Float)
    mrp: Mapped[float] = mapped_column(Float)
    quantity: Mapped[int] = mapped_column(Integer)
    image: Mapped[Optional[str]] = mapped_column(String, nullable=True)

    order = relationship("Order", back_populates="items")
    product = relationship("Product")

class RiderWallet(Base):
    __tablename__ = "rider_wallets"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    cashInHand: Mapped[float] = mapped_column(Float, default=0.0)
    cashLimit: Mapped[float] = mapped_column(Float, default=2000.0)
    totalCollected: Mapped[float] = mapped_column(Float, default=0.0)
    totalDeposited: Mapped[float] = mapped_column(Float, default=0.0)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="riderWallet")

class CashDepositTransaction(Base):
    __tablename__ = "cash_deposit_transactions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    riderId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"))
    adminId: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    amount: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String, default="APPROVED")
    notes: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class StoreSetting(Base):
    __tablename__ = "store_settings"

    key: Mapped[str] = mapped_column(String, primary_key=True)
    value: Mapped[str] = mapped_column(Text)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
