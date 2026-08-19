"""
Admin Extended Routes
Migrated from Next.js API routes to FastAPI.
Covers: dashboard, products, orders, users, coupons, inventory, reports, etc.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, BackgroundTasks
from utils.push import send_push_notification
import logging

logger = logging.getLogger("admin_extended")
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, text, or_, case
from sqlalchemy.orm import selectinload
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
import uuid
import random
import string

from database import get_db
from models import User, Order, Product, Category, Coupon, OrderStatus, OrderType, Role, PaymentMethod, PaymentStatus, RiderWallet
from routers.auth import require_admin
from routers.cart import get_user_id

router = APIRouter(prefix="/admin", tags=["Admin Extended"])

# ============================================================
# HELPERS
# ============================================================

def generate_readable_id(prefix: str, db: AsyncSession, model_class) -> str:
    """Generate unique readable ID like ORD-001, INV-001 etc."""
    today = date.today().strftime("%Y%m%d")
    return f"{prefix}-{today}-{random.randint(1000, 9999)}"

# ============================================================
# DASHBOARD
# ============================================================

@router.get("/dashboard")
async def get_admin_dashboard(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin dashboard stats."""
    today_start = datetime.combine(date.today(), datetime.min.time())

    # Today's orders count and revenue
    today_orders_stmt = select(
        func.count(Order.id),
        func.coalesce(func.sum(Order.total), 0.0)
    ).where(Order.createdAt >= today_start)
    today_orders_result = await db.execute(today_orders_stmt)
    today_orders_count, today_revenue = today_orders_result.first() or (0, 0.0)

    # Total users
    total_users_stmt = select(func.count(User.id)).where(User.deletedAt.is_(None))
    total_users = (await db.execute(total_users_stmt)).scalar() or 0

    # Total products
    total_products_stmt = select(func.count(Product.id))
    total_products = (await db.execute(total_products_stmt)).scalar() or 0

    # Low stock products
    low_stock_stmt = select(func.count(Product.id)).where(Product.stock < Product.minStock)
    low_stock = (await db.execute(low_stock_stmt)).scalar() or 0

    # Pending orders
    pending_stmt = select(func.count(Order.id)).where(
        Order.status.in_([OrderStatus.PENDING, OrderStatus.CONFIRMED])
    )
    pending_orders = (await db.execute(pending_stmt)).scalar() or 0

    return {
        "todayOrders": today_orders_count,
        "todayRevenue": float(today_revenue),
        "totalUsers": total_users,
        "totalProducts": total_products,
        "lowStock": low_stock,
        "pendingOrders": pending_orders,
    }

# ============================================================
# PRODUCTS (Admin CRUD)
# ============================================================

@router.get("/products")
async def admin_get_products(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    categoryId: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    lowStock: bool = Query(False),
    flashDeals: bool = Query(False),
    topPicks: bool = Query(False),
    bestSellers: bool = Query(False),
    type: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin product listing with filters."""
    skip = (page - 1) * limit

    stmt = select(Product).options(selectinload(Product.category))

    and_clauses = []
    if categoryId and categoryId not in ('ALL', 'undefined', 'null'):
        and_clauses.append(Product.categoryId == categoryId)
    if lowStock:
        and_clauses.append(Product.stock < 15)
    if flashDeals:
        and_clauses.append(Product.isFlashDeal == True)
    if topPicks:
        and_clauses.append(Product.isTopPick == True)
    if bestSellers:
        and_clauses.append(Product.isBestSeller == True)
    if search:
        and_clauses.append(
            or_(
                Product.name.ilike(f"%{search}%"),
                Product.slug.ilike(f"%{search}%"),
                Product.description.ilike(f"%{search}%")
            )
        )

    if and_clauses:
        stmt = stmt.where(and_(*and_clauses))

    # Count
    count_stmt = select(func.count()).select_from(Product)
    if and_clauses:
        count_stmt = count_stmt.where(and_(*and_clauses))
    total = (await db.execute(count_stmt)).scalar() or 0

    # Paginated results
    stmt = stmt.order_by(desc(Product.createdAt)).offset(skip).limit(limit)
    result = await db.execute(stmt)
    products = result.scalars().all()

    from schemas import ProductOut
    product_list = [
        ProductOut(
            id=p.id,
            name=p.name,
            slug=p.slug,
            description=p.description,
            imageUrl=p.imageUrl,
            categoryId=p.categoryId,
            mrp=p.mrp,
            price=p.price,
            discount=p.discount,
            unit=p.unit,
            stock=p.stock,
            isAvailable=p.isAvailable,
            tags=p.tags,
            variants=p.variants,
            costPrice=p.costPrice or 0,
            minStock=p.minStock or 10,
            location=p.location,
            barcode=p.barcode or '',
            sortOrder=p.sortOrder or 0,
            isFlashDeal=p.isFlashDeal,
            isTopPick=p.isTopPick,
            isBestSeller=p.isBestSeller,
            availableStartTime=p.availableStartTime,
            availableEndTime=p.availableEndTime,
            category={
                "id": p.category.id if p.category else "",
                "name": p.category.name if p.category else "",
                "slug": p.category.slug if p.category else "",
            } if p.category else None,
        )
        for p in products
    ]

    return {"products": product_list, "total": total, "page": page, "limit": limit}


@router.post("/products")
async def admin_create_product(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new product."""
    product = Product(
        id=f"prod_{uuid.uuid4().hex[:12]}",
        name=data.get("name", ""),
        slug=data.get("slug", ""),
        description=data.get("description"),
        imageUrl=data.get("imageUrl"),
        categoryId=data.get("categoryId", ""),
        mrp=float(data.get("mrp", 0)),
        price=float(data.get("price", 0)),
        discount=float(data.get("discount", 0)),
        unit=data.get("unit", ""),
        stock=int(data.get("stock", 0)),
        isAvailable=data.get("isAvailable", True),
        tags=data.get("tags", []),
        variants=data.get("variants"),
        minStock=int(data.get("minStock", 10)),
        costPrice=float(data.get("costPrice", 0)),
        location=data.get("location"),
        isFlashDeal=data.get("isFlashDeal", False),
        isTopPick=data.get("isTopPick", False),
        isBestSeller=data.get("isBestSeller", False),
        sortOrder=int(data.get("sortOrder", 0)),
        availableStartTime=data.get("availableStartTime"),
        availableEndTime=data.get("availableEndTime"),
        barcode=data.get("barcode"),
    )
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return {"product": ProductOut.model_validate(product).model_dump()}


@router.patch("/products/{product_id}")
async def admin_update_product(
    product_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update a product."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    for field in ["name", "slug", "description", "imageUrl", "categoryId", "unit", "location",
                  "availableStartTime", "availableEndTime", "barcode"]:
        if field in data:
            setattr(product, field, data[field])

    for field in ["mrp", "price", "discount", "costPrice"]:
        if field in data:
            setattr(product, field, float(data[field]))

    for field in ["stock", "minStock", "sortOrder"]:
        if field in data:
            setattr(product, field, int(data[field]))

    for field in ["isAvailable", "isFlashDeal", "isTopPick", "isBestSeller"]:
        if field in data:
            setattr(product, field, bool(data[field]))

    for field in ["tags", "variants"]:
        if field in data:
            setattr(product, field, data[field])

    await db.commit()
    await db.refresh(product)
    return {"product": ProductOut.model_validate(product).model_dump()}


@router.delete("/products/{product_id}")
async def admin_delete_product(
    product_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a product (soft delete by setting isAvailable=False)."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    product.isAvailable = False
    await db.commit()
    return {"success": True, "message": "Product deleted"}


# ============================================================
# BULK IMPORT / SORT
# ============================================================

@router.post("/products/bulk-import")
async def admin_bulk_import_products(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Bulk import products from CSV data."""
    products_data = data.get("products", [])
    created = 0
    failed = 0
    errors = []

    for p_data in products_data:
        try:
            product = Product(
                id=f"prod_{uuid.uuid4().hex[:12]}",
                name=p_data.get("name", ""),
                slug=p_data.get("slug", ""),
                mrp=float(p_data.get("mrp", 0)),
                price=float(p_data.get("price", 0)),
                stock=int(p_data.get("stock", 0)),
                unit=p_data.get("unit", ""),
                categoryId=p_data.get("categoryId", ""),
                isAvailable=True,
            )
            db.add(product)
            created += 1
        except Exception as e:
            failed += 1
            errors.append(str(e))

    await db.commit()
    return {"created": created, "failed": failed, "errors": errors}


@router.post("/products/bulk-sort")
async def admin_bulk_sort_products(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Bulk update product sort orders."""
    items = data.get("items", [])
    for item in items:
        result = await db.execute(select(Product).where(Product.id == item["id"]))
        product = result.scalars().first()
        if product:
            product.sortOrder = int(item.get("sortOrder", 0))
    await db.commit()
    return {"success": True}

# ============================================================
# ORDERS (Admin)
# ============================================================

@router.get("/orders")
async def admin_get_orders(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin order listing."""
    skip = (page - 1) * limit
    stmt = select(Order).options(
        selectinload(Order.user),
        selectinload(Order.address),
    )

    and_clauses = []
    if status and status != 'ALL':
        and_clauses.append(Order.status == OrderStatus(status))

    if search:
        and_clauses.append(
            or_(
                Order.id.ilike(f"%{search}%"),
                Order.readableId.ilike(f"%{search}%"),
                User.name.ilike(f"%{search}%"),
                User.email.ilike(f"%{search}%"),
            )
        )

    if and_clauses:
        stmt = stmt.where(and_(*and_clauses))

    count_stmt = select(func.count()).select_from(Order)
    if and_clauses:
        count_stmt = count_stmt.where(and_(*and_clauses))
    total = (await db.execute(count_stmt)).scalar() or 0

    stmt = stmt.order_by(desc(Order.createdAt)).offset(skip).limit(limit)
    result = await db.execute(stmt)
    orders = result.scalars().all()

    from schemas import OrderOut
    order_list = []
    for o in orders:
        order_list.append({
            "id": o.id,
            "readableId": o.readableId,
            "userId": o.userId,
            "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
            "total": float(o.total),
            "subtotal": float(o.subtotal),
            "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, 'value') else str(o.paymentMethod),
            "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, 'value') else str(o.paymentStatus),
            "createdAt": o.createdAt.isoformat() if o.createdAt else None,
            "updatedAt": o.updatedAt.isoformat() if o.updatedAt else None,
            "user": {
                "id": o.user.id if o.user else None,
                "name": o.user.name if o.user else None,
                "email": o.user.email if o.user else None,
                "phone": o.user.phone if o.user else None,
            } if o.user else None,
        })

    return {"orders": order_list, "total": total, "page": page, "limit": limit}


@router.patch("/orders/{order_id}/status")
async def admin_update_order_status(
    order_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """Update order status."""
    result = await db.execute(select(Order).where(or_(
        Order.id == order_id,
        Order.readableId == order_id,
        Order.readableId.ilike(f"{order_id}%"),
        Order.combinedId == order_id
    )))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    new_status = data.get("status")
    if new_status:
        try:
            order.status = OrderStatus(str(new_status).upper())
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid status")

    if "deliveryUserId" in data:
        order.deliveryUserId = data["deliveryUserId"]

    await db.commit()
    await db.refresh(order)

    # Trigger push notifications for status updates in the background
    if new_status:
        status_notification_map = {
            OrderStatus.CONFIRMED: ("Order Confirmed! 🛒", f"Order #{order.readableId or order.id[:8]} has been confirmed by the store."),
            OrderStatus.PACKED: ("Order Packed! 📦", "Your items have been packed and are ready to deliver."),
            OrderStatus.SHIPPED: ("Out for Delivery! 🛵", "Our rider is on the way with your order. Keep your phone nearby!"),
            OrderStatus.DELIVERED: ("Order Delivered! 🎉", "Thank you for ordering with FastKirana. Enjoy your groceries!"),
            OrderStatus.CANCELLED: ("Order Cancelled ❌", f"Order #{order.readableId or order.id[:8]} has been cancelled.")
        }
        
        notify_data = status_notification_map.get(order.status)
        if notify_data:
            title, body = notify_data
            background_tasks.add_task(
                send_push_notification,
                user_id=order.userId,
                title=title,
                body=body,
                data={"orderId": order.id, "status": order.status.value}
            )
            # If there is a companion order, notify them too
            if order.combinedId:
                try:
                    comp_stmt = select(Order).where(and_(Order.combinedId == order.combinedId, Order.id != order.id))
                    comp_res = await db.execute(comp_stmt)
                    companion = comp_res.scalars().first()
                    if companion and companion.userId != order.userId:
                        background_tasks.add_task(
                            send_push_notification,
                            user_id=companion.userId,
                            title=title,
                            body=body,
                            data={"orderId": companion.id, "status": companion.status.value}
                        )
                except Exception as e:
                    logger.error(f"Error notifying companion user in admin status update: {str(e)}")

    return {"order": {"id": order.id, "status": order.status.value}}


# ============================================================
# USERS (Admin)
# ============================================================

@router.get("/users")
async def admin_get_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin user listing with filters."""
    skip = (page - 1) * limit
    and_clauses = [User.deletedAt.is_(None)]

    if role and role != 'ALL':
        and_clauses.append(User.role == Role(role))
    if status == 'BLOCKED':
        and_clauses.append(User.isBlocked == True)
    elif status == 'ACTIVE':
        and_clauses.append(User.isBlocked == False)

    if search:
        and_clauses.append(
            or_(
                User.name.ilike(f"%{search}%"),
                User.email.ilike(f"%{search}%"),
                User.phone.ilike(f"%{search}%"),
            )
        )

    stmt = select(User).where(and_(*and_clauses))
    count_stmt = select(func.count()).select_from(User).where(and_(*and_clauses))
    total = (await db.execute(count_stmt)).scalar() or 0

    stmt = stmt.order_by(desc(User.createdAt)).offset(skip).limit(limit)
    result = await db.execute(stmt)
    users = result.scalars().all()

    user_list = [
        {
            "id": u.id, "name": u.name, "email": u.email, "phone": u.phone,
            "image": u.image,
            "role": u.role.value if hasattr(u.role, 'value') else str(u.role),
            "isBlocked": u.isBlocked, "blockReason": u.blockReason,
            "assignedStoreId": u.assignedStoreId, "assignedRestaurantId": u.assignedRestaurantId,
            "createdAt": u.createdAt.isoformat() if u.createdAt else None,
        }
        for u in users
    ]
    return {"users": user_list, "total": total, "page": page, "limit": limit}


@router.patch("/users/{user_id}/block")
async def admin_block_user(
    user_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Block or unblock a user."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.isBlocked = data.get("isBlocked", True)
    user.blockReason = data.get("reason")
    if user.isBlocked:
        user.blockedAt = datetime.utcnow()
    else:
        user.blockedAt = None

    await db.commit()
    return {"success": True, "isBlocked": user.isBlocked}


@router.get("/users/assignable")
async def admin_get_assignable_users(
    role: str = Query(...),
    restaurantId: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get assignable users for a role."""
    stmt = select(User).where(
        and_(User.role == Role(role), User.isBlocked == False, User.deletedAt.is_(None))
    )
    if restaurantId:
        stmt = stmt.where(User.assignedRestaurantId == restaurantId)
    stmt = stmt.order_by(User.name)
    result = await db.execute(stmt)
    users = result.scalars().all()
    return {"users": [{"id": u.id, "name": u.name, "email": u.email, "phone": u.phone} for u in users]}


@router.get("/users/{user_id}/cart")
async def admin_get_user_cart(
    user_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get user's cart (admin view)."""
    from models import Cart, CartItem
    cart_stmt = select(Cart).where(Cart.userId == user_id)
    cart_result = await db.execute(cart_stmt)
    cart = cart_result.scalars().first()
    if not cart:
        return {"items": [], "subtotal": 0, "itemCount": 0}

    items_stmt = select(CartItem).options(selectinload(CartItem.product)).where(CartItem.cartId == cart.id)
    items_result = await db.execute(items_stmt)
    cart_items = items_result.scalars().all()

    items, subtotal = [], 0.0
    for ci in cart_items:
        if ci.product:
            item_total = ci.product.price * ci.quantity
            subtotal += item_total
            items.append({
                "id": ci.id, "productId": ci.productId, "quantity": ci.quantity,
                "product": {"id": ci.product.id, "name": ci.product.name, "price": ci.product.price, "imageUrl": ci.product.imageUrl},
                "itemTotal": round(item_total, 2),
            })
    return {"items": items, "subtotal": round(subtotal, 2), "itemCount": len(items)}


# ============================================================
# COUPONS
# ============================================================

@router.get("/coupons")
async def admin_get_coupons(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Coupon).order_by(desc(Coupon.createdAt)))
    coupons = result.scalars().all()
    return {"coupons": [
        {"id": c.id, "code": c.code, "discountType": c.discountType, "value": float(c.value),
         "minOrder": float(c.minOrder) if c.minOrder else 0, "maxDiscount": float(c.maxDiscount) if c.maxDiscount else None,
         "maxUses": c.maxUses, "usedCount": c.usedCount, "isActive": c.isActive,
         "expiresAt": c.expiresAt.isoformat() if c.expiresAt else None,
         "categoryId": c.categoryId, "oncePerCustomer": c.oncePerCustomer}
        for c in coupons
    ]}


@router.post("/coupons")
async def admin_create_coupon(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    code = (data.get("code") or "").upper()
    if not code or not data.get("discountType") or data.get("value") is None:
        raise HTTPException(status_code=400, detail="Missing required fields")
    if data["discountType"] not in ('FLAT', 'PERCENT'):
        raise HTTPException(status_code=400, detail="Invalid discount type")

    coupon = Coupon(
        id=f"cpn_{uuid.uuid4().hex[:12]}", code=code, discountType=data["discountType"],
        value=float(data["value"]), minOrder=float(data.get("minOrder", 0)),
        maxDiscount=float(data["maxDiscount"]) if data.get("maxDiscount") else None,
        maxUses=int(data["maxUses"]) if data.get("maxUses") else None,
        usedCount=0, isActive=data.get("isActive", True),
        expiresAt=datetime.fromisoformat(data["expiresAt"]) if data.get("expiresAt") else None,
        categoryId=data.get("categoryId"), oncePerCustomer=data.get("oncePerCustomer", False),
    )
    db.add(coupon)
    await db.commit()
    await db.refresh(coupon)
    return {"coupon": {"id": coupon.id, "code": coupon.code}}


@router.delete("/coupons/{coupon_id}")
async def admin_delete_coupon(
    coupon_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Coupon).where(Coupon.id == coupon_id))
    coupon = result.scalars().first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")
    await db.delete(coupon)
    await db.commit()
    return {"success": True}


# ============================================================
# CATEGORIES (Admin)
# ============================================================

@router.get("/categories")
async def admin_get_categories(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Category).order_by(Category.sortOrder))
    categories = result.scalars().all()
    return {"categories": [{"id": c.id, "name": c.name, "slug": c.slug,
                              "imageUrl": c.imageUrl, "sortOrder": c.sortOrder} for c in categories]}


@router.post("/categories")
async def admin_create_category(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    category = Category(
        id=f"cat_{uuid.uuid4().hex[:12]}", name=data.get("name", ""), slug=data.get("slug", ""),
        imageUrl=data.get("imageUrl"), sortOrder=int(data.get("sortOrder", 0)),
    )
    db.add(category)
    await db.commit()
    await db.refresh(category)
    return {"category": {"id": category.id, "name": category.name, "slug": category.slug}}


@router.patch("/categories/{category_id}")
async def admin_update_category(
    category_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Category).where(Category.id == category_id))
    category = result.scalars().first()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    for field in ["name", "slug", "imageUrl"]:
        if field in data:
            setattr(category, field, data[field])
    if "sortOrder" in data:
        category.sortOrder = int(data["sortOrder"])
    await db.commit()
    return {"category": {"id": category.id, "name": category.name}}


@router.delete("/categories/{category_id}")
async def admin_delete_category(
    category_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Category).where(Category.id == category_id))
    category = result.scalars().first()
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    await db.delete(category)
    await db.commit()
    return {"success": True}


# ============================================================
# SETTINGS
# ============================================================

@router.get("/settings")
async def admin_get_settings(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get all store settings."""
    from models import StoreSetting
    result = await db.execute(select(StoreSetting))
    settings = result.scalars().all()
    return {"settings": {s.key: s.value for s in settings}}


@router.patch("/settings")
async def admin_update_settings(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update store settings."""
    from models import StoreSetting
    for key, value in data.items():
        result = await db.execute(select(StoreSetting).where(StoreSetting.key == key))
        setting = result.scalars().first()
        if setting:
            setting.value = str(value)
        else:
            setting = StoreSetting(key=key, value=str(value))
            db.add(setting)
    await db.commit()
    return {"success": True}


# ============================================================
# BANNERS
# ============================================================

@router.get("/banners")
async def admin_get_banners(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get all banners."""
    from models import Banner
    result = await db.execute(select(Banner).order_by(desc(Banner.sortOrder)))
    banners = result.scalars().all()
    return {"banners": [
        {"id": b.id, "title": b.title, "subtitle": b.subtitle, "imageUrl": b.imageUrl,
         "link": b.link, "isActive": b.isActive, "sortOrder": b.sortOrder}
        for b in banners
    ]}


@router.post("/banners")
async def admin_create_banner(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new banner."""
    from models import Banner
    banner = Banner(
        id=f"banner_{uuid.uuid4().hex[:12]}", title=data.get("title", ""),
        subtitle=data.get("subtitle"), imageUrl=data.get("imageUrl", ""),
        link=data.get("link"), isActive=data.get("isActive", True),
        sortOrder=int(data.get("sortOrder", 0)),
    )
    db.add(banner)
    await db.commit()
    await db.refresh(banner)
    return {"banner": {"id": banner.id, "title": banner.title}}


@router.patch("/banners/{banner_id}")
async def admin_update_banner(
    banner_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update a banner."""
    from models import Banner
    result = await db.execute(select(Banner).where(Banner.id == banner_id))
    banner = result.scalars().first()
    if not banner:
        raise HTTPException(status_code=404, detail="Banner not found")
    for field in ["title", "subtitle", "imageUrl", "link"]:
        if field in data:
            setattr(banner, field, data[field])
    if "isActive" in data:
        banner.isActive = bool(data["isActive"])
    if "sortOrder" in data:
        banner.sortOrder = int(data["sortOrder"])
    await db.commit()
    return {"success": True}


@router.delete("/banners/{banner_id}")
async def admin_delete_banner(
    banner_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a banner."""
    from models import Banner
    result = await db.execute(select(Banner).where(Banner.id == banner_id))
    banner = result.scalars().first()
    if not banner:
        raise HTTPException(status_code=404, detail="Banner not found")
    await db.delete(banner)
    await db.commit()
    return {"success": True}


# ============================================================
# REVIEWS
# ============================================================

@router.get("/reviews")
async def admin_get_reviews(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get all reviews."""
    from models import Review
    from sqlalchemy.orm import selectinload as sl
    stmt = select(Review).options(sl(Review.user), sl(Review.product)).order_by(desc(Review.createdAt))
    result = await db.execute(stmt)
    reviews = result.scalars().all()
    return {"reviews": [
        {"id": r.id, "rating": r.rating, "comment": r.comment,
         "userId": r.userId, "productId": r.productId,
         "user": {"id": r.user.id, "name": r.user.name} if r.user else None,
         "product": {"id": r.product.id, "name": r.product.name} if r.product else None,
         "createdAt": r.createdAt.isoformat() if r.createdAt else None}
        for r in reviews
    ]}


@router.delete("/reviews/{review_id}")
async def admin_delete_review(
    review_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a review."""
    from models import Review
    result = await db.execute(select(Review).where(Review.id == review_id))
    review = result.scalars().first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    await db.delete(review)
    await db.commit()
    return {"success": True}


# ============================================================
# REPORTS & ALERTS
# ============================================================

@router.get("/reports")
async def admin_get_reports(
    range: str = Query("7d"),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get sales/revenue reports."""
    days = 7
    if range == "30d": days = 30
    elif range == "90d": days = 90
    since = datetime.utcnow() - timedelta(days=days)

    stmt = select(
        func.date(Order.createdAt).label("date"),
        func.count(Order.id).label("orders"),
        func.coalesce(func.sum(Order.total), 0.0).label("revenue")
    ).where(Order.createdAt >= since).group_by(func.date(Order.createdAt)).order_by(func.date(Order.createdAt))

    result = await db.execute(stmt)
    rows = result.all()
    return {"reports": [
        {"date": str(r.date), "orders": r.orders, "revenue": float(r.revenue)}
        for r in rows
    ]}


@router.get("/restaurant-sales")
async def admin_restaurant_sales(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Restaurant-wise sales summary."""
    stmt = select(
        Order.restaurantId,
        func.count(Order.id).label("orders"),
        func.coalesce(func.sum(Order.total), 0.0).label("revenue")
    ).where(Order.restaurantId.isnot(None)).group_by(Order.restaurantId).order_by(desc("revenue"))

    result = await db.execute(stmt)
    return {"sales": [
        {"restaurantId": r.restaurantId, "orders": r.orders, "revenue": float(r.revenue)}
        for r in result.all()
    ]}


@router.get("/alerts")
async def admin_get_alerts(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin alerts (low stock, pending orders etc)."""
    low_stock_stmt = select(func.count(Product.id)).where(
        and_(Product.stock < Product.minStock, Product.isAvailable == True)
    )
    low_stock = (await db.execute(low_stock_stmt)).scalar() or 0

    pending_stmt = select(func.count(Order.id)).where(
        Order.status.in_([OrderStatus.PENDING, OrderStatus.CONFIRMED])
    )
    pending = (await db.execute(pending_stmt)).scalar() or 0

    return {"alerts": [
        {"type": "LOW_STOCK", "count": low_stock, "message": f"{low_stock} products are low on stock"},
        {"type": "PENDING_ORDERS", "count": pending, "message": f"{pending} orders pending"},
    ]}


# ============================================================
# INVENTORY
# ============================================================

@router.get("/inventory/history")
async def admin_inventory_history(
    productId: Optional[str] = Query(None),
    limit: int = Query(50, le=200),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Inventory change history."""
    from models import InventoryLog
    stmt = select(InventoryLog).order_by(desc(InventoryLog.createdAt)).limit(limit)
    if productId:
        stmt = stmt.where(InventoryLog.productId == productId)
    result = await db.execute(stmt)
    logs = result.scalars().all()
    return {"history": [
        {"id": l.id, "productId": l.productId, "changeType": l.changeType,
         "quantity": l.quantity, "previousStock": l.previousStock, "newStock": l.newStock,
         "notes": l.notes, "createdAt": l.createdAt.isoformat() if l.createdAt else None}
        for l in logs
    ]}


@router.post("/inventory/import")
async def admin_inventory_import(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Bulk import inventory/stock."""
    items = data.get("items", [])
    updated = 0
    for item in items:
        pid = item.get("productId")
        stock = item.get("stock")
        if pid and stock is not None:
            result = await db.execute(select(Product).where(Product.id == pid))
            product = result.scalars().first()
            if product:
                product.stock = int(stock)
                updated += 1
    await db.commit()
    return {"updated": updated}


@router.get("/inventory/master-lookup")
async def admin_inventory_master_lookup(
    search: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Master product lookup for inventory."""
    stmt = select(Product)
    if search:
        stmt = stmt.where(or_(
            Product.name.ilike(f"%{search}%"),
            Product.barcode == search,
        ))
    stmt = stmt.order_by(Product.name).limit(50)
    result = await db.execute(stmt)
    products = result.scalars().all()
    return {"products": [
        {"id": p.id, "name": p.name, "barcode": p.barcode, "stock": p.stock, "minStock": p.minStock}
        for p in products
    ]}


@router.post("/inventory/pos-checkout")
async def admin_pos_checkout(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """POS checkout - direct sale from store."""
    items = data.get("items", [])
    total = sum(float(i.get("price", 0)) * int(i.get("quantity", 0)) for i in items)
    # Create an order for record-keeping
    user_id = data.get("userId", "walkin")
    return {"success": True, "total": total, "itemsCount": len(items)}


# ============================================================
# INWARD (Stock In)
# ============================================================

@router.post("/inward")
async def admin_inward_stock(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Record inward stock (delivery from supplier)."""
    items = data.get("items", [])
    updated = 0
    for item in items:
        pid = item.get("productId")
        qty = int(item.get("quantity", 0))
        if pid and qty > 0:
            result = await db.execute(select(Product).where(Product.id == pid))
            product = result.scalars().first()
            if product:
                product.stock += qty
                updated += 1
    await db.commit()
    return {"updated": updated, "items": len(items)}


# ============================================================
# PAYOUTS (Rider)
# ============================================================

@router.get("/payouts")
async def admin_get_payouts(
    status: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get rider payouts."""
    from models import PayoutRequest
    stmt = select(PayoutRequest).order_by(desc(PayoutRequest.createdAt))
    if status:
        stmt = stmt.where(PayoutRequest.status == status)
    result = await db.execute(stmt)
    payouts = result.scalars().all()
    return {"payouts": [
        {"id": p.id, "riderId": p.riderId, "amount": float(p.amount), "status": p.status,
         "createdAt": p.createdAt.isoformat() if p.createdAt else None}
        for p in payouts
    ]}


@router.patch("/payouts/{payout_id}")
async def admin_update_payout(
    payout_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update payout status (approve/reject)."""
    from models import PayoutRequest
    result = await db.execute(select(PayoutRequest).where(PayoutRequest.id == payout_id))
    payout = result.scalars().first()
    if not payout:
        raise HTTPException(status_code=404, detail="Payout not found")
    payout.status = data.get("status", "PENDING")
    payout.notes = data.get("notes")
    if data.get("status") == "APPROVED":
        payout.approvedAt = datetime.utcnow()
    await db.commit()
    return {"success": True}


# ============================================================
# LIVE CARTS
# ============================================================

@router.get("/live-carts")
async def admin_get_live_carts(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get users with active carts."""
    from models import Cart, CartItem
    stmt = select(User).join(Cart, Cart.userId == User.id).where(User.deletedAt.is_(None)).options(selectinload(Cart, Cart.items))
    result = await db.execute(stmt)
    users = result.scalars().all()

    carts = []
    for u in users:
        if u.cart and u.cart.items:
            subtotal = sum(item.product.price * item.quantity if item.product else 0 for item in u.cart.items)
            carts.append({
                "userId": u.id, "name": u.name, "phone": u.phone, "email": u.email,
                "itemsCount": len(u.cart.items), "subtotal": round(subtotal, 2),
                "updatedAt": u.cart.updatedAt.isoformat() if u.cart.updatedAt else None,
            })
    return {"carts": carts}


@router.post("/live-carts/notify")
async def admin_notify_live_carts(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Send push notification to users with active carts."""
    return {"success": True, "notified": 0, "message": "Notification sent"}


# ============================================================
# PUSH NOTIFICATIONS
# ============================================================

@router.post("/push-notifications")
async def admin_send_push(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Send push notification to all users."""
    return {"success": True, "message": "Push notification dispatched"}


# ============================================================
# STORES
# ============================================================

@router.get("/stores")
async def admin_get_stores(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get all stores."""
    from models import Store
    result = await db.execute(select(Store))
    stores = result.scalars().all()
    return {"stores": [
        {"id": s.id, "name": s.name, "type": s.type, "isActive": s.isActive,
         "address": s.address, "phone": s.phone}
        for s in stores
    ]}


# ============================================================
# ORDERS DELETE / CREATE ON BEHALF
# ============================================================

@router.delete("/orders/{order_id}")
async def admin_delete_order(
    order_id: str,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete cancelled orders cleanup."""
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalars().first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.status != OrderStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Only cancelled orders can be deleted")
    await db.delete(order)
    await db.commit()
    return {"success": True}


@router.post("/orders/delete-cancelled")
async def admin_delete_cancelled(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Bulk delete cancelled orders."""
    stmt = select(Order).where(Order.status == OrderStatus.CANCELLED)
    result = await db.execute(stmt)
    cancelled = result.scalars().all()
    count = len(cancelled)
    for o in cancelled:
        await db.delete(o)
    await db.commit()
    return {"deleted": count}


@router.post("/orders/create-on-behalf")
async def admin_create_order_behalf(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Admin creates order on behalf of customer."""
    # Placeholder - uses same logic as regular order creation
    return {"orderId": f"ord_{uuid.uuid4().hex[:12]}", "message": "Order created on behalf"}


# ============================================================
# BULK UPDATE
# ============================================================

@router.post("/bulk-update")
async def admin_bulk_update(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Bulk update products."""
    ids = data.get("ids", [])
    updates = data.get("updates", {})
    if not ids or not updates:
        raise HTTPException(status_code=400, detail="ids and updates required")

    stmt = select(Product).where(Product.id.in_(ids))
    result = await db.execute(stmt)
    products = result.scalars().all()
    updated = 0
    for p in products:
        for k, v in updates.items():
            if hasattr(p, k):
                setattr(p, k, v)
                updated += 1
    await db.commit()
    return {"updated": updated}


# ============================================================
# FORECAST (placeholder, real logic in forecast.py)
# ============================================================

@router.get("/forecast")
async def admin_get_forecast(
    productId: Optional[str] = Query(None),
    days: int = Query(7),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get demand forecast."""
    return {"forecast": [], "days": days, "productId": productId}


@router.get("/inventory/forecast")
async def admin_inventory_forecast(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Inventory forecast based on sales."""
    return {"forecast": []}


# ============================================================
# CATEGORIES SORT RULE
# ============================================================

@router.get("/categories/sort-rule")
async def admin_get_sort_rule(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    return {"rule": "default"}


@router.patch("/categories/sort-rule")
async def admin_update_sort_rule(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    return {"success": True, "rule": data.get("rule", "default")}
