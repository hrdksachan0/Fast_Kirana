from fastapi import APIRouter, Depends, HTTPException, status, Body, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import desc
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid

from database import get_db
from models import Cart, CartItem, Product, User
from routers.auth import get_current_user, require_auth

router = APIRouter(prefix="/cart", tags=["Cart"])


def generate_id(prefix: str) -> str:
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def get_user_id(user: Optional[dict]) -> Optional[str]:
    if not user or not isinstance(user, dict):
        return None
    return user.get("id") or user.get("sub")


async def get_or_create_guest_user(guest_id: str, db: AsyncSession) -> Optional[User]:
    clean_id = "".join([c for c in guest_id if c.isalnum() or c in ("_", "-")])[:32]
    if not clean_id:
        return None
    guest_email = f"guest-{clean_id}@fastkirana.com"
    result = await db.execute(select(User).where(User.email == guest_email))
    user = result.scalars().first()
    if not user:
        user = User(
            id=generate_id("usr_"),
            email=guest_email,
            name=f"Guest Shopper ({clean_id[:6]})",
            role="USER",
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return user


async def get_or_create_cart(user_id: str, db: AsyncSession) -> Optional[Cart]:
    result = await db.execute(select(Cart).where(Cart.userId == user_id))
    cart = result.scalars().first()

    if not cart:
        user_check = await db.execute(select(User).where(User.id == user_id))
        user_obj = user_check.scalars().first()
        if not user_obj:
            return None

        cart = Cart(
            id=generate_id("cart_"),
            userId=user_id,
        )
        db.add(cart)
        await db.commit()
        await db.refresh(cart)

    return cart


@router.get("")
async def get_cart(
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's or guest's cart with items and product details.
    """
    user_id = get_user_id(current_user)

    if not user_id and x_guest_id:
        guest_user = await get_or_create_guest_user(x_guest_id, db)
        user_id = guest_user.id if guest_user else None

    if not user_id:
        return {
            "success": True,
            "items": [],
            "subtotal": 0.0,
            "count": 0,
        }

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        return {
            "success": True,
            "items": [],
            "subtotal": 0.0,
            "count": 0,
        }

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
            price = product.price
            if item.selectedVariant and isinstance(product.variants, list):
                variant = next((v for v in product.variants if v.get("name") == item.selectedVariant), None)
                if variant and isinstance(variant.get("price"), (int, float)):
                    price = float(variant["price"])

            item_total = price * item.quantity
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
                    "slug": product.slug,
                    "imageUrl": product.imageUrl,
                    "mrp": product.mrp,
                    "price": price,
                    "discount": product.discount,
                    "unit": product.unit,
                    "stock": product.stock,
                    "isAvailable": product.isAvailable,
                    "tags": product.tags,
                    "variants": product.variants,
                },
                "itemTotal": round(item_total, 2),
            })

    return {
        "success": True,
        "cartId": cart.id,
        "items": items_list,
        "subtotal": round(subtotal, 2),
        "count": len(items_list),
        "updatedAt": cart.updatedAt,
    }


@router.post("")
async def sync_cart(
    payload: dict = Body(...),
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Full cart sync — replace all items for logged in or guest user.
    Expected payload: {"items": [{"productId": "xxx", "quantity": 1, "selectedVariant": null, "notes": ""}]}
    """
    user_id = get_user_id(current_user)
    guest_id = payload.get("guestId") or x_guest_id
    items_data = payload.get("items", [])

    if not isinstance(items_data, list):
        raise HTTPException(status_code=400, detail="items must be a list")

    if not user_id and guest_id:
        guest_user = await get_or_create_guest_user(str(guest_id), db)
        user_id = guest_user.id if guest_user else None

    if not user_id:
        return {"success": True, "message": "No active session to sync cart", "count": 0}

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        raise HTTPException(status_code=500, detail="Failed to find or create cart")

    # Delete existing items
    existing_items_result = await db.execute(
        select(CartItem).where(CartItem.cartId == cart.id)
    )
    existing_items = existing_items_result.scalars().all()
    for item in existing_items:
        await db.delete(item)

    # Filter valid products
    valid_count = 0
    if items_data:
        product_ids = [str(i.get("productId") or "") for i in items_data if i.get("productId")]
        if product_ids:
            p_stmt = select(Product.id).where(Product.id.in_(product_ids))
            p_res = await db.execute(p_stmt)
            valid_pids = set(p_res.scalars().all())

            for item_data in items_data:
                product_id = item_data.get("productId")
                if not product_id or product_id not in valid_pids:
                    continue

                new_item = CartItem(
                    id=generate_id("ci_"),
                    cartId=cart.id,
                    productId=product_id,
                    quantity=max(1, int(item_data.get("quantity", 1))),
                    selectedVariant=item_data.get("selectedVariant"),
                    notes=item_data.get("notes"),
                )
                db.add(new_item)
                valid_count += 1

    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {
        "success": True,
        "message": "Cart synced to database successfully",
        "itemCount": valid_count,
    }


@router.post("/add")
async def add_to_cart(
    payload: dict = Body(...),
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Add item to cart or increase quantity if already exists.
    Expected payload: {"productId": "xxx", "quantity": 1, "selectedVariant": null, "notes": ""}
    """
    user_id = get_user_id(current_user)
    guest_id = payload.get("guestId") or x_guest_id
    product_id = payload.get("productId")
    quantity = int(payload.get("quantity", 1))
    selected_variant = payload.get("selectedVariant")
    notes = payload.get("notes")

    if not product_id:
        raise HTTPException(status_code=400, detail="productId is required")

    if not user_id and guest_id:
        guest_user = await get_or_create_guest_user(str(guest_id), db)
        user_id = guest_user.id if guest_user else None

    if not user_id:
        raise HTTPException(status_code=400, detail="User or guest session is required")

    # Verify product exists
    product_result = await db.execute(select(Product).where(Product.id == product_id))
    product = product_result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if not product.isAvailable:
        raise HTTPException(status_code=400, detail="Product is not available")

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        raise HTTPException(status_code=500, detail="Failed to find or create cart")

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
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Update cart item quantity.
    Expected payload: {"quantity": 2}
    """
    user_id = get_user_id(current_user)

    if not user_id and x_guest_id:
        guest_user = await get_or_create_guest_user(x_guest_id, db)
        user_id = guest_user.id if guest_user else None

    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    quantity = int(payload.get("quantity", 1))
    if quantity < 1:
        raise HTTPException(status_code=400, detail="Quantity must be at least 1")

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        raise HTTPException(status_code=404, detail="Cart not found")

    item_result = await db.execute(
        select(CartItem).where(CartItem.id == item_id, CartItem.cartId == cart.id)
    )
    item = item_result.scalars().first()
    if not item:
        raise HTTPException(status_code=404, detail="Cart item not found")

    item.quantity = quantity
    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {"success": True, "message": "Cart updated"}


@router.delete("/items/{item_id}")
async def remove_cart_item(
    item_id: str,
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Remove item from cart.
    """
    user_id = get_user_id(current_user)

    if not user_id and x_guest_id:
        guest_user = await get_or_create_guest_user(x_guest_id, db)
        user_id = guest_user.id if guest_user else None

    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        raise HTTPException(status_code=404, detail="Cart not found")

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
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Clear all items from cart.
    """
    user_id = get_user_id(current_user)

    if not user_id and x_guest_id:
        guest_user = await get_or_create_guest_user(x_guest_id, db)
        user_id = guest_user.id if guest_user else None

    if not user_id:
        return {"success": True, "message": "Cart already empty"}

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        return {"success": True, "message": "Cart already empty"}

    items_result = await db.execute(select(CartItem).where(CartItem.cartId == cart.id))
    items = items_result.scalars().all()
    for item in items:
        await db.delete(item)

    cart.updatedAt = datetime.utcnow()
    await db.commit()

    return {"success": True, "message": "Cart cleared"}
