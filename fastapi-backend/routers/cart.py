from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import desc
from typing import List, Optional
from datetime import datetime
import uuid

from database import get_db
from models import Cart, CartItem, Product, User
from routers.auth import get_current_user_from_jwt
from schemas import ProductOut

router = APIRouter(prefix="/cart", tags=["Cart"])


def generate_id(prefix: str) -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


@router.get("")
async def get_cart(
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's cart with items and product details.
    """
    # Get or create cart
    result = await db.execute(select(Cart).where(Cart.userId == current_user.id))
    cart = result.scalars().first()

    if not cart:
        cart = Cart(
            id=generate_id("cart_"),
            userId=current_user.id,
        )
        db.add(cart)
        await db.commit()
        await db.refresh(cart)

    # Get cart items with product details
    items_result = await db.execute(
        select(CartItem).where(CartItem.cartId == cart.id)
    )
    cart_items = items_result.scalars().all()

    items_list = []
    subtotal = 0.0

    for item in cart_items:
        product_result = await db.execute(
            select(Product).where(Product.id == item.productId)
        )
        product = product_result.scalars().first()

        if product:
            item_total = product.price * item.quantity
            subtotal += item_total
            items_list.append({
                "id": item.id,
                "productId": item.productId,
                "quantity": item.quantity,
                "selectedVariant": item.selectedVariant,
                "notes": item.notes,
                "product": {
                    "id": product.id,
                    "name": product.name,
                    "price": product.price,
                    "mrp": product.mrp,
                    "imageUrl": product.imageUrl,
                    "unit": product.unit,
                    "isAvailable": product.isAvailable,
                    "stock": product.stock,
                },
                "itemTotal": round(item_total, 2),
            })

    return {
        "id": cart.id,
        "userId": cart.userId,
        "items": items_list,
        "itemCount": len(items_list),
        "subtotal": round(subtotal, 2),
        "deliveryFee": 0.0,
        "total": round(subtotal, 2),
        "updatedAt": cart.updatedAt,
    }


@router.post("/add")
async def add_to_cart(
    payload: dict = Body(...),
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Add item to cart or increase quantity if already exists.
    Expected payload: {"productId": "xxx", "quantity": 1, "selectedVariant": null, "notes": ""}
    """
    product_id = payload.get("productId")
    quantity = int(payload.get("quantity", 1))
    selected_variant = payload.get("selectedVariant")
    notes = payload.get("notes")

    if not product_id:
        raise HTTPException(status_code=400, detail="productId is required")

    # Verify product exists
    product_result = await db.execute(select(Product).where(Product.id == product_id))
    product = product_result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if not product.isAvailable:
        raise HTTPException(status_code=400, detail="Product is not available")

    # Get or create cart
    cart_result = await db.execute(select(Cart).where(Cart.userId == current_user.id))
    cart = cart_result.scalars().first()

    if not cart:
        cart = Cart(
            id=generate_id("cart_"),
            userId=current_user.id,
        )
        db.add(cart)
        await db.commit()
        await db.refresh(cart)

    # Check if item already in cart
    existing_result = await db.execute(
        select(CartItem).where(
            CartItem.cartId == cart.id,
            CartItem.productId == product_id,
            CartItem.selectedVariant == selected_variant,
        )
    )
    existing_item = existing_result.scalars().first()

    if existing_item:
        existing_item.quantity += quantity
    else:
        new_item = CartItem(
            id=generate_id("ci_"),
            cartId=cart.id,
            productId=product_id,
            quantity=quantity,
            selectedVariant=selected_variant,
            notes=notes,
        )
        db.add(new_item)

    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {"success": True, "message": "Item added to cart"}


@router.patch("/items/{item_id}")
async def update_cart_item(
    item_id: str,
    payload: dict = Body(...),
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Update cart item quantity.
    Expected payload: {"quantity": 2}
    """
    quantity = int(payload.get("quantity", 1))

    if quantity < 1:
        raise HTTPException(status_code=400, detail="Quantity must be at least 1")

    # Get user's cart
    cart_result = await db.execute(select(Cart).where(Cart.userId == current_user.id))
    cart = cart_result.scalars().first()
    if not cart:
        raise HTTPException(status_code=404, detail="Cart not found")

    # Get item
    item_result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.cartId == cart.id)
    )
    item = item_result.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    # Check stock
    product_result = await db.execute(select(Product).where(Product.id == item.productId))
    product = product_result.scalars().first()
    if product and quantity > product.stock:
        raise HTTPException(status_code=400, detail=f"Only {product.stock} items available")

    item.quantity = quantity
    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {"success": True, "message": "Cart updated"}


@router.delete("/items/{item_id}")
async def remove_cart_item(
    item_id: str,
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Remove item from cart.
    """
    # Get user's cart
    cart_result = await db.execute(select(Cart).where(Cart.userId == current_user.id))
    cart = cart_result.scalars().first()
    if not cart:
        raise HTTPException(status_code=404, detail="Cart not found")

    # Get item
    item_result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.cartId == cart.id)
    )
    item = item_result.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    await db.delete(item)
    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {"success": True, "message": "Item removed from cart"}


@router.delete("")
async def clear_cart(
    current_user: User = Depends(get_current_user_from_jwt),
    db: AsyncSession = Depends(get_db)
):
    """
    Clear all items from cart.
    """
    cart_result = await db.execute(select(Cart).where(Cart.userId == current_user.id))
    cart = cart_result.scalars().first()
    if not cart:
        return {"success": True, "message": "Cart already empty"}

    # Delete all items
    items_result = await db.execute(select(CartItem).where(CartItem.cartId == cart.id))
    items = items_result.scalars().all()
    for item in items:
        await db.delete(item)

    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {"success": True, "message": "Cart cleared"}
