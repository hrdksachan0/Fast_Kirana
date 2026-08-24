from sqlalchemy import Column, String, Boolean, Float, Integer, JSON, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..core.database import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(String, primary_key=True)
    readableId = Column(Integer, unique=True, nullable=True)
    name = Column(String, nullable=False, index=True)
    slug = Column(String, unique=True, nullable=False, index=True)
    description = Column(Text, nullable=True)
    imageUrl = Column(String, nullable=True)
    categoryId = Column(String, ForeignKey("categories.id"), nullable=False, index=True)
    restaurantId = Column(String, ForeignKey("restaurants.id"), nullable=True, index=True)
    mrp = Column(Float, nullable=False)
    price = Column(Float, nullable=False)
    discount = Column(Float, default=0.0)
    unit = Column(String, nullable=False)
    stock = Column(Integer, default=0)
    isAvailable = Column(Boolean, default=True, index=True)
    tags = Column(ARRAY(String), default=[])
    variants = Column(JSON, nullable=True)
    isFlashDeal = Column(Boolean, default=False, index=True)
    isTopPick = Column(Boolean, default=False, index=True)
    isBestSeller = Column(Boolean, default=False, index=True)
    sortOrder = Column(Integer, default=0)
    createdAt = Column(DateTime, server_default=func.now())
    updatedAt = Column(DateTime, onupdate=func.now())

    category = relationship("Category", back_populates="products")
    restaurant = relationship("Restaurant", back_populates="products")
    cartItems = relationship("CartItem", back_populates="product", cascade="all, delete-orphan")
    orderItems = relationship("OrderItem", back_populates="product")
