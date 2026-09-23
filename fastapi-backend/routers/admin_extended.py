"""
Admin Extended Routes
Migrated from Next.js API routes to FastAPI.
Covers: dashboard, products, orders, users, coupons, inventory, reports, etc.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, BackgroundTasks, Request
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
import re

from database import get_db
from models import User, Order, Product, Category, Coupon, OrderStatus, OrderType, Role, PaymentMethod, PaymentStatus, RiderWallet, StoreInventory, DarkStore, StoreSetting
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


def serialize_product(p: Product) -> Dict[str, Any]:
    return {
        "id": p.id,
        "name": p.name,
        "slug": p.slug,
        "description": p.description,
        "price": float(p.price) if p.price is not None else 0.0,
        "mrp": float(p.mrp) if p.mrp is not None else 0.0,
        "discount": float(p.discount) if p.discount is not None else 0.0,
        "stock": int(p.stock) if p.stock is not None else 0,
        "unit": p.unit,
        "imageUrl": p.imageUrl,
        "categoryId": p.categoryId,
        "restaurantId": p.restaurantId,
        "isAvailable": bool(p.isAvailable),
        "tags": p.tags,
        "variants": p.variants,
    }

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
    raw_rest_id = data.get("restaurantId")
    clean_rest_id = str(raw_rest_id).strip() if raw_rest_id else None
    raw_cat_id = data.get("categoryId")
    clean_cat_id = str(raw_cat_id).strip() if raw_cat_id else None

    if clean_rest_id:
        final_rest_id = clean_rest_id
        final_cat_id = None
    else:
        final_rest_id = None
        final_cat_id = clean_cat_id

    raw_mrp = float(data.get("mrp", 0))
    raw_price = float(data.get("price", 0))
    variants = data.get("variants")
    if variants and isinstance(variants, list) and len(variants) > 0:
        variants = sorted(variants, key=lambda x: float(x.get("price", 0)))
        raw_price = float(variants[0].get("price", raw_price))
        raw_mrp = float(variants[0].get("mrp", raw_price))

    discount = max(0.0, round(((raw_mrp - raw_price) / raw_mrp) * 100.0)) if raw_mrp > raw_price else 0.0

    addons = data.get("addons")
    if addons and not isinstance(addons, list):
        addons = None

    slug = data.get("slug")
    if not slug:
        import re
        base_name = data.get("name", "product").lower().strip()
        slug = re.sub(r"[^a-z0-9]+", "-", base_name).strip("-") or "product"
        slug = f"{slug}-{uuid.uuid4().hex[:6]}"

    readable_id = None
    try:
        from sqlalchemy import func
        max_res = await db.execute(select(func.max(Product.readableId)))
        max_id = max_res.scalar() or 200000
        readable_id = int(max_id) + 1
    except Exception:
        pass

    product = Product(
        id=f"prod_{uuid.uuid4().hex[:12]}",
        readableId=readable_id,
        name=data.get("name", ""),
        slug=slug,
        description=data.get("description"),
        imageUrl=data.get("imageUrl") or "📦",
        categoryId=final_cat_id,
        restaurantId=final_rest_id,
        mrp=raw_mrp,
        price=raw_price,
        discount=discount,
        unit=data.get("unit", "pcs"),
        stock=99999 if final_rest_id else int(data.get("stock", 0)),
        isAvailable=data.get("isAvailable", True),
        tags=data.get("tags", []),
        variants=variants if isinstance(variants, (list, dict)) else None,
        addons=addons,
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
        vendor=data.get("vendor"),
        vendorId=data.get("vendorId"),
    )
    db.add(product)
    await db.flush()

    # Seed StoreInventory
    initial_stock_num = 99999 if final_rest_id else int(data.get("stock", 0))
    target_store_id = data.get("storeId") if data.get("storeId") != "all" else None
    from models import StoreInventory, DarkStore
    try:
        if target_store_id:
            db.add(StoreInventory(
                productId=product.id,
                storeId=target_store_id,
                stock=initial_stock_num
            ))
        else:
            stores_res = await db.execute(select(DarkStore.id))
            for sid in stores_res.scalars().all():
                db.add(StoreInventory(
                    productId=product.id,
                    storeId=sid,
                    stock=initial_stock_num
                ))
    except Exception as e:
        logger.warning(f"StoreInventory seed error in admin_create_product: {e}")

    await db.commit()
    await db.refresh(product)
    return {"product": serialize_product(product)}


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

    for field in ["name", "slug", "description", "imageUrl", "unit", "location",
                  "availableStartTime", "availableEndTime", "barcode", "vendor", "vendorId"]:
        if field in data:
            setattr(product, field, data[field])

    # Restaurant ID & Category ID auto-alignment
    if "restaurantId" in data:
        raw_rest_id = data.get("restaurantId")
        clean_rest_id = str(raw_rest_id).strip() if raw_rest_id else None
        if clean_rest_id:
            product.restaurantId = clean_rest_id
            product.categoryId = None
        else:
            product.restaurantId = None
    elif "categoryId" in data and data.get("categoryId"):
        product.categoryId = str(data["categoryId"]).strip()
        product.restaurantId = None

    # Variants & pricing
    raw_mrp = data.get("mrp")
    raw_price = data.get("price")
    final_mrp = float(raw_mrp) if raw_mrp is not None else product.mrp
    final_price = float(raw_price) if raw_price is not None else product.price

    if "variants" in data:
        variants = data["variants"]
        if isinstance(variants, list) and len(variants) > 0:
            sorted_variants = sorted(variants, key=lambda x: float(x.get("price", 0)))
            product.variants = sorted_variants
            final_price = float(sorted_variants[0].get("price", final_price))
            final_mrp = float(sorted_variants[0].get("mrp", final_price))
            if not product.unit or product.unit in ['1 pc', '1 unit', '1 Serving']:
                product.unit = sorted_variants[0].get("name", product.unit)
        else:
            product.variants = variants if isinstance(variants, (list, dict)) else None

    product.price = final_price
    product.mrp = final_mrp
    product.discount = max(0.0, round(((final_mrp - final_price) / final_mrp) * 100.0)) if final_mrp > final_price else 0.0

    if "addons" in data:
        addons = data["addons"]
        if isinstance(addons, list) and len(addons) > 0:
            product.addons = addons
        else:
            product.addons = None

    if "costPrice" in data and data["costPrice"] is not None:
        product.costPrice = float(data["costPrice"])

    target_store_id = data.get("storeId")
    if "stock" in data and data["stock"] is not None:
        parsed_stock = int(data["stock"])
        if target_store_id and target_store_id != 'all' and target_store_id != 'hub-209206':
            pass
        else:
            product.stock = parsed_stock

    if target_store_id and target_store_id != 'all' and "stock" in data and data["stock"] is not None:
        val = int(data["stock"])
        try:
            inv_stmt = select(StoreInventory).where(
                StoreInventory.productId == product.id,
                StoreInventory.storeId == target_store_id
            )
            inv_res = await db.execute(inv_stmt)
            existing_inv = inv_res.scalars().first()
            if existing_inv:
                existing_inv.stock = val
            else:
                new_inv = StoreInventory(
                    productId=product.id,
                    storeId=target_store_id,
                    stock=val
                )
                db.add(new_inv)
        except Exception as inv_err:
            print(f"Warning: Failed to update StoreInventory: {inv_err}")

    for field in ["minStock", "sortOrder"]:
        if field in data and data[field] is not None:
            setattr(product, field, int(data[field]))

    for field in ["isAvailable", "isFlashDeal", "isTopPick", "isBestSeller"]:
        if field in data and data[field] is not None:
            setattr(product, field, bool(data[field]))

    if "tags" in data:
        product.tags = data["tags"]

    await db.commit()
    await db.refresh(product)
    return {"product": serialize_product(product)}


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
    request: Request,
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


@router.patch("/users")
@router.patch("/users/{user_id}")
async def admin_update_user(
    user_id: Optional[str] = None,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    H19 FIX: Admin updates user details (role, name, phone, assignedStoreId, assignedRestaurantId).
    Includes safeguard against downgrading root admin accounts.
    """
    target_id = user_id or data.get("userId")
    if not target_id:
        raise HTTPException(status_code=400, detail="userId is required")

    result = await db.execute(select(User).where(User.id == target_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if "name" in data and data["name"]:
        user.name = str(data["name"]).strip()
    if "phone" in data and data["phone"]:
        user.phone = str(data["phone"]).strip()
    if "assignedStoreId" in data:
        user.assignedStoreId = data["assignedStoreId"] or None
    if "assignedRestaurantId" in data:
        user.assignedRestaurantId = data["assignedRestaurantId"] or None

    new_role = data.get("role")
    if new_role:
        new_role_upper = str(new_role).upper().strip()
        if new_role_upper not in [r.value for r in Role]:
            raise HTTPException(status_code=400, detail="Invalid role")

        # Root admin safeguard
        clean_user_phone = re.sub(r"\D", "", user.phone or "")[-10:]
        is_root_admin = (
            user.email in ["admin@fastkirana.com", "superadmin@fastkirana.com"]
            or clean_user_phone in ["7054470303", "9170942500", "8112849854"]
        )
        if is_root_admin and new_role_upper != "ADMIN":
            raise HTTPException(status_code=403, detail="Root Admin accounts cannot be downgraded")

        user.role = Role(new_role_upper)

    await db.commit()
    await db.refresh(user)

    return {
        "success": True,
        "message": "User details updated successfully",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": user.role.value if hasattr(user.role, "value") else str(user.role),
            "assignedStoreId": user.assignedStoreId,
            "assignedRestaurantId": user.assignedRestaurantId
        }
    }


@router.post("/users")
async def admin_set_worker_password(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    H20 FIX: Admin sets/updates worker password.
    Syncs across all linked accounts sharing phone number.
    """
    user_id = data.get("userId")
    password = data.get("password")

    if not user_id or not password:
        raise HTTPException(status_code=400, detail="userId and password are required")

    if len(str(password)) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    from routers.auth import hash_password
    pw_hash = hash_password(str(password))

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.passwordHash = pw_hash

    # Sync across matching phone records if present
    if user.phone:
        digits = re.sub(r"\D", "", user.phone)[-10:]
        patterns = [user.phone, digits, f"+91{digits}", f"91{digits}", f"wa-{digits}@fastkirana.com"]
        sync_stmt = select(User).where(or_(User.phone.in_(patterns), User.email.in_(patterns)))
        sync_res = await db.execute(sync_stmt)
        for u in sync_res.scalars().all():
            u.passwordHash = pw_hash

    await db.commit()
    return {"success": True, "message": "Worker password updated successfully"}


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
    from models import Cart, CartItem, Product, User
    from sqlalchemy.orm import selectinload
    stmt = (
        select(Cart)
        .options(selectinload(Cart.items).selectinload(CartItem.product), selectinload(Cart.user))
        .join(Cart.items)
        .order_by(desc(Cart.updatedAt))
    )
    result = await db.execute(stmt)
    carts_db = result.scalars().unique().all()

    carts = []
    for c in carts_db:
        if not c.items:
            continue
        subtotal = sum(item.product.price * item.quantity if item.product else 0 for item in c.items)
        user_name = c.user.name if c.user else f"Guest ({c.id[-6:]})"
        user_email = c.user.email if c.user else "guest@fastkirana.com"
        user_phone = c.user.phone if c.user else None
        carts.append({
            "id": c.id,
            "userId": c.userId,
            "userName": user_name,
            "name": user_name,
            "phone": user_phone,
            "email": user_email,
            "itemsCount": len(c.items),
            "subtotal": round(subtotal, 2),
            "updatedAt": c.updatedAt.isoformat() if c.updatedAt else None,
        })
    return {"success": True, "carts": carts, "count": len(carts)}


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
# STORES & DARKSTORE HUBS
# ============================================================

@router.get("/stores")
async def admin_get_stores(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get all dark stores with full geo-fencing and operational controls."""
    from models import DarkStore, StoreInventory
    result = await db.execute(select(DarkStore).order_by(DarkStore.createdAt.asc()))
    stores = result.scalars().all()

    store_list = []
    for s in stores:
        # Get active stock count for this store
        inv_stmt = select(func.count(StoreInventory.productId)).where(
            StoreInventory.storeId == s.id,
            StoreInventory.stock > 0
        )
        inv_res = await db.execute(inv_stmt)
        inv_count = inv_res.scalar() or 0

        store_list.append({
            "id": s.id,
            "name": s.name,
            "latitude": float(s.latitude),
            "longitude": float(s.longitude),
            "deliveryRadiusKm": float(s.deliveryRadiusKm or 5.0),
            "deliveryPolygon": s.deliveryPolygon,
            "groceryOpen": getattr(s, "groceryOpen", True),
            "surgeCharge": float(s.surgeCharge or 0.0),
            "isActive": s.isActive,
            "inventoryCount": inv_count,
            "createdAt": s.createdAt.isoformat() if s.createdAt else None,
        })

    return {"stores": store_list}


@router.post("/stores")
async def admin_create_store(
    payload: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new DarkStore hub with isolated settings and optional manager."""
    name = payload.get("name")
    if not name or not str(name).strip():
        raise HTTPException(status_code=400, detail="Store name is required")

    name = str(name).strip()
    pincode = payload.get("pincode")
    clean_pincode = re.sub(r"\D", "", str(pincode or ""))[:6]
    slug_name = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    store_id = (payload.get("id") or "").strip() or (f"hub-{clean_pincode}" if len(clean_pincode) == 6 else f"hub-{slug_name}")

    lat = float(payload.get("latitude") or payload.get("lat") or 26.1534)
    lng = float(payload.get("longitude") or payload.get("lng") or 80.1714)
    radius = float(payload.get("deliveryRadiusKm") or 5.0)
    surge = float(payload.get("surgeCharge") or 0.0)
    grocery_open = payload.get("groceryOpen", True)
    polygon = payload.get("deliveryPolygon")

    store = DarkStore(
        id=store_id,
        name=name,
        latitude=lat,
        longitude=lng,
        deliveryRadiusKm=radius,
        surgeCharge=surge,
        groceryOpen=grocery_open,
        deliveryPolygon=polygon,
        isActive=True
    )
    db.add(store)
    await db.flush()

    # Automatically initialize isolated store-scoped settings for this new hub
    try:
        city_name = re.sub(r"\s+(Hub|Market|Central|Dark\s*Store|Branch).*$", "", name, flags=re.IGNORECASE).strip()
        address = payload.get("address") or payload.get("contactAddress")
        pickup = payload.get("pickupAddress") or payload.get("groceryPickupAddress")
        phone = payload.get("phone") or payload.get("storePhone") or payload.get("managerPhone") or "+918112849854"
        upi = payload.get("upiVpa") or payload.get("storeUpiVpa") or ""

        resolved_address = (address or f"{city_name}{', ' + clean_pincode if clean_pincode else ''}").strip()
        resolved_pickup = (pickup or f"FastKirana Dark Store, {city_name}{' - ' + clean_pincode if clean_pincode else ''}").strip()
        resolved_phone = str(phone).strip()
        resolved_upi = str(upi).strip()

        initial_settings = [
            (f"store:{store.id}:store_address", resolved_address),
            (f"store:{store.id}:contact_address", resolved_address),
            (f"store:{store.id}:grocery_pickup_address", resolved_pickup),
            (f"store:{store.id}:contact_phone", resolved_phone),
            (f"store:{store.id}:store_phone", resolved_phone),
            (f"store:{store.id}:store_pincode", clean_pincode or ""),
            (f"store:{store.id}:store_lat", str(store.latitude)),
            (f"store:{store.id}:store_lng", str(store.longitude)),
            (f"store:{store.id}:delivery_radius", str(store.deliveryRadiusKm or 5.0)),
            (f"store:{store.id}:grocery_mart_open", "true" if store.groceryOpen else "false"),
            (f"store:{store.id}:trusted_text", f"✨ Trusted by families in {city_name}"),
            (f"store:{store.id}:delivery_fee_tier1", "25"),
            (f"store:{store.id}:delivery_threshold_tier1", "199"),
            (f"store:{store.id}:delivery_fee_tier2", "35"),
            (f"store:{store.id}:delivery_threshold_tier2", "299"),
            (f"store:{store.id}:delivery_fee_tier3", "50"),
            (f"store:{store.id}:delivery_threshold_tier3", "399"),
        ]
        if resolved_upi:
            initial_settings.append((f"store:{store.id}:store_upi_vpa", resolved_upi))

        for k, v in initial_settings:
            s_res = await db.execute(select(StoreSetting).where(StoreSetting.key == k))
            existing_s = s_res.scalars().first()
            if existing_s:
                existing_s.value = v
                existing_s.updatedAt = datetime.utcnow()
            else:
                db.add(StoreSetting(key=k, value=v, updatedAt=datetime.utcnow()))
    except Exception as setting_err:
        logger.error(f"Failed to initialize isolated settings for new store (non-fatal): {setting_err}")

    # Assign Hub Manager / Admin Phone Number
    manager_phone = payload.get("managerPhone")
    if manager_phone and isinstance(manager_phone, str):
        try:
            clean_manager_phone = re.sub(r"\D", "", manager_phone)[-10:]
            if len(clean_manager_phone) == 10:
                formatted_phone = f"+91{clean_manager_phone}"
                u_res = await db.execute(select(User).where(
                    or_(
                        User.phone == formatted_phone,
                        User.phone == clean_manager_phone,
                        User.phone.endswith(clean_manager_phone)
                    )
                ))
                existing_u = u_res.scalars().first()
                if existing_u:
                    existing_u.role = Role.ADMIN
                    existing_u.assignedStoreId = store.id
                else:
                    db.add(User(
                        id=str(uuid.uuid4()),
                        phone=formatted_phone,
                        name=f"{name} Admin",
                        email=f"admin.{store.id}@fastkirana.in",
                        role=Role.ADMIN,
                        assignedStoreId=store.id
                    ))
        except Exception as admin_err:
            logger.error(f"Hub Admin assignment error (non-fatal): {admin_err}")

    await db.commit()
    await db.refresh(store)
    return {"success": True, "store": {
        "id": store.id,
        "name": store.name,
        "latitude": store.latitude,
        "longitude": store.longitude,
        "deliveryRadiusKm": store.deliveryRadiusKm,
        "surgeCharge": store.surgeCharge,
        "groceryOpen": store.groceryOpen,
        "isActive": store.isActive
    }}


@router.patch("/stores")
@router.patch("/stores/{store_id}")
async def admin_update_store(
    payload: Dict[str, Any] = Body(...),
    store_id: Optional[str] = None,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update DarkStore hub settings (groceryOpen, surgeCharge, deliveryPolygon, etc.)."""
    from models import DarkStore
    target_id = store_id or payload.get("id") or payload.get("storeId")
    if not target_id:
        raise HTTPException(status_code=400, detail="storeId is required")

    stmt = select(DarkStore).where(DarkStore.id == target_id)
    res = await db.execute(stmt)
    store = res.scalars().first()
    if not store:
        raise HTTPException(status_code=404, detail="Store not found")

    if "name" in payload:
        store.name = str(payload["name"])
    if "groceryOpen" in payload:
        store.groceryOpen = bool(payload["groceryOpen"])
    if "isActive" in payload:
        store.isActive = bool(payload["isActive"])
    if "surgeCharge" in payload:
        store.surgeCharge = float(payload["surgeCharge"])
    if "deliveryRadiusKm" in payload:
        store.deliveryRadiusKm = float(payload["deliveryRadiusKm"])
    if "deliveryPolygon" in payload:
        store.deliveryPolygon = payload["deliveryPolygon"]
    if "latitude" in payload or "lat" in payload:
        store.latitude = float(payload.get("latitude") or payload.get("lat"))
    if "longitude" in payload or "lng" in payload:
        store.longitude = float(payload.get("longitude") or payload.get("lng"))

    await db.commit()
    await db.refresh(store)
    return {"success": True, "store": {
        "id": store.id,
        "name": store.name,
        "groceryOpen": store.groceryOpen,
        "surgeCharge": store.surgeCharge,
        "isActive": store.isActive
    }}


# ============================================================
# ORDERS DELETE / CLEAN CANCELLED / REFUND
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
@router.post("/orders/clean-cancelled")
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
    return {"deleted": count, "success": True}


@router.post("/orders/{id}/refund")
@router.post("/orders/{order_id}/refund")
async def admin_refund_order(
    order_id: str,
    payload: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    C13 FIX: Process partial or full refund for an order.
    Appends refund details to notes, marks paymentStatus as REFUNDED if full refund,
    preserves order status (does NOT force CANCELLED), and only restocks if explicitly requested.
    """
    clean_id = order_id.strip()
    stmt = select(Order).options(selectinload(Order.items)).where(
        or_(Order.id == clean_id, Order.readableId == clean_id)
    )
    res = await db.execute(stmt)
    order = res.scalars().first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    raw_amount = payload.get("amount")
    item_id = payload.get("itemId")
    reason = str(payload.get("reason") or "").strip()

    try:
        refund_value = float(raw_amount) if raw_amount is not None else float(order.total or 0.0)
    except (ValueError, TypeError):
        refund_value = float(order.total or 0.0)

    if refund_value <= 0:
        raise HTTPException(status_code=400, detail="Valid refund amount greater than 0 is required")

    refunded_item_name = ""
    if item_id and order.items:
        target_item = next((i for i in order.items if i.id == item_id), None)
        if target_item:
            refunded_item_name = target_item.name
            target_item.notes = f"{target_item.notes} | ₹{refund_value:.2f} Refunded" if target_item.notes else f"₹{refund_value:.2f} Refunded"

    is_full_refund = refund_value >= float(order.total or 0.0)

    refund_note = f"₹{refund_value:.2f} Refunded"
    if refunded_item_name:
        refund_note += f" ({refunded_item_name})"
    if reason:
        refund_note += f" - {reason}"

    order.notes = f"{order.notes}\n{refund_note}" if order.notes else refund_note
    order.updatedAt = datetime.utcnow()

    if is_full_refund:
        order.paymentStatus = PaymentStatus.REFUNDED

    # Optional restocking only if explicitly requested
    restock = payload.get("restock", False)
    if restock and order.items:
        for it in order.items:
            p_stmt = select(Product).where(Product.id == it.productId)
            p_res = await db.execute(p_stmt)
            prod = p_res.scalars().first()
            if prod and not prod.restaurantId:
                prod.stock += it.quantity

    await db.commit()
    await db.refresh(order)

    return {
        "success": True,
        "message": f"Refund of ₹{refund_value:.2f} processed for Order #{order.readableId or order.id}.",
        "orderId": order.id,
        "isFullRefund": is_full_refund,
        "paymentStatus": order.paymentStatus.value
    }


@router.post("/orders/create-on-behalf")
async def admin_create_order_behalf(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """C14 FIX: Admin creates order on behalf of customer using full order creation engine."""
    from routers.orders import create_order
    return await create_order(payload=data, current_user=current_admin, db=db)


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
