from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..core.database import Base

class Cart(Base):
    __tablename__ = "carts"

    id = Column(String, primary_key=True)
    userId = Column(String, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    createdAt = Column(DateTime, server_default=func.now())
    updatedAt = Column(DateTime, onupdate=func.now())

    user = relationship("User", back_populates="cart")
    items = relationship("CartItem", back_populates="cart", cascade="all, delete-orphan")

class CartItem(Base):
    __tablename__ = "cart_items"

    id = Column(String, primary_key=True)
    cartId = Column(String, ForeignKey("carts.id", ondelete="CASCADE"), nullable=False)
    productId = Column(String, ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    quantity = Column(Integer, default=1)
    selectedVariant = Column(String, nullable=True)
    notes = Column(String, nullable=True)

    cart = relationship("Cart", back_populates="items")
    product = relationship("Product", back_populates="cartItems")

    __table_args__ = (
        UniqueConstraint('cartId', 'productId', 'selectedVariant', name='_cart_product_variant_uc'),
    )
