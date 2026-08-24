from sqlalchemy import Column, String, Boolean, DateTime, Float, Enum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import enum
from ..core.database import Base

class RoleEnum(str, enum.Enum):
    USER = "USER"
    PICKER = "PICKER"
    CHEF = "CHEF"
    RESTAURANT_OWNER = "RESTAURANT_OWNER"
    DELIVERY = "DELIVERY"
    ADMIN = "ADMIN"

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=True)
    email = Column(String, unique=True, index=True, nullable=False)
    emailVerified = Column(DateTime, nullable=True)
    image = Column(String, nullable=True)
    phone = Column(String, index=True, nullable=True)
    passwordHash = Column(String, nullable=True)
    role = Column(String, default="USER")
    assignedStoreId = Column(String, nullable=True)
    assignedRestaurantId = Column(String, nullable=True)
    isBlocked = Column(Boolean, default=False)
    blockReason = Column(String, nullable=True)
    liveLat = Column(Float, nullable=True)
    liveLng = Column(Float, nullable=True)
    createdAt = Column(DateTime, server_default=func.now())
    updatedAt = Column(DateTime, onupdate=func.now())

    addresses = relationship("Address", back_populates="user", cascade="all, delete-orphan")
    cart = relationship("Cart", back_populates="user", uselist=False)
    orders = relationship("Order", back_populates="user")
