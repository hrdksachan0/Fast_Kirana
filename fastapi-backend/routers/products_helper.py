"""
Products Helper Routes
Migrated from Next.js API routes to FastAPI.
"""

from fastapi import APIRouter, Depends, HTTPException, Body, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, or_
from sqlalchemy.orm import selectinload
from typing import Dict, Any, List, Optional

from database import get_db
from models import Product, CartItem, OrderItem, Order, OrderStatus
from routers.auth import require_auth

helper_router = APIRouter(prefix="/products", tags=["Product Helpers"])


@helper_router.post("/validate-cart")
async def validate_cart(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Validate cart items (price, availability, stock)."""
    user_id = current_user.get("id") or current_user.get("sub")
    items = data.get("items", [])

    issues = []
    valid_items = []

    for item in items:
        pid = item.get("productId")
        qty = int(item.get("quantity", 1))
        if not pid or qty < 1:
            issues.append({"productId": pid, "issue": "Invalid item"})
            continue

        result = await db.execute(select(Product).where(Product.id == pid))
        product = result.scalars().first()
        if not product:
            issues.append({"productId": pid, "issue": "Product not found"})
            continue
        if not product.isAvailable:
            issues.append({"productId": pid, "issue": "Product unavailable"})
            continue
        if product.stock < qty:
            issues.append({"productId": pid, "issue": "Out of stock", "availableStock": product.stock})
            continue

        valid_items.append({
            "productId": pid, "name": product.name,
            "price": float(product.price), "quantity": qty,
        })

    return {"validItems": valid_items, "issues": issues}


@helper_router.get("/buy-again")
async def get_buy_again_products(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Products user has bought before."""
    user_id = current_user.get("id") or current_user.get("sub")

    # Get recent delivered orders
    stmt = select(Order).where(
        Order.userId == user_id,
        Order.status == OrderStatus.DELIVERED
    ).order_by(Order.createdAt.desc()).limit(5)

    result = await db.execute(stmt)
    orders = result.scalars().all()

    if not orders:
        return {"products": []}

    # Get product IDs from these orders
    product_ids = []
    for order in orders:
        items_stmt = select(OrderItem).where(OrderItem.orderId == order.id)
        items_result = await db.execute(items_stmt)
        order_items = items_result.scalars().all()
        product_ids.extend([oi.productId for oi in order_items])

    product_ids = list(set(product_ids))[:20]  # Top 20 unique

    # Fetch products
    products_stmt = select(Product).where(
        Product.id.in_(product_ids), Product.isAvailable == True
    )
    products_result = await db.execute(products_stmt)
    products = products_result.scalars().all()

    return {"products": [
        {"id": p.id, "name": p.name, "price": p.price, "imageUrl": p.imageUrl,
         "mrp": p.mrp}
        for p in products
    ]}


@helper_router.get("/live-stock")
async def get_live_stock(
    productId: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """Get live stock for a single product (used by product page)."""
    result = await db.execute(select(Product).where(Product.id == productId))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return {
        "productId": product.id,
        "stock": product.stock,
        "isAvailable": product.isAvailable,
        "minStock": product.minStock,
    }


@helper_router.get("/upsell")
async def get_upsell_products(
    cartId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get upsell/cross-sell products based on cart contents."""
    user_id = current_user.get("id") or current_user.get("sub")
    from models import Cart
    cart_stmt = select(Cart).where(Cart.userId == user_id)
    cart_result = await db.execute(cart_stmt)
    cart = cart_result.scalars().first()

    if not cart:
        return {"products": []}

    items_stmt = select(CartItem).options(selectinload(CartItem.product)).where(CartItem.cartId == cart.id)
    items_result = await db.execute(items_stmt)
    items = items_result.scalars().all()

    if not items:
        return {"products": []}

    categories = list(set(item.product.categoryId for item in items if item.product))
    product_ids_in_cart = list(set(item.productId for item in items))

    stmt = select(Product).where(
        Product.categoryId.in_(categories),
        ~Product.id.in_(product_ids_in_cart),
        Product.isAvailable == True,
    ).order_by(Product.sortOrder).limit(10)

    result = await db.execute(stmt)
    products = result.scalars().all()

    return {"products": [
        {"id": p.id, "name": p.name, "price": p.price, "imageUrl": p.imageUrl,
         "mrp": p.mrp, "discount": p.discount}
        for p in products
    ]}


@helper_router.post("/validate-cart")
async def validate_cart(
    data: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Validate cart items (price, availability, stock)."""
    user_id = current_user.get("id") or current_user.get("sub")
    items = data.get("items", [])
    issues = []
    valid_items = []

    for item in items:
        pid = item.get("productId")
        qty = int(item.get("quantity", 1))
        if not pid or qty < 1:
            issues.append({"productId": pid, "issue": "Invalid item"})
            continue

        result = await db.execute(select(Product).where(Product.id == pid))
        product = result.scalars().first()
        if not product:
            issues.append({"productId": pid, "issue": "Product not found"})
            continue
        if not product.isAvailable:
            issues.append({"productId": pid, "issue": "Product unavailable"})
            continue
        if product.stock < qty:
            issues.append({"productId": pid, "issue": "Out of stock", "availableStock": product.stock})
            continue

        valid_items.append({
            "productId": pid, "name": product.name,
            "price": float(product.price), "quantity": qty,
        })

    return {"validItems": valid_items, "issues": issues}


@helper_router.get("/buy-again")
async def get_buy_again_products(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Products user has bought before."""
    user_id = current_user.get("id") or current_user.get("sub")
    stmt = select(Order).where(
        Order.userId == user_id,
        Order.status == OrderStatus.DELIVERED
    ).order_by(Order.createdAt.desc()).limit(5)

    result = await db.execute(stmt)
    orders = result.scalars().all()

    if not orders:
        return {"products": []}

    product_ids = []
    for order in orders:
        items_stmt = select(OrderItem).where(OrderItem.orderId == order.id)
        items_result = await db.execute(items_stmt)
        order_items = items_result.scalars().all()
        product_ids.extend([oi.productId for oi in order_items])

    product_ids = list(set(product_ids))[:20]
    products_stmt = select(Product).where(
        Product.id.in_(product_ids), Product.isAvailable == True
    )
    products_result = await db.execute(products_stmt)
    products = products_result.scalars().all()

    return {"products": [
        {"id": p.id, "name": p.name, "price": p.price, "imageUrl": p.imageUrl, "mrp": p.mrp}
        for p in products
    ]}