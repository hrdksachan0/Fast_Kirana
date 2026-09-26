import enum
import uuid
from datetime import datetime
from typing import Optional, List, Any
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, ForeignKey,
    Text, JSON, Index, UniqueConstraint, Enum as SAEnum
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
    VENDOR = "VENDOR"


class OrderStatus(str, enum.Enum):
    ADMIN_PENDING = "ADMIN_PENDING"
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
    ONLINE = "UPI"


class OrderType(str, enum.Enum):
    GROCERY = "GROCERY"
    RESTAURANT = "RESTAURANT"


# Note: All enum columns use String type since Prisma stores enums as text in PostgreSQL
# This ensures SQLAlchemy models work with Prisma-managed schema

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String, unique=True, index=True, nullable=True)
    emailVerified: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    image: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    passwordHash: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    role: Mapped[str] = mapped_column(SAEnum(Role, name="Role", create_type=False, native_enum=True), default="USER", index=True)
    assignedStoreId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    assignedRestaurantId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    isBlocked: Mapped[bool] = mapped_column(Boolean, default=False)
    blockReason: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    blockedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    deletedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True, index=True)
    liveLat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    liveLng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    orders = relationship("Order", foreign_keys="[Order.userId]", back_populates="user")
    deliveryOrders = relationship("Order", foreign_keys="[Order.deliveryUserId]", back_populates="deliveryUser")
    pickerOrders = relationship("Order", foreign_keys="[Order.assignedPickerId]", back_populates="assignedPicker")
    chefOrders = relationship("Order", foreign_keys="[Order.assignedChefId]", back_populates="assignedChef")
    addresses = relationship("Address", back_populates="user", cascade="all, delete-orphan")
    cart = relationship("Cart", uselist=False, back_populates="user", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="user", cascade="all, delete-orphan")
    riderWallet = relationship("RiderWallet", uselist=False, back_populates="user", cascade="all, delete-orphan")
    riderDeposits = relationship("CashDepositTransaction", foreign_keys="[CashDepositTransaction.riderId]", back_populates="rider")
    adminCollectedCash = relationship("CashDepositTransaction", foreign_keys="[CashDepositTransaction.adminId]", back_populates="admin")
    fcmTokens = relationship("FcmToken", back_populates="user", cascade="all, delete-orphan")


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String)
    slug: Mapped[str] = mapped_column(String, unique=True)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    parentId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("categories.id"), nullable=True, index=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0, index=True)

    parent = relationship("Category", remote_side=[id], backref="children")
    products = relationship("Product", back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    readableId: Mapped[Optional[int]] = mapped_column(Integer, unique=True, nullable=True)
    name: Mapped[str] = mapped_column(String, index=True)
    slug: Mapped[str] = mapped_column(String, unique=True, index=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    categoryId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("categories.id"), nullable=True, index=True)
    restaurantId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("restaurants.id"), nullable=True, index=True)
    mrp: Mapped[float] = mapped_column(Float)
    price: Mapped[float] = mapped_column(Float)
    discount: Mapped[float] = mapped_column(Float, default=0.0)
    unit: Mapped[str] = mapped_column(String)
    stock: Mapped[int] = mapped_column(Integer, default=0)
    isAvailable: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    tags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    variants: Mapped[Optional[Any]] = mapped_column(JSON, nullable=True)
    addons: Mapped[Optional[Any]] = mapped_column(JSON, nullable=True)
    minStock: Mapped[int] = mapped_column(Integer, default=10)
    expiryDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    costPrice: Mapped[float] = mapped_column(Float, default=0.0)
    location: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isFlashDeal: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    isTopPick: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    isBestSeller: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)
    availableStartTime: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    availableEndTime: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    barcode: Mapped[Optional[str]] = mapped_column(String, nullable=True, unique=True)
    vendor: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    vendorId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    category = relationship("Category", back_populates="products")
    restaurant = relationship("Restaurant")
    reviews = relationship("Review", back_populates="product", cascade="all, delete-orphan")
    batches = relationship("ProductBatch", back_populates="product", cascade="all, delete-orphan")
    stockLogs = relationship("StockLog", back_populates="product", cascade="all, delete-orphan")
    images = relationship("ProductImage", back_populates="product", cascade="all, delete-orphan")


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

    user = relationship("User", back_populates="addresses")
    orders = relationship("Order", back_populates="address")


class Cart(Base):
    __tablename__ = "carts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), unique=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="cart")
    items = relationship("CartItem", back_populates="cart", cascade="all, delete-orphan")


class CartItem(Base):
    __tablename__ = "cart_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    cartId: Mapped[str] = mapped_column(String, ForeignKey("carts.id", ondelete="CASCADE"))
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"))
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    selectedVariant: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    cart = relationship("Cart", back_populates="items")
    product = relationship("Product")

    __table_args__ = (
        UniqueConstraint("cartId", "productId", "selectedVariant", name="cart_items_unique"),
    )


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    readableId: Mapped[Optional[str]] = mapped_column(String, unique=True, nullable=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    addressId: Mapped[str] = mapped_column(String, ForeignKey("addresses.id"))
    combinedId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    restaurantId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    orderType: Mapped[str] = mapped_column(SAEnum(OrderType, name="OrderType", create_type=False, native_enum=True), default="GROCERY")
    status: Mapped[str] = mapped_column(SAEnum(OrderStatus, name="OrderStatus", create_type=False, native_enum=True), default="PENDING", index=True)
    subtotal: Mapped[float] = mapped_column(Float)
    discount: Mapped[float] = mapped_column(Float, default=0.0)
    deliveryFee: Mapped[float] = mapped_column(Float, default=0.0)
    taxes: Mapped[float] = mapped_column(Float, default=0.0)
    miscFee: Mapped[float] = mapped_column(Float, default=0.0)
    refundAmount: Mapped[float] = mapped_column(Float, default=0.0)
    total: Mapped[float] = mapped_column(Float)
    paymentMethod: Mapped[str] = mapped_column(SAEnum(PaymentMethod, name="PaymentMethod", create_type=False, native_enum=True), default="COD")
    paymentStatus: Mapped[str] = mapped_column(SAEnum(PaymentStatus, name="PaymentStatus", create_type=False, native_enum=True), default="PENDING")
    estimatedDelivery: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    deliveryPhoto: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    deliveryLat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    deliveryLng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    deliveryMethod: Mapped[str] = mapped_column(String, default="DELIVERY")
    isB2B: Mapped[bool] = mapped_column(Boolean, default=False)
    shopName: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    shopPhone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    storeId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    couponCode: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    confirmedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    packedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    shippedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    deliveredAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    deliveryUserId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.id"), nullable=True, index=True)
    assignedPickerId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.id"), nullable=True, index=True)
    assignedChefId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("users.id"), nullable=True, index=True)
    cashSettledToAdmin: Mapped[bool] = mapped_column(Boolean, default=False)
    cashSettledAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    user = relationship("User", foreign_keys=[userId], back_populates="orders")
    deliveryUser = relationship("User", foreign_keys=[deliveryUserId], back_populates="deliveryOrders")
    assignedPicker = relationship("User", foreign_keys=[assignedPickerId], back_populates="pickerOrders")
    assignedChef = relationship("User", foreign_keys=[assignedChefId], back_populates="chefOrders")
    address = relationship("Address", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_orders_store_status_created", "storeId", "status", "createdAt"),
        Index("idx_orders_user_created", "userId", "createdAt"),
        Index("idx_orders_combined_status", "combinedId", "status"),
        Index("idx_orders_delivery_status", "deliveryUserId", "status"),
    )


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    orderId: Mapped[str] = mapped_column(String, ForeignKey("orders.id", ondelete="CASCADE"), index=True)
    productId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("products.id", ondelete="SET NULL"), nullable=True)
    name: Mapped[str] = mapped_column(String)
    price: Mapped[float] = mapped_column(Float)
    quantity: Mapped[int] = mapped_column(Integer)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    selectedVariant: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    costPrice: Mapped[float] = mapped_column(Float, default=0.0)
    variants: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    refundAmount: Mapped[float] = mapped_column(Float, default=0.0)
    isRefunded: Mapped[bool] = mapped_column(Boolean, default=False)

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
    riderId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    adminId: Mapped[str] = mapped_column(String, ForeignKey("users.id"))
    amount: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String, default="APPROVED")
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    rider = relationship("User", foreign_keys=[riderId], back_populates="riderDeposits")
    admin = relationship("User", foreign_keys=[adminId], back_populates="adminCollectedCash")


class StoreSetting(Base):
    __tablename__ = "store_settings"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: f"ss_{uuid.uuid4().hex[:16]}")
    key: Mapped[str] = mapped_column(String, unique=True, index=True)
    value: Mapped[str] = mapped_column(Text)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __init__(self, **kwargs):
        if "id" not in kwargs or not kwargs["id"]:
            kwargs["id"] = f"ss_{uuid.uuid4().hex[:16]}"
        super().__init__(**kwargs)


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="reviews")
    product = relationship("Product", back_populates="reviews")


class RestaurantReview(Base):
    __tablename__ = "restaurant_reviews"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    restaurantId: Mapped[str] = mapped_column(String, ForeignKey("restaurants.id", ondelete="CASCADE"), index=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")



class Banner(Base):
    __tablename__ = "banners"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String)
    subtitle: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    imageUrl: Mapped[str] = mapped_column(String)
    link: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Store(Base):
    __tablename__ = "stores"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String)
    type: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Restaurant(Base):
    __tablename__ = "restaurants"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String)
    slug: Mapped[str] = mapped_column(String, unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    logoUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    bannerUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    address: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    cuisineTags: Mapped[Optional[list]] = mapped_column(JSON, nullable=True)
    rating: Mapped[float] = mapped_column(Float, default=4.0)
    reviewCount: Mapped[int] = mapped_column(Integer, default=0)
    deliveryTime: Mapped[str] = mapped_column(String, default="30-40 mins")
    distance: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    lat: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lng: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    isVeg: Mapped[bool] = mapped_column(Boolean, default=False)
    isPureVeg: Mapped[bool] = mapped_column(Boolean, default=False)
    isOpen: Mapped[bool] = mapped_column(Boolean, default=True)
    pauseUntil: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    closeReason: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    openTime: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    closeTime: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)
    discountOffer: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    discountBadge: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    commissionRate: Mapped[float] = mapped_column(Float, default=0.15)
    ownerPhone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    ownerEmail: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    deliveryRadiusKm: Mapped[float] = mapped_column(Float, default=5.0)
    storeId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    menuSections: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)



class Coupon(Base):
    __tablename__ = "coupons"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str] = mapped_column(String, unique=True, index=True)
    discountType: Mapped[str] = mapped_column(String)  # FLAT / PERCENT
    value: Mapped[float] = mapped_column(Float)
    minOrder: Mapped[float] = mapped_column(Float, default=0.0)
    maxDiscount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    maxUses: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    usedCount: Mapped[int] = mapped_column(Integer, default=0)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    expiresAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    categoryId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    restaurantId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("restaurants.id", ondelete="CASCADE"), nullable=True)
    oncePerCustomer: Mapped[bool] = mapped_column(Boolean, default=False)
    bogoType: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    triggerVariant: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    rewardVariant: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    defaultFreeDishId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    maxFreeItems: Mapped[Optional[int]] = mapped_column(Integer, default=3)
    badgeText: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    menuSection: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    bogoDishId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    autoApply: Mapped[bool] = mapped_column(Boolean, default=False)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class PayoutRequest(Base):
    __tablename__ = "payout_requests"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    riderId: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    amount: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String, default="PENDING")  # PENDING, APPROVED, REJECTED
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    approvedAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class InventoryLog(Base):
    __tablename__ = "inventory_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id"), index=True)
    changeType: Mapped[str] = mapped_column(String)  # IN, OUT, ADJUST
    quantity: Mapped[int] = mapped_column(Integer)
    previousStock: Mapped[int] = mapped_column(Integer)
    newStock: Mapped[int] = mapped_column(Integer)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class FcmToken(Base):
    __tablename__ = "fcm_tokens"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String, unique=True)
    deviceType: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="fcmTokens")


class OtpToken(Base):
    __tablename__ = "otp_tokens"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    email: Mapped[str] = mapped_column(String)
    token: Mapped[str] = mapped_column(String)
    expiresAt: Mapped[datetime] = mapped_column(DateTime)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class PromoBanner(Base):
    __tablename__ = "promo_banners"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String)
    description: Mapped[str] = mapped_column(String)
    code: Mapped[str] = mapped_column(String)
    gradient: Mapped[str] = mapped_column(String, default="from-primary via-rose-500 to-orange-400")
    type: Mapped[str] = mapped_column(String, default="custom")
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    linkUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    storeId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class DarkStore(Base):
    __tablename__ = "dark_stores"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    name: Mapped[str] = mapped_column(String)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    deliveryRadiusKm: Mapped[Optional[float]] = mapped_column(Float, default=5.0, nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    deliveryPolygon: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    surgeCharge: Mapped[float] = mapped_column(Float, default=0.0)
    groceryOpen: Mapped[bool] = mapped_column(Boolean, default=True)
    pauseUntil: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    closeReason: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    closedByUserId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class StoreInventory(Base):
    __tablename__ = "store_inventories"

    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), primary_key=True)
    storeId: Mapped[str] = mapped_column(String, ForeignKey("dark_stores.id", ondelete="CASCADE"), primary_key=True)
    stock: Mapped[int] = mapped_column(Integer, default=0)
    reservedStock: Mapped[int] = mapped_column(Integer, default=0)
    priceOverride: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    aisleLocation: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    minStockAlert: Mapped[int] = mapped_column(Integer, default=5)
    isAvailable: Mapped[bool] = mapped_column(Boolean, default=True)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ProductBatch(Base):
    __tablename__ = "product_batches"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    batchCode: Mapped[str] = mapped_column(String)
    quantity: Mapped[int] = mapped_column(Integer)
    initialQty: Mapped[int] = mapped_column(Integer)
    costPrice: Mapped[float] = mapped_column(Float)
    expiryDate: Mapped[datetime] = mapped_column(DateTime, index=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    product = relationship("Product", back_populates="batches")


class StockLog(Base):
    __tablename__ = "stock_logs"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    quantity: Mapped[int] = mapped_column(Integer)
    type: Mapped[str] = mapped_column(String)
    prevStock: Mapped[int] = mapped_column(Integer)
    newStock: Mapped[int] = mapped_column(Integer)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    product = relationship("Product", back_populates="stockLogs")


class Vendor(Base):
    __tablename__ = "vendors"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    vendorCode: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    name: Mapped[str] = mapped_column(String, index=True)
    phone: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    companyName: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    gstin: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    upiId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    bankName: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    accountNo: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    ifscCode: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    storeId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    payouts = relationship("VendorPayout", back_populates="vendor", cascade="all, delete-orphan")


class VendorPayout(Base):
    __tablename__ = "vendor_payouts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    vendorId: Mapped[str] = mapped_column(String, ForeignKey("vendors.id", ondelete="CASCADE"), index=True)
    amount: Mapped[float] = mapped_column(Float)
    startDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    endDate: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    paymentMethod: Mapped[str] = mapped_column(String, default="UPI")
    transactionId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    paidAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(String, default="PAID")
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    storeId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    vendor = relationship("Vendor", back_populates="payouts")


class WishlistItem(Base):
    __tablename__ = "wishlist_items"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    product = relationship("Product")
    user = relationship("User")


class PushSubscription(Base):
    __tablename__ = "push_subscriptions"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    userId: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), index=True)
    endpoint: Mapped[str] = mapped_column(String, unique=True, index=True)
    p256dh: Mapped[str] = mapped_column(String)
    auth: Mapped[str] = mapped_column(String)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User")


class PushNotification(Base):
    __tablename__ = "push_notifications"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String)
    body: Mapped[str] = mapped_column(Text)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    linkUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    sentAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    successCount: Mapped[int] = mapped_column(Integer, default=0)
    failureCount: Mapped[int] = mapped_column(Integer, default=0)


class StockAlert(Base):
    __tablename__ = "stock_alerts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    alertType: Mapped[str] = mapped_column(String)
    message: Mapped[str] = mapped_column(Text)
    isRead: Mapped[bool] = mapped_column(Boolean, default=False)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    product = relationship("Product")


class PriceHistory(Base):
    __tablename__ = "price_history"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    oldPrice: Mapped[float] = mapped_column(Float)
    newPrice: Mapped[float] = mapped_column(Float)
    oldMrp: Mapped[float] = mapped_column(Float)
    newMrp: Mapped[float] = mapped_column(Float)
    changeType: Mapped[str] = mapped_column(String)
    changedBy: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    batchId: Mapped[Optional[str]] = mapped_column(String, nullable=True, index=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    product = relationship("Product")


class RestaurantPayout(Base):
    __tablename__ = "restaurant_payouts"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    type: Mapped[str] = mapped_column(String, default="RESTAURANT")
    restaurantId: Mapped[Optional[str]] = mapped_column(String, ForeignKey("restaurants.id"), nullable=True, index=True)
    startDate: Mapped[datetime] = mapped_column(DateTime)
    endDate: Mapped[datetime] = mapped_column(DateTime)
    amount: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String, default="PENDING")
    transactionId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    paidAt: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    restaurant = relationship("Restaurant")


class SuperAdmin(Base):
    __tablename__ = "super_admins"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    phone: Mapped[str] = mapped_column(String, unique=True, index=True)
    email: Mapped[str] = mapped_column(String)
    label: Mapped[str] = mapped_column(String)
    assignedRestaurantId: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    grantedBy: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class StockHold(Base):
    __tablename__ = "stock_holds"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    storeId: Mapped[str] = mapped_column(String, index=True)
    productId: Mapped[str] = mapped_column(String, index=True)
    cartId: Mapped[str] = mapped_column(String)
    quantity: Mapped[int] = mapped_column(Integer)
    expiresAt: Mapped[datetime] = mapped_column(DateTime, index=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("storeId", "productId", "cartId", name="stock_holds_store_product_cart_unique"),
        Index("idx_stock_holds_store_product", "storeId", "productId"),
        Index("idx_stock_holds_expires_at", "expiresAt"),
    )


class ProductImage(Base):
    __tablename__ = "product_images"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    productId: Mapped[str] = mapped_column(String, ForeignKey("products.id", ondelete="CASCADE"), index=True)
    url: Mapped[str] = mapped_column(String)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)

    product = relationship("Product", back_populates="images")


class RestaurantMenu(Base):
    __tablename__ = "restaurant_menus"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    restaurantId: Mapped[str] = mapped_column(String, ForeignKey("restaurants.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    slug: Mapped[str] = mapped_column(String)
    emoji: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0, index=True)
    isActive: Mapped[bool] = mapped_column(Boolean, default=True)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    restaurant = relationship("Restaurant")
    dishes = relationship("FoodDish", back_populates="menu", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("restaurantId", "slug", name="restaurant_menus_restaurant_slug_unique"),
    )


class FoodDish(Base):
    __tablename__ = "food_dishes"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    restaurantId: Mapped[str] = mapped_column(String, ForeignKey("restaurants.id", ondelete="CASCADE"), index=True)
    menuId: Mapped[str] = mapped_column(String, ForeignKey("restaurant_menus.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    slug: Mapped[str] = mapped_column(String)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    imageUrl: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    price: Mapped[float] = mapped_column(Float)
    mrp: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    isVeg: Mapped[bool] = mapped_column(Boolean, default=True)
    isAvailable: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    sortOrder: Mapped[int] = mapped_column(Integer, default=0)
    tags: Mapped[Optional[list]] = mapped_column(JSON, default=list)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updatedAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    restaurant = relationship("Restaurant")
    menu = relationship("RestaurantMenu", back_populates="dishes")
    variants = relationship("DishVariant", back_populates="dish", cascade="all, delete-orphan")


class DishVariant(Base):
    __tablename__ = "dish_variants"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    dishId: Mapped[str] = mapped_column(String, ForeignKey("food_dishes.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String)
    price: Mapped[float] = mapped_column(Float)
    isDefault: Mapped[bool] = mapped_column(Boolean, default=False)
    createdAt: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    dish = relationship("FoodDish", back_populates="variants")