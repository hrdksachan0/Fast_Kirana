from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.orm import relationship
from ..core.database import Base

class Category(Base):
    __tablename__ = "categories"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    slug = Column(String, unique=True, nullable=False)
    imageUrl = Column(String, nullable=True)
    parentId = Column(String, ForeignKey("categories.id"), nullable=True, index=True)
    sortOrder = Column(Integer, default=0, index=True)

    products = relationship("Product", back_populates="category")
