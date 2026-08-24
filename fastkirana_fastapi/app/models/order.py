from sqlalchemy import Column, String, Boolean, Float, Integer, JSON, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..core.database import Base

class Order(Base):
    __tablename__ = "orders"

    id = Column(String, primary_key=True)
    readableId = Column(String, unique=True, nullable=True)
    userId = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    addressId = Column(String, ForeignKey("addresses.id"), nullable=False)
    combinedId = Column(String, nullable=True)
    restaurantId = Column(String, ForeignKey("restaurants.id"), nullable=True, index=True)
    orderType = Column(String, default="GROCERY")

    status = Column(String, default="PENDING", index=True)
    subtotal = Column(Float, nullable=False)
    discount = Column(Float, default=0.0)
    deliveryFee = Column(Float, default=0.0)
    taxes = Column(Float, default=0.0)
    miscFee = Column(Float, default=0.0)
    total = Column(Float, nullable=False)
    paymentMethod = Column(String, default="COD")
    paymentStatus = Column(String, default="PENDING")
    estimatedDelivery = Column(DateTime, nullable=True)
    deliveryMethod = Column(String, default="DELIVERY")
    notes = Column(String, nullable=True)
    couponCode = Column(String, nullable=True)
    createdAt = Column(DateTime, server_default=func.now(), index=True)
    updatedAt = Column(DateTime, onupdate=func.now())

    user = relationship("User", back_populates="orders")
    address = relationship("Address", back_populates="orders")
    restaurant = relationship("Restaurant", back_populates="orders")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(String, primary_key=True)
    orderId = Column(String, ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True)
    productId = Column(String, ForeignKey("products.id", ondelete="SET NULL"), nullable=True, index=True)
    name = Column(String, nullable=False)
    price = Column(Float, nullable=False)
    quantity = Column(Integer, nullable=False)
    imageUrl = Column(String, nullable=True)
    selectedVariant = Column(String, nullable=True)
    costPrice = Column(Float, default=0.0)
    variants = Column(JSON, nullable=True)
    notes = Column(String, nullable=True)

    order = relationship("Order", back_populates="items")
    product = relationship("Product", back_populates="orderItems")
