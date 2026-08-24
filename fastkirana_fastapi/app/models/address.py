from sqlalchemy import Column, String, Boolean, Float, ForeignKey
from sqlalchemy.orm import relationship
from ..core.database import Base

class Address(Base):
    __tablename__ = "addresses"

    id = Column(String, primary_key=True)
    userId = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    label = Column(String, nullable=False)
    houseNo = Column(String, nullable=False)
    street = Column(String, nullable=False)
    area = Column(String, nullable=False)
    city = Column(String, nullable=False, default="Ghatampur")
    pincode = Column(String, nullable=False, default="209206")
    phone = Column(String, default="")
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    isDefault = Column(Boolean, default=False)

    user = relationship("User", back_populates="addresses")
    orders = relationship("Order", back_populates="address")
