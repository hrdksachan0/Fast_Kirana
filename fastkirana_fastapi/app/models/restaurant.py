from sqlalchemy import Column, String, Boolean, Float, Integer, JSON, DateTime
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..core.database import Base

class Restaurant(Base):
    __tablename__ = "restaurants"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    slug = Column(String, unique=True, nullable=False)
    description = Column(String, nullable=True)
    logoUrl = Column(String, nullable=True)
    bannerUrl = Column(String, nullable=True)
    address = Column(String, nullable=True)
    city = Column(String, nullable=True)
    cuisineTags = Column(ARRAY(String), default=[])
    rating = Column(Float, default=4.0)
    reviewCount = Column(Integer, default=0)
    deliveryTime = Column(String, default="25-30 min")
    distance = Column(String, nullable=True)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    isVeg = Column(Boolean, default=false) if False else Column(Boolean, default=False)
    isPureVeg = Column(Boolean, default=False)
    isOpen = Column(Boolean, default=True)
    openTime = Column(String, nullable=True)
    closeTime = Column(String, nullable=True)
    sortOrder = Column(Integer, default=0)
    discountOffer = Column(String, nullable=True)
    discountBadge = Column(String, nullable=True)
    commissionRate = Column(Float, default=0.15)
    ownerPhone = Column(String, nullable=True)
    ownerEmail = Column(String, nullable=True)
    isActive = Column(Boolean, default=True)
    menuSections = Column(JSON, nullable=True)
    createdAt = Column(DateTime, server_default=func.now())
    updatedAt = Column(DateTime, onupdate=func.now())

    products = relationship("Product", back_populates="restaurant")
    orders = relationship("Order", back_populates="restaurant")
