from sqlalchemy import Column, String, Boolean, Integer, DateTime
from sqlalchemy.sql import func
from ..core.database import Base

class PromoBanner(Base):
    __tablename__ = "promo_banners"

    id = Column(String, primary_key=True)
    title = Column(String, nullable=False)
    description = Column(String, nullable=False)
    code = Column(String, nullable=False)
    gradient = Column(String, default="from-primary via-rose-500 to-orange-400")
    type = Column(String, default="custom")
    imageUrl = Column(String, nullable=True)
    linkUrl = Column(String, nullable=True)
    isActive = Column(Boolean, default=True)
    sortOrder = Column(Integer, default=0)
    createdAt = Column(DateTime, server_default=func.now())
    updatedAt = Column(DateTime, onupdate=func.now())
