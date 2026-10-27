from fastapi import APIRouter, Depends, HTTPException, status, Body, Header, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import desc, delete, or_
from typing import List, Optional, Dict, Any
from datetime import datetime
import os
import uuid
import hashlib

from database import get_db
from models import Cart, CartItem, Product, User
from routers.auth import get_current_user, require_auth, normalize_phone

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
        display_name = f"Guest Shopper (App #{clean_id[-4:]})" if "g_app_" in clean_id else f"Guest Shopper ({clean_id[:6]})"
        user = User(
            id=generate_id("usr_"),
            email=guest_email,
            name=display_name,
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


async def broadcast_cart_update(cart_id: str, user_id: Optional[str] = None):
    try:
        from routers.websockets import manager
        await manager.broadcast_to_channel("general", {
            "event": "CART_UPDATE",
            "type": "cart-updated",
            "cartId": cart_id,
            "userId": user_id,
            "timestamp": datetime.utcnow().isoformat(),
        })
    except Exception:
        pass



@router.get("")
async def get_cart(
    request: Request = None,
    storeId: Optional[str] = Query(None),
    x_store_id: Optional[str] = Header(None),
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    x_user_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's or guest's cart with items and product details.
    Supports per-hub localized stock & availability hydration.
    """
    user_id = get_user_id(current_user)
    x_internal_secret = request.headers.get("x-internal-secret") if request else None
    internal_secret = os.getenv("INTERNAL_API_SECRET", "").strip()
    is_internal_service = bool(internal_secret and x_internal_secret == internal_secret)

    if not user_id and is_internal_service:
        user_id = x_user_id or (request.headers.get("x-user-id") if request else None)

    # Secure user resolution: derive ownership strictly from verified authentication or internal service secret
    # Device-scoped guest sessions use x-guest-id; unverified phone headers are never proof of account ownership
    guest_id = x_guest_id or (request.headers.get("x-guest-id") if request else None)
    if not user_id and guest_id:
        guest_user = await get_or_create_guest_user(guest_id, db)
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

    # Hydrate per-store inventory overlay if storeId / x-store-id is provided
    effective_store = storeId or x_store_id
    inv_map = {}
    if cart_items and effective_store and effective_store != "all":
        try:
            from models import StoreInventory
            p_ids = [ci.productId for ci in cart_items if ci.productId]
            if p_ids:
                inv_res = await db.execute(
                    select(StoreInventory).where(
                        StoreInventory.storeId == effective_store,
                        StoreInventory.productId.in_(p_ids)
                    )
                )
                for inv in inv_res.scalars().all():
                    inv_map[inv.productId] = inv
        except Exception:
            pass

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

            stock = product.stock
            is_available = product.isAvailable
            if product.id in inv_map:
                inv = inv_map[product.id]
                stock = int(inv.stock or 0)
                is_available = bool(inv.isAvailable if inv.isAvailable is not None else stock > 0)

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
                    "stock": stock,
                    "isAvailable": is_available,
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
    request: Request = None,
    current_user: Optional[dict] = Depends(get_current_user),
    x_guest_id: Optional[str] = Header(None),
    x_user_id: Optional[str] = Header(None),
    x_user_phone: Optional[str] = Header(None),
    x_store_id: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Full cart sync — replace all items for logged in or guest user.
    Expected payload: {"items": [{"productId": "xxx", "quantity": 1, "selectedVariant": null, "notes": ""}]}
    """
    user_id = get_user_id(current_user)
    x_internal_secret = request.headers.get("x-internal-secret") if request else None
    internal_secret = os.getenv("INTERNAL_API_SECRET", "").strip()
    is_internal_service = bool(internal_secret and x_internal_secret == internal_secret)

    if not user_id and is_internal_service:
        user_id = x_user_id or (request.headers.get("x-user-id") if request else None)

    guest_id = payload.get("guestId") or x_guest_id or (request.headers.get("x-guest-id") if request else None)
    store_id = x_store_id or (request.headers.get("x-store-id") if request else None) or payload.get("storeId")
    items_data = payload.get("items", [])

    if not isinstance(items_data, list):
        raise HTTPException(status_code=400, detail="items must be a list")

    # Unauthenticated callers bind strictly to device-scoped guest accounts
    # Passing unverified phone or user numbers never grants ownership of an existing registered user
    if not user_id and guest_id:
        guest_user = await get_or_create_guest_user(str(guest_id), db)
        if guest_user:
            incoming_name = payload.get("userName") or (request.headers.get("x-user-name") if request else None)
            incoming_phone = payload.get("userPhone") or x_user_phone or (request.headers.get("x-user-phone") if request else None)
            if incoming_name and (not guest_user.name or guest_user.name.startswith("Guest Shopper")):
                guest_user.name = incoming_name
            if incoming_phone and not guest_user.phone:
                guest_user.phone = normalize_phone(incoming_phone)
            if store_id:
                guest_user.assignedStoreId = store_id
            await db.commit()
        user_id = guest_user.id if guest_user else None

    # Fallback for unauthenticated client without guest-id header: generate device/IP guest user so cart is NEVER dropped
    if not user_id and request:
        client_ip = request.client.host if request.client else "app_client"
        ip_guest_id = f"g_app_{hashlib.md5(client_ip.encode()).hexdigest()[:12]}"
        guest_user = await get_or_create_guest_user(ip_guest_id, db)
        if guest_user and store_id:
            guest_user.assignedStoreId = store_id
            await db.commit()
        user_id = guest_user.id if guest_user else None

    if not user_id:
        return {"success": True, "message": "No active session to sync cart", "count": 0}

    cart = await get_or_create_cart(user_id, db)
    if not cart:
        raise HTTPException(status_code=500, detail="Failed to find or create cart")

    # Guard against accidental empty-cart wipes from transient local states
    is_explicit_clear = bool(payload.get("isExplicitClear") or payload.get("clearCart"))
    if not items_data and not is_explicit_clear:
        items_result = await db.execute(select(CartItem).where(CartItem.cartId == cart.id))
        existing_items = items_result.scalars().all()
        return {
            "success": True,
            "message": "Cart preserved (empty sync without explicit clear intent)",
            "itemCount": len(existing_items),
        }

    # Validate replacement items BEFORE deleting existing cart items to prevent silent cart loss
    deduped_items: Dict[tuple, Dict[str, Any]] = {}
    valid_count = 0
    if items_data:
        candidate_ids = set()
        for i in items_data:
            pid = str(i.get("productId") or "").strip()
            if not pid:
                raise HTTPException(status_code=400, detail="Invalid item in cart payload: productId cannot be blank")
            candidate_ids.add(pid)
            if "_" in pid:
                parts = pid.split("_")
                for idx in range(1, len(parts)):
                    candidate_ids.add("_".join(parts[:idx]))

        valid_pids = set()
        if candidate_ids:
            p_stmt = select(Product.id).where(Product.id.in_(list(candidate_ids)))
            p_res = await db.execute(p_stmt)
            valid_pids = set(p_res.scalars().all())

        for item_data in items_data:
            raw_product_id = str(item_data.get("productId") or "").strip()
            resolved_pid = None
            variant = item_data.get("selectedVariant") or None

            # 1. Exact catalog ID match takes absolute precedence (e.g. prod_1)
            if raw_product_id in valid_pids:
                resolved_pid = raw_product_id
            elif "_" in raw_product_id:
                # 2. Only decompose compound ID if exact match is NOT present in catalog
                parts = raw_product_id.split("_")
                for idx in range(len(parts) - 1, 0, -1):
                    prefix = "_".join(parts[:idx])
                    if prefix in valid_pids:
                        resolved_pid = prefix
                        if not variant:
                            variant = "_".join(parts[idx:])
                        break

            if not resolved_pid:
                raise HTTPException(
                    status_code=400,
                    detail=f"Product with ID '{raw_product_id}' could not be resolved in catalog"
                )

            key = (resolved_pid, variant)
            qty = max(1, int(item_data.get("quantity", 1)))
            if key in deduped_items:
                deduped_items[key]["quantity"] += qty
            else:
                deduped_items[key] = {
                    "productId": resolved_pid,
                    "quantity": qty,
                    "selectedVariant": variant,
                    "notes": item_data.get("notes"),
                }

    # Atomic delete and insert to ensure no unique constraint violation on insert
    await db.execute(delete(CartItem).where(CartItem.cartId == cart.id))
    await db.flush()

    for item in deduped_items.values():
        new_item = CartItem(
            id=generate_id("ci_"),
            cartId=cart.id,
            productId=item["productId"],
            quantity=item["quantity"],
            selectedVariant=item["selectedVariant"],
            notes=item["notes"],
        )
        db.add(new_item)
        valid_count += 1

    cart.updatedAt = datetime.utcnow()
    await db.commit()
    await broadcast_cart_update(cart.id, user_id)

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
    await broadcast_cart_update(cart.id, user_id)

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
    await broadcast_cart_update(cart.id, user_id)

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
    await broadcast_cart_update(cart.id, user_id)

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
    await broadcast_cart_update(cart.id, user_id)

    return {"success": True, "message": "Cart cleared"}
