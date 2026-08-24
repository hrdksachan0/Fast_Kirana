from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import Dict, Any
import uuid
from ..core.database import get_db
from ..core.security import get_current_user, CurrentUser
from ..models.cart import Cart, CartItem
from ..models.product import Product
from ..schemas.cart import CartOut, CartSyncIn

router = APIRouter(prefix="/cart", tags=["Cart"])

@router.get("", response_model=CartOut)
def get_cart(
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    cart = db.query(Cart).options(
        joinedload(Cart.items).joinedload(CartItem.product).joinedload(Product.category)
    ).filter(Cart.userId == user.id).first()

    if not cart:
        cart = Cart(id=f"cart_{uuid.uuid4().hex[:16]}", userId=user.id)
        db.add(cart)
        db.commit()
        db.refresh(cart)
        return CartOut(id=cart.id, userId=user.id, items=[], subtotal=0.0, totalItems=0)

    subtotal = sum(
        (item.product.price if item.product else 0.0) * item.quantity
        for item in cart.items
    )
    total_items = sum(item.quantity for item in cart.items)

    return CartOut(
        id=cart.id,
        userId=user.id,
        items=cart.items,
        subtotal=subtotal,
        totalItems=total_items
    )

@router.post("", response_model=CartOut)
def sync_cart(
    payload: CartSyncIn,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    cart = db.query(Cart).filter(Cart.userId == user.id).first()
    if not cart:
        cart = Cart(id=f"cart_{uuid.uuid4().hex[:16]}", userId=user.id)
        db.add(cart)
        db.commit()
        db.refresh(cart)

    # Delete existing items
    db.query(CartItem).filter(CartItem.cartId == cart.id).delete()

    # Insert synced items
    for item in payload.items:
        new_item = CartItem(
            id=f"ci_{uuid.uuid4().hex[:16]}",
            cartId=cart.id,
            productId=item.productId,
            quantity=item.quantity,
            selectedVariant=item.selectedVariant,
            notes=item.notes
        )
        db.add(new_item)

    db.commit()
    return get_cart(user=user, db=db)
