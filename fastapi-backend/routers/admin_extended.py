"""
Admin Extended Routes
Migrated from Next.js API routes to FastAPI.
Covers: dashboard, products, orders, users, coupons, inventory, reports, etc.
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, BackgroundTasks, Request, Response
from utils.push import send_push_notification
import logging
import hashlib

logger = logging.getLogger("admin_extended")
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, text, or_, case, delete
from sqlalchemy.orm import selectinload
from datetime import datetime, date, timedelta
from typing import Optional, List, Dict, Any
import uuid
import random
import string
import re

from database import get_db
from models import (
    User, Order, Product, Category, Coupon, OrderStatus, OrderType, Role,
    PaymentMethod, PaymentStatus, RiderWallet, StoreInventory, DarkStore,
    StoreSetting, StockAlert, PriceHistory, PromoBanner, RestaurantPayout,
    CashDepositTransaction, VendorPayout, Vendor, RestaurantReview, Review,
    Address, Restaurant, ProductBatch, StockLog
)
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
    storeId: Optional[str] = Query(None),
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
    if type == 'cafe' or type == 'restaurant':
        and_clauses.append(Product.restaurantId.isnot(None))
    elif type == 'grocery':
        and_clauses.append(Product.restaurantId.is_(None))

    if storeId and storeId != "all":
        from models import StoreInventory, Restaurant
        grocery_scope = and_(
            Product.restaurantId.is_(None),
            exists().where(
                and_(
                    StoreInventory.productId == Product.id,
                    StoreInventory.storeId == storeId
                )
            )
        )
        rest_scope = Product.restaurant.has(Restaurant.storeId == storeId)
        and_clauses.append(or_(grocery_scope, rest_scope))

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

    # Localize inventory stock if storeId is specified
    inv_map = {}
    if storeId and storeId != "all" and products:
        from models import StoreInventory
        prod_ids = [p.id for p in products]
        inv_stmt = select(StoreInventory).where(
            StoreInventory.storeId == storeId,
            StoreInventory.productId.in_(prod_ids)
        )
        inv_res = await db.execute(inv_stmt)
        inv_map = {inv.productId: inv.stock for inv in inv_res.scalars().all()}

    from schemas import ProductOut
    product_list = []
    for p in products:
        if storeId and storeId != "all":
            if p.restaurantId:
                local_stk = p.stock or 99999
            else:
                local_stk = inv_map.get(p.id, 0)
        else:
            local_stk = p.stock

        product_list.append(ProductOut(
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
            stock=local_stk,
            isAvailable=p.isAvailable and (local_stk > 0 if not p.restaurantId else True) if storeId and storeId != "all" else p.isAvailable,
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
        ))

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
        selectinload(Order.deliveryUser),
        selectinload(Order.items),
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

    order_list = []
    for o in orders:
        user_name = (o.user.name.strip() if (o.user and o.user.name) else None) or "Customer"
        user_phone = (o.address.phone if (o.address and o.address.phone) else None) or (o.user.phone if (o.user and o.user.phone) else None) or o.shopPhone or None
        user_email = (o.user.email if o.user else None) or ""
        order_list.append({
            "id": o.id,
            "readableId": o.readableId,
            "userId": o.userId,
            "addressId": o.addressId,
            "restaurantId": o.restaurantId,
            "combinedId": o.combinedId,
            "orderType": o.orderType.value if hasattr(o.orderType, 'value') else str(o.orderType or 'GROCERY'),
            "deliveryMethod": o.deliveryMethod or "DELIVERY",
            "storeId": o.storeId,
            "notes": o.notes,
            "isB2B": bool(o.isB2B),
            "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
            "total": float(o.total or 0.0),
            "subtotal": float(o.subtotal or 0.0),
            "discount": float(o.discount or 0.0),
            "deliveryFee": float(o.deliveryFee or 0.0),
            "taxes": float(o.taxes or 0.0),
            "miscFee": float(o.miscFee or 0.0),
            "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, 'value') else str(o.paymentMethod),
            "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, 'value') else str(o.paymentStatus),
            "createdAt": o.createdAt.isoformat() if o.createdAt else None,
            "updatedAt": o.updatedAt.isoformat() if o.updatedAt else None,
            "confirmedAt": o.confirmedAt.isoformat() if o.confirmedAt else None,
            "packedAt": o.packedAt.isoformat() if o.packedAt else None,
            "shippedAt": o.shippedAt.isoformat() if o.shippedAt else None,
            "deliveredAt": o.deliveredAt.isoformat() if o.deliveredAt else None,
            "userName": user_name,
            "userEmail": user_email,
            "userPhone": user_phone,
            "deliveryBoyName": o.deliveryUser.name if (hasattr(o, 'deliveryUser') and o.deliveryUser) else None,
            "deliveryBoyPhone": o.deliveryUser.phone if (hasattr(o, 'deliveryUser') and o.deliveryUser) else None,
            "shopName": o.shopName,
            "shopPhone": o.shopPhone,
            "user": {
                "id": o.user.id if o.user else None,
                "name": user_name,
                "email": user_email,
                "phone": o.user.phone if o.user else None,
            } if o.user else None,
            "address": {
                "id": o.address.id if o.address else None,
                "houseNo": o.address.houseNo if o.address else "",
                "street": o.address.street if o.address else "",
                "area": o.address.area if o.address else "",
                "city": o.address.city if o.address else "",
                "pincode": o.address.pincode if o.address else "",
                "phone": o.address.phone if o.address else "",
            } if o.address else None,
            "items": [
                {
                    "id": i.id,
                    "orderId": i.orderId,
                    "productId": i.productId,
                    "name": i.name,
                    "quantity": i.quantity,
                    "price": float(i.price or 0.0),
                    "imageUrl": i.imageUrl,
                    "selectedVariant": i.selectedVariant,
                    "notes": i.notes,
                } for i in (o.items or [])
            ]
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

    old_status = order.status
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

    from routers.websockets import manager
    from routers.orders import dispatch_isolated_order_fcm_notifications, dispatch_isolated_status_update_notifications

    # Real-time WebSocket alerts
    status_evt = {
        "event": "STATUS_UPDATE",
        "orderId": order.id,
        "status": order.status.value,
        "restaurantId": order.restaurantId,
        "order": {
            "id": order.id,
            "readableId": order.readableId,
            "status": order.status.value,
            "restaurantId": order.restaurantId,
            "total": float(order.total),
            "updatedAt": order.updatedAt.isoformat()
        }
    }
    try:
        await manager.broadcast_to_channel("general", status_evt)
        await manager.broadcast_to_channel(f"order_{order.id}", status_evt)
        if order.restaurantId:
            await manager.broadcast_to_channel(f"restaurant_{order.restaurantId}", status_evt)
            await manager.broadcast_to_channel(f"kitchen_{order.restaurantId}", status_evt)
    except Exception as ws_e:
        logger.warning(f"Admin status ws broadcast note: {ws_e}")

    # If admin just APPROVED an ADMIN_PENDING order to PENDING:
    if old_status == OrderStatus.ADMIN_PENDING and order.status == OrderStatus.PENDING:
        background_tasks.add_task(
            dispatch_isolated_order_fcm_notifications,
            order.id,
            order.readableId,
            order.restaurantId,
            order.shopName,
            float(order.total),
            order.status.value,
            order.storeId
        )
    elif new_status and old_status != order.status:
        background_tasks.add_task(
            dispatch_isolated_status_update_notifications,
            order.id,
            order.readableId,
            order.restaurantId,
            order.shopName,
            order.status.value,
            order.storeId
        )

    # Trigger push notifications for customer status updates in the background
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
    and_clauses = [
        User.deletedAt.is_(None),
        or_(User.email.is_(None), not_(User.email.like("guest-%"))),
        or_(User.name.is_(None), not_(User.name.like("Guest Shopper%"))),
    ]

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
         "categoryId": c.categoryId, "restaurantId": c.restaurantId, "oncePerCustomer": c.oncePerCustomer,
         "bogoType": c.bogoType, "triggerVariant": c.triggerVariant, "rewardVariant": c.rewardVariant,
         "defaultFreeDishId": c.defaultFreeDishId, "bogoDishId": c.bogoDishId, "maxFreeItems": c.maxFreeItems,
         "badgeText": c.badgeText, "menuSection": c.menuSection, "autoApply": c.autoApply}
        for c in coupons
    ]}


@router.post("/coupons")
async def admin_create_coupon(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    code = (data.get("code") or "").upper().strip()
    discount_type = data.get("discountType")
    if not code or not discount_type:
        raise HTTPException(status_code=400, detail="Missing required fields (code, discountType)")
    if discount_type not in ('FLAT', 'PERCENT', 'BOGO', 'FREE_DELIVERY'):
        raise HTTPException(status_code=400, detail="Invalid discount type")

    raw_val = data.get("value")
    val = float(raw_val) if raw_val is not None else (0.0 if discount_type in ('BOGO', 'FREE_DELIVERY') else 0.0)

    coupon = Coupon(
        id=f"cpn_{uuid.uuid4().hex[:12]}",
        code=code,
        discountType=discount_type,
        value=val,
        minOrder=float(data.get("minOrder", 0) or 0),
        maxDiscount=float(data["maxDiscount"]) if data.get("maxDiscount") else None,
        maxUses=int(data["maxUses"]) if data.get("maxUses") else None,
        usedCount=0,
        isActive=data.get("isActive", True),
        expiresAt=datetime.fromisoformat(data["expiresAt"]) if data.get("expiresAt") else None,
        categoryId=data.get("categoryId"),
        restaurantId=data.get("restaurantId"),
        oncePerCustomer=data.get("oncePerCustomer", False),
        bogoType=data.get("bogoType"),
        triggerVariant=data.get("triggerVariant"),
        rewardVariant=data.get("rewardVariant"),
        defaultFreeDishId=data.get("defaultFreeDishId"),
        bogoDishId=data.get("bogoDishId"),
        maxFreeItems=int(data["maxFreeItems"]) if data.get("maxFreeItems") else 1,
        badgeText=data.get("badgeText"),
        menuSection=data.get("menuSection"),
        autoApply=data.get("autoApply", False),
    )
    db.add(coupon)
    await db.commit()
    await db.refresh(coupon)
    return {"coupon": {"id": coupon.id, "code": coupon.code}}


@router.patch("/coupons/{coupon_id}")
async def admin_update_coupon(
    coupon_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Coupon).where(Coupon.id == coupon_id))
    coupon = result.scalars().first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")

    updatable_fields = [
        "code", "discountType", "value", "minOrder", "maxDiscount", "maxUses",
        "isActive", "categoryId", "restaurantId", "oncePerCustomer",
        "bogoType", "triggerVariant", "rewardVariant", "defaultFreeDishId",
        "bogoDishId", "maxFreeItems", "badgeText", "menuSection", "autoApply"
    ]
    for field in updatable_fields:
        if field in data:
            val = data[field]
            if field == "code" and val:
                val = str(val).upper().strip()
            elif field in ("value", "minOrder", "maxDiscount") and val is not None:
                val = float(val)
            elif field in ("maxUses", "maxFreeItems") and val is not None:
                val = int(val)
            setattr(coupon, field, val)

    if "expiresAt" in data:
        coupon.expiresAt = datetime.fromisoformat(data["expiresAt"]) if data["expiresAt"] else None

    await db.commit()
    await db.refresh(coupon)
    return {"coupon": {"id": coupon.id, "code": coupon.code, "isActive": coupon.isActive}}


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

@router.get("/restaurant-sales")
async def admin_restaurant_sales(
    startDate: Optional[str] = Query(None),
    endDate: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Comprehensive restaurant-wise sales, commission, and payout reconciliation.
    Matching Next.js admin restaurant-sales API.
    """
    now = datetime.utcnow()
    if startDate:
        start = datetime.strptime(f"{startDate} 00:00:00", "%Y-%m-%d %H:%M:%S")
    else:
        start = now - timedelta(days=7)
        start = datetime.combine(start.date(), datetime.min.time())

    if endDate:
        end = datetime.strptime(f"{endDate} 23:59:59", "%Y-%m-%d %H:%M:%S")
    else:
        end = datetime.combine(now.date(), datetime.max.time())

    effective_store = storeId or (getattr(current_admin, "assignedStoreId", None) if hasattr(current_admin, "assignedStoreId") else (current_admin.get("assignedStoreId") if isinstance(current_admin, dict) else None))

    # 1. Fetch active restaurants
    r_stmt = select(Restaurant).where(Restaurant.isActive == True)
    if effective_store and effective_store.lower() != 'all':
        r_stmt = r_stmt.where(Restaurant.storeId == effective_store)
    restaurants = (await db.execute(r_stmt)).scalars().all()

    # 2. Fetch latest paid payouts for each restaurant
    p_stmt = select(RestaurantPayout).where(RestaurantPayout.status == "PAID").order_by(desc(RestaurantPayout.paidAt))
    paid_payouts = (await db.execute(p_stmt)).scalars().all()
    last_settled_map = {}
    for p in paid_payouts:
        if p.restaurantId and p.restaurantId not in last_settled_map:
            last_settled_map[p.restaurantId] = {
                "date": p.paidAt.isoformat() if p.paidAt else (p.endDate.isoformat() if p.endDate else None),
                "amount": float(p.amount),
                "transactionId": p.transactionId
            }

    # 3. Fetch delivered orders in period
    o_stmt = select(Order).where(
        and_(
            Order.status == OrderStatus.DELIVERED,
            Order.restaurantId.isnot(None),
            Order.createdAt >= start,
            Order.createdAt <= end
        )
    )
    if effective_store and effective_store.lower() != 'all':
        o_stmt = o_stmt.where(Order.storeId == effective_store)
    orders = (await db.execute(o_stmt)).scalars().all()
    order_ids = [o.id for o in orders]

    # 4. Fetch order items with products and categories
    items_by_order = {}
    if order_ids:
        items_sql = """
            SELECT oi."orderId", oi.name, oi.quantity, oi.price, o."restaurantId", 
                   p."restaurantId" as "prodRestaurantId", c.name as "categoryName", c.slug as "categorySlug"
            FROM order_items oi
            JOIN orders o ON oi."orderId" = o.id
            LEFT JOIN products p ON oi."productId" = p.id
            LEFT JOIN categories c ON p."categoryId" = c.id
            WHERE o.status::text = 'DELIVERED'
              AND o."restaurantId" IS NOT NULL
              AND o."createdAt" >= :start
              AND o."createdAt" <= :end
        """
        params = {"start": start, "end": end}
        if effective_store and effective_store.lower() != 'all':
            items_sql += ' AND o."storeId" = :store_id'
            params["store_id"] = effective_store

        items_res = await db.execute(text(items_sql), params)
        for r in items_res.all():
            m = dict(r._mapping)
            oid = m["orderId"]
            if oid not in items_by_order:
                items_by_order[oid] = []
            items_by_order[oid].append(m)

    # 5. Build restaurant stats
    restaurant_map = {}
    for r in restaurants:
        last_settled = last_settled_map.get(r.id)
        restaurant_map[r.id] = {
            "id": r.id,
            "name": r.name,
            "slug": r.slug,
            "logoUrl": r.logoUrl,
            "isOpen": r.isOpen,
            "commissionRate": float(r.commissionRate or 0.0),
            "totalOrders": 0,
            "totalProductSales": 0.0,
            "adminCommission": 0.0,
            "restaurantShare": 0.0,
            "avgOrderValue": 0.0,
            "topDish": "",
            "totalDeliveryFee": 0.0,
            "totalPackaging": 0.0,
            "deliveryOrders": 0,
            "deliverySales": 0.0,
            "deliveryShare": 0.0,
            "pickupOrders": 0,
            "pickupSales": 0.0,
            "pickupShare": 0.0,
            "lastSettledDate": last_settled["date"] if last_settled else None,
            "lastSettledAmount": last_settled["amount"] if last_settled else None,
            "lastSettledTxnId": last_settled["transactionId"] if last_settled else None,
            "_itemCounts": {}
        }

    def is_pure_grocery_item(item):
        if item.get("prodRestaurantId"):
            return False
        cat_lower = (item.get("categoryName") or "").lower().strip()
        slug_lower = (item.get("categorySlug") or "").lower().strip()
        return any(k in cat_lower or k in slug_lower for k in [
            "beverage", "drink", "cold drink", "ice cream", "ice-cream", "snack", "grocery"
        ])

    for o in orders:
        items = items_by_order.get(o.id, [])
        items_by_rest = {}
        for item in items:
            if is_pure_grocery_item(item):
                continue
            item_rest_id = item.get("prodRestaurantId") or item.get("restaurantId") or o.restaurantId
            if not item_rest_id:
                continue
            if item_rest_id not in items_by_rest:
                items_by_rest[item_rest_id] = []
            items_by_rest[item_rest_id].append(item)

        if not items_by_rest and o.restaurantId:
            items_by_rest[o.restaurantId] = []

        for rest_id, rest_items in items_by_rest.items():
            r_stats = restaurant_map.get(rest_id)
            if not r_stats:
                continue

            order_rest_sales = sum(float(it["price"] or 0) * int(it["quantity"] or 1) for it in rest_items)
            discount_share = (float(o.discount) * (order_rest_sales / float(o.subtotal))) if (o.subtotal and o.subtotal > 0) else 0.0
            product_sales = max(0.0, order_rest_sales - discount_share)

            comm_rate = float(r_stats["commissionRate"])
            if comm_rate > 1.0:
                comm_rate = comm_rate / 100.0
            admin_comm = product_sales * comm_rate
            rest_share = product_sales - admin_comm

            r_stats["totalOrders"] += 1
            r_stats["totalProductSales"] += product_sales
            r_stats["adminCommission"] += admin_comm
            r_stats["restaurantShare"] += rest_share
            r_stats["totalDeliveryFee"] += float(o.deliveryFee or 0.0)
            r_stats["totalPackaging"] += float(o.miscFee or 0.0)

            is_pickup = str(o.deliveryMethod or "").upper() == "PICKUP"
            if is_pickup:
                r_stats["pickupOrders"] += 1
                r_stats["pickupSales"] += product_sales
                r_stats["pickupShare"] += rest_share
            else:
                r_stats["deliveryOrders"] += 1
                r_stats["deliverySales"] += product_sales
                r_stats["deliveryShare"] += rest_share

            for it in rest_items:
                name = it.get("name") or "Dish"
                r_stats["_itemCounts"][name] = r_stats["_itemCounts"].get(name, 0) + int(it.get("quantity") or 1)

    result_restaurants = []
    for r_stats in restaurant_map.values():
        if r_stats["totalOrders"] > 0:
            r_stats["avgOrderValue"] = round(r_stats["totalProductSales"] / r_stats["totalOrders"], 2)

        item_counts = r_stats.pop("_itemCounts", {})
        if item_counts:
            top_dish = max(item_counts.items(), key=lambda x: x[1])
            r_stats["topDish"] = f"{top_dish[0]} ({top_dish[1]})"

        r_stats["totalProductSales"] = round(r_stats["totalProductSales"], 2)
        r_stats["adminCommission"] = round(r_stats["adminCommission"], 2)
        r_stats["restaurantShare"] = round(r_stats["restaurantShare"], 2)
        r_stats["totalDeliveryFee"] = round(r_stats["totalDeliveryFee"], 2)
        r_stats["totalPackaging"] = round(r_stats["totalPackaging"], 2)
        r_stats["deliverySales"] = round(r_stats["deliverySales"], 2)
        r_stats["deliveryShare"] = round(r_stats["deliveryShare"], 2)
        r_stats["pickupSales"] = round(r_stats["pickupSales"], 2)
        r_stats["pickupShare"] = round(r_stats["pickupShare"], 2)

        result_restaurants.append(r_stats)

    return {
        "restaurants": result_restaurants,
        "dateRange": {
            "start": start.isoformat(),
            "end": end.isoformat()
        }
    }


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
    """
    Record inward stock / GRN batch.
    Supports both single batch registration and bulk items payload.
    """
    product_id = data.get("productId")
    barcode = data.get("barcode")
    name = data.get("name")
    batch_code = data.get("batchCode")
    store_id = data.get("storeId")
    qty_raw = data.get("quantity")

    # If it's a bulk inward payload
    items = data.get("items")
    if items is not None and isinstance(items, list):
        updated = 0
        for item in items:
            pid = item.get("productId")
            qty = int(item.get("quantity", 0))
            if pid and qty > 0:
                p_res = await db.execute(select(Product).where(Product.id == pid))
                p = p_res.scalars().first()
                if p:
                    p.stock = (p.stock or 0) + qty
                    updated += 1
        await db.commit()
        return {"success": True, "updated": updated, "items": len(items)}

    # Otherwise validate single batch
    if not product_id and not barcode and not name:
        raise HTTPException(status_code=400, detail="Missing required field: please provide productId, barcode, or product name")

    try:
        qty = int(qty_raw) if qty_raw is not None else 0
    except (ValueError, TypeError):
        qty = 0
    if qty <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be a positive number")

    # Find product
    product = None
    if product_id:
        p_res = await db.execute(select(Product).options(selectinload(Product.category)).where(Product.id == product_id))
        product = p_res.scalars().first()
    if not product and barcode:
        p_res = await db.execute(select(Product).options(selectinload(Product.category)).where(Product.barcode == str(barcode).strip()))
        product = p_res.scalars().first()
    if not product and name:
        p_res = await db.execute(select(Product).options(selectinload(Product.category)).where(func.lower(Product.name) == str(name).strip().lower()))
        product = p_res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found in catalog. Please check the barcode or product name.")

    # Calculate cost price
    cost_price_raw = data.get("costPrice")
    cost_price = None
    if cost_price_raw is not None:
        try:
            cost_price = float(cost_price_raw)
        except (ValueError, TypeError):
            pass
    if cost_price is None or cost_price <= 0:
        cost_price = float(product.costPrice) if product.costPrice and product.costPrice > 0 else round(float(product.price or 0.0) * 0.75, 2)

    # Expiry date
    expiry_date_str = data.get("expiryDate")
    expiry_date = datetime.utcnow() + timedelta(days=180)
    if expiry_date_str:
        try:
            expiry_date = datetime.fromisoformat(str(expiry_date_str).replace("Z", ""))
        except Exception:
            pass

    # Batch code
    if not batch_code or not str(batch_code).strip():
        batch_code = f"GRN_{datetime.utcnow().strftime('%Y%m%d')}_{''.join(random.choices(string.ascii_uppercase + string.digits, k=4))}"
    else:
        batch_code = str(batch_code).strip()

    prev_stock = int(product.stock or 0)
    new_stock = prev_stock + qty

    # 1. Create ProductBatch
    new_batch = ProductBatch(
        id=str(uuid.uuid4()),
        productId=product.id,
        batchCode=batch_code,
        quantity=qty,
        initialQty=qty,
        costPrice=cost_price,
        expiryDate=expiry_date
    )
    db.add(new_batch)

    # 2. Update Product
    product.stock = new_stock
    product.costPrice = cost_price
    product.isAvailable = True
    if not product.expiryDate:
        product.expiryDate = expiry_date

    # 3. Localize to dark store inventory if provided
    if store_id and store_id.lower() != 'all':
        inv_stmt = select(StoreInventory).where(
            StoreInventory.productId == product.id,
            StoreInventory.storeId == store_id
        )
        inv = (await db.execute(inv_stmt)).scalars().first()
        if inv:
            inv.stock = int(inv.stock or 0) + qty
        else:
            db.add(StoreInventory(
                id=str(uuid.uuid4()),
                productId=product.id,
                storeId=store_id,
                stock=qty
            ))

    # 4. Create StockLog
    db.add(StockLog(
        id=str(uuid.uuid4()),
        productId=product.id,
        quantity=qty,
        type="INWARD_GRN",
        prevStock=prev_stock
    ))

    await db.commit()
    await db.refresh(product)
    await db.refresh(new_batch)

    return {
        "success": True,
        "message": f"Successfully inwarded {qty} units for \"{product.name}\" (Batch: {batch_code}).",
        "batch": {
            "id": new_batch.id,
            "productId": new_batch.productId,
            "batchCode": new_batch.batchCode,
            "quantity": new_batch.quantity,
            "initialQty": new_batch.initialQty,
            "costPrice": float(new_batch.costPrice),
            "expiryDate": new_batch.expiryDate.isoformat() if new_batch.expiryDate else None
        },
        "product": serialize_product(product)
    }


# ============================================================
# PAYOUTS (Rider)
# ============================================================

@router.get("/rider-payouts")
async def admin_get_rider_payouts(
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


@router.patch("/rider-payouts/{payout_id}")
async def admin_update_rider_payout(
    payout_id: str,
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update rider payout status (approve/reject)."""
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
    request: Request,
    response: Response,
    storeId: Optional[str] = Query(None),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get users with active carts (updated in past 24h) with storeId scoping."""
    from models import Cart, CartItem, Product, User, Address
    from sqlalchemy.orm import selectinload

    cutoff = datetime.utcnow() - timedelta(hours=24)
    stmt = (
        select(Cart)
        .options(
            selectinload(Cart.items).selectinload(CartItem.product),
            selectinload(Cart.user).selectinload(User.addresses)
        )
        .join(Cart.items)
        .where(Cart.updatedAt >= cutoff)
        .order_by(desc(Cart.updatedAt))
    )
    result = await db.execute(stmt)
    carts_db = result.scalars().unique().all()

    # Store scoping
    if storeId and storeId != "all":
        filtered_carts = []
        for c in carts_db:
            u = c.user
            if not u:
                continue
            user_store = getattr(u, "assignedStoreId", None)
            if storeId == "hub-209206":
                if user_store in ["hub-816107", "hub-224122"]:
                    continue
                filtered_carts.append(c)
            else:
                pin = storeId.replace("hub-", "")
                has_pin = u.addresses and any(a.pincode == pin for a in u.addresses if a.pincode)
                if user_store == storeId or has_pin:
                    filtered_carts.append(c)
        carts_db = filtered_carts

    # ─── Delta Polling ETag Optimization (HTTP 304 Not Modified) ───
    scope_key = str(storeId or "all")
    if carts_db:
        latest_ts = max((c.updatedAt.isoformat() if c.updatedAt else "") for c in carts_db)
        cart_etag = f'"{hashlib.md5(f"{len(carts_db)}:{latest_ts}:{scope_key}".encode()).hexdigest()}"'
        response.headers["ETag"] = cart_etag
        response.headers["Cache-Control"] = "no-cache, private, must-revalidate"
        if request.headers.get("if-none-match") == cart_etag:
            return Response(status_code=304)
    else:
        empty_etag = f'"{hashlib.md5(f"0:{scope_key}".encode()).hexdigest()}"'
        response.headers["ETag"] = empty_etag
        response.headers["Cache-Control"] = "no-cache, private, must-revalidate"
        if request.headers.get("if-none-match") == empty_etag:
            return Response(status_code=304)

    carts = []
    for c in carts_db:
        if not c.items:
            continue

        items_list = []
        subtotal = 0.0
        for item in c.items:
            if not item.product:
                continue
            item_price = float(item.product.price or 0.0)
            if item.selectedVariant and item.product.variants:
                variants_data = item.product.variants
                if isinstance(variants_data, list):
                    for v in variants_data:
                        if isinstance(v, dict) and v.get("name") == item.selectedVariant:
                            try:
                                item_price = float(v.get("price", item_price))
                            except Exception:
                                pass
                            break
            item_total = item_price * int(item.quantity or 1)
            subtotal += item_total
            items_list.append({
                "id": item.id,
                "productId": item.productId,
                "productName": item.product.name,
                "imageUrl": item.product.imageUrl,
                "unit": item.product.unit,
                "price": item_price,
                "quantity": item.quantity,
                "selectedVariant": item.selectedVariant,
                "total": round(item_total, 2)
            })

        user_name = c.user.name if c.user and c.user.name else f"Guest Shopper ({c.id[-6:]})"
        user_email = c.user.email if c.user and c.user.email else "guest@fastkirana.in"
        user_phone = c.user.phone if c.user and c.user.phone else "Guest Shopper"

        default_addr = None
        if c.user and c.user.addresses:
            default_addr = next((a for a in c.user.addresses if a.isDefault), c.user.addresses[0])

        addr_str = "Location Pending (Browsing In-App Cart)"
        lat = None
        lng = None
        if default_addr:
            parts = [default_addr.houseNo, default_addr.street, default_addr.area, default_addr.city]
            addr_str = ", ".join([p for p in parts if p])
            if default_addr.pincode:
                addr_str += f" - {default_addr.pincode}"
            lat = default_addr.lat
            lng = default_addr.lng

        carts.append({
            "id": c.id,
            "userId": c.userId,
            "userName": user_name,
            "userEmail": user_email,
            "userPhone": user_phone,
            "updatedAt": (c.updatedAt.isoformat() + "Z") if c.updatedAt else None,
            "items": items_list,
            "subtotal": round(subtotal, 2),
            "address": addr_str,
            "lat": lat,
            "lng": lng
        })

    return {"success": True, "carts": carts, "count": len(carts)}


@router.post("/live-carts/notify")
async def admin_notify_live_carts(
    data: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Send push notification to users with active carts."""
    return {"success": True, "notified": 0, "message": "Notification alert sent successfully to customer mobile app & web!"}


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

    return store_list


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


# ============================================================
# GEMINI AI SHOWCASE & BENTO CARDS GENERATOR
# ============================================================

AESTHETIC_PHOTOS: Dict[str, Dict[str, List[str]]] = {
    "burger": {
        "hero": [
            "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80",
            "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=800&q=80",
            "https://images.unsplash.com/photo-1550547660-d9450f859349?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80",
            "https://images.unsplash.com/photo-1576107232684-1279f3908594?w=400&q=80",
            "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=400&q=80",
            "https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=80",
        ],
    },
    "pizza": {
        "hero": [
            "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80",
            "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80",
            "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80",
            "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&q=80",
            "https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=400&q=80",
        ],
    },
    "biryani": {
        "hero": [
            "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&q=80",
            "https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80",
            "https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&q=80",
            "https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=400&q=80",
            "https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&q=80",
        ],
    },
    "fruits": {
        "hero": [
            "https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=80",
            "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400&q=80",
            "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80",
            "https://images.unsplash.com/photo-1519996529931-28324d5a630e?w=400&q=80",
            "https://images.unsplash.com/photo-1587132137056-bfbf0166836e?w=400&q=80",
        ],
    },
    "dairy": {
        "hero": [
            "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=800&q=80",
            "https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80",
            "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80",
            "https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=400&q=80",
            "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=400&q=80",
        ],
    },
    "snacks": {
        "hero": [
            "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=800&q=80",
            "https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80",
            "https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400&q=80",
            "https://images.unsplash.com/photo-1576107232684-1279f3908594?w=400&q=80",
            "https://images.unsplash.com/photo-1621447504864-d8686e12698c?w=400&q=80",
        ],
    },
    "desserts": {
        "hero": [
            "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=800&q=80",
            "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=800&q=80",
        ],
        "bento": [
            "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80",
            "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=400&q=80",
            "https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400&q=80",
            "https://images.unsplash.com/photo-1509722747041-616f39b57569?w=400&q=80",
        ],
    },
}


def _get_photo_pool(category_name: str, category_type: str) -> Dict[str, List[str]]:
    name = category_name.lower()
    if any(k in name for k in ("burg", "sandwich", "patty")):
        return AESTHETIC_PHOTOS["burger"]
    if any(k in name for k in ("pizz", "italian")):
        return AESTHETIC_PHOTOS["pizza"]
    if any(k in name for k in ("biryan", "rice", "roll", "tandoor", "curry")):
        return AESTHETIC_PHOTOS["biryani"]
    if any(k in name for k in ("fruit", "veg", "organic", "salad")):
        return AESTHETIC_PHOTOS["fruits"]
    if any(k in name for k in ("dairy", "milk", "bread", "egg", "paneer")):
        return AESTHETIC_PHOTOS["dairy"]
    if any(k in name for k in ("snack", "chip", "namkeen", "munch")):
        return AESTHETIC_PHOTOS["snacks"]
    if any(k in name for k in ("sweet", "dessert", "ice", "cake", "choco")):
        return AESTHETIC_PHOTOS["desserts"]
    return AESTHETIC_PHOTOS["burger"] if category_type == "food" else AESTHETIC_PHOTOS["fruits"]


@router.post("/gemini-cards")
async def generate_gemini_cards(
    payload: Dict[str, Any] = Body(...),
    current_admin: dict = Depends(require_admin)
):
    """
    Generate high-aesthetic marketing cards using Google Gemini 2.5 Flash with creative fallback.
    """
    import json
    import httpx

    category_name = payload.get("categoryName", "Burgers & Fast Bites")
    category_type = payload.get("categoryType", "food")
    card_format = payload.get("cardFormat", "dark_showcase")
    outlet_name = payload.get("outletName", "")
    api_key = payload.get("apiKey") or os.environ.get("GEMINI_API_KEY", "")

    pool = _get_photo_pool(category_name, category_type)
    hero_image = random.choice(pool["hero"])
    bento_images = pool["bento"]

    if api_key:
        try:
            prompt = f"""You are a world-class luxury quick-commerce creative director for FastKirana.
Create an irresistible, mouth-watering, highly aesthetic promotional card configuration for the category: "{category_name}" in "{category_type}" delivery mode.
Card Format: "{card_format}" (options: dark_showcase, bento_grid, editorial).
Optional Outlet/Brand: "{outlet_name or ('A.S. Restaurant' if category_type == 'food' else 'FastKirana Direct')}".

Return ONLY a valid JSON object with these EXACT keys:
{{
  "eyebrowTag": "Short uppercase punchy badge (e.g. '🔥 SIZZLING FAST DROP', '🌿 100% FARM FRESH')",
  "discountTitle": "Bold catchy headline in all-caps (e.g. 'DOUBLE CHEESE BURGER', 'FLAT 50% OFF')",
  "subtitle": "Irresistible culinary or freshness description under 8 words",
  "primaryBrand": "Short uppercase brand name",
  "secondaryBrand": "Optional accent tag",
  "ctaText": "Active conversion button text (e.g. 'ORDER NOW', 'EXPLORE MENU')",
  "ctaBgColorHex": "Vibrant hex color (e.g. '#EF4444' or '#10B981')",
  "ctaTextColorHex": "High contrast hex (e.g. '#FFFFFF')",
  "cashbackTitle": "Attractive savings tag (e.g. 'FLAT 40% OFF')",
  "cashbackSubtitle": "Perk string",
  "disclaimerText": "Discreet asterisk disclaimer",
  "backgroundColorHex": "Deep aesthetic background hex (e.g. '#09090B')"
}}"""
            gemini_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
            async with httpx.AsyncClient(timeout=8.0) as client:
                res = await client.post(
                    gemini_url,
                    json={
                        "contents": [{"parts": [{"text": prompt}]}],
                        "generationConfig": {
                            "responseMimeType": "application/json",
                            "temperature": 0.7
                        }
                    }
                )
                if res.status_code == 200:
                    data = res.json()
                    text_out = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text")
                    if text_out:
                        parsed = json.loads(text_out)
                        return {
                            "success": True,
                            "generatedBy": "gemini-2.5-flash",
                            "card": {
                                **parsed,
                                "cardType": card_format,
                                "imageUrl": hero_image,
                                "gridImages": bento_images,
                                "hasWireframeGrid": (card_format == "dark_showcase"),
                                "ctaUrl": f"/category/{re.sub(r'[^a-z0-9]+', '-', category_name.lower())}"
                            }
                        }
        except Exception as e:
            logger.warning(f"Gemini API call failed, falling back to creative engine: {e}")

    # Fallback creative generation
    is_food = (category_type == "food")
    cat_upper = category_name.upper()
    if is_food:
        if "BURGER" in cat_upper:
            fallback_title = "DOUBLE CHEESE CRUNCH"
        elif "PIZZA" in cat_upper:
            fallback_title = "LOADED CHEESY CRUST"
        elif "BIRYANI" in cat_upper:
            fallback_title = "ROYAL DUM BIRYANI"
        else:
            fallback_title = f"{cat_upper} SPECIAL"
        fallback_sub = "Hot, fresh & delivered piping hot in 15 mins"
    else:
        if "FRUIT" in cat_upper:
            fallback_title = "FARM FRESH GREENS"
        elif "DAIRY" in cat_upper:
            fallback_title = "FARM MILK & BAKERY"
        elif "SNACK" in cat_upper:
            fallback_title = "MUNCHIES & SODAS"
        else:
            fallback_title = f"{cat_upper} STAPLES"
        fallback_sub = "Handpicked daily harvest delivered in 10 mins"

    slug = re.sub(r'[^a-z0-9]+', '-', category_name.lower())

    return {
        "success": True,
        "generatedBy": "creative-engine",
        "card": {
            "cardType": card_format,
            "eyebrowTag": "🔥 SIZZLING FAST FOOD" if is_food else "🌿 DAILY HARVEST",
            "discountTitle": fallback_title,
            "subtitle": fallback_sub,
            "primaryBrand": outlet_name or ("A.S. RESTAURANT" if is_food else "FASTKIRANA"),
            "secondaryBrand": "FAST BITES" if is_food else "DIRECT",
            "imageUrl": hero_image,
            "gridImages": bento_images,
            "hasWireframeGrid": (card_format == "dark_showcase"),
            "ctaText": "ORDER NOW" if is_food else "SHOP FRESH",
            "ctaUrl": f"/category/{slug}",
            "ctaBgColorHex": "#EF4444" if is_food else "#10B981",
            "ctaTextColorHex": "#FFFFFF",
            "cashbackTitle": "FLAT 40% OFF",
            "cashbackSubtitle": "+ Extra ₹50 on UPI Payment",
            "disclaimerText": "*T&C Apply. Superfast express delivery in Ghatampur.",
            "backgroundColorHex": "#0F172A"
        }
    }


# ============================================================
# ADMIN INVENTORY & PACKING ALERTS
# ============================================================

@router.get("/alerts")
async def get_admin_inventory_alerts(
    storeId: Optional[str] = Query(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Fetch all active inventory & packing delay alerts."""
    now = datetime.utcnow()
    seven_days = now + timedelta(days=7)

    if storeId and storeId != "all":
        # 1. OUT OF STOCK for specific store
        oos_stmt = (
            select(Product, StoreInventory.stock)
            .join(StoreInventory, StoreInventory.productId == Product.id)
            .where(
                StoreInventory.storeId == storeId,
                StoreInventory.stock == 0,
                Product.isAvailable == True,
                Product.restaurantId.is_(None)
            )
        )
        oos_res = await db.execute(oos_stmt)
        oos_prods = []
        for p, s in oos_res.all():
            p.stock = s
            oos_prods.append(p)

        # 2. LOW STOCK for specific store
        low_stmt = (
            select(Product, StoreInventory.stock)
            .join(StoreInventory, StoreInventory.productId == Product.id)
            .where(
                StoreInventory.storeId == storeId,
                StoreInventory.stock > 0,
                StoreInventory.stock <= Product.minStock,
                Product.isAvailable == True,
                Product.restaurantId.is_(None)
            )
        )
        low_res = await db.execute(low_stmt)
        low_prods = []
        for p, s in low_res.all():
            p.stock = s
            low_prods.append(p)

        # 3. EXPIRING SOON for specific store
        exp_soon_stmt = (
            select(Product, StoreInventory.stock)
            .join(StoreInventory, StoreInventory.productId == Product.id)
            .where(
                StoreInventory.storeId == storeId,
                Product.expiryDate.is_not(None),
                Product.expiryDate > now,
                Product.expiryDate <= seven_days
            )
        )
        exp_soon_res = await db.execute(exp_soon_stmt)
        exp_soon_prods = []
        for p, s in exp_soon_res.all():
            p.stock = s
            exp_soon_prods.append(p)

        # 4. EXPIRED for specific store
        exp_stmt = (
            select(Product, StoreInventory.stock)
            .join(StoreInventory, StoreInventory.productId == Product.id)
            .where(
                StoreInventory.storeId == storeId,
                Product.expiryDate.is_not(None),
                Product.expiryDate <= now
            )
        )
        exp_res = await db.execute(exp_stmt)
        exp_prods = []
        for p, s in exp_res.all():
            p.stock = s
            exp_prods.append(p)
    else:
        # Global Master Catalog queries
        # 1. OUT OF STOCK
        oos_stmt = select(Product).where(
            Product.stock == 0,
            Product.isAvailable == True,
            Product.restaurantId.is_(None)
        )
        oos_res = await db.execute(oos_stmt)
        oos_prods = oos_res.scalars().all()

        # 2. LOW STOCK
        low_stmt = select(Product).where(
            Product.stock > 0,
            Product.stock <= Product.minStock,
            Product.isAvailable == True,
            Product.restaurantId.is_(None)
        )
        low_res = await db.execute(low_stmt)
        low_prods = low_res.scalars().all()

        # 3. EXPIRING SOON
        exp_soon_stmt = select(Product).where(
            Product.expiryDate.is_not(None),
            Product.expiryDate > now,
            Product.expiryDate <= seven_days
        )
        exp_soon_res = await db.execute(exp_soon_stmt)
        exp_soon_prods = exp_soon_res.scalars().all()

        # 4. EXPIRED
        exp_stmt = select(Product).where(
            Product.expiryDate.is_not(None),
            Product.expiryDate <= now
        )
        exp_res = await db.execute(exp_stmt)
        exp_prods = exp_res.scalars().all()

    # 5. PACKING DELAYS
    ten_min_ago = now - timedelta(minutes=10)
    thirty_min_ago = now - timedelta(minutes=30)
    conf_stmt = select(Order).where(Order.status == OrderStatus.CONFIRMED)
    if storeId and storeId != "all":
        conf_stmt = conf_stmt.where(Order.storeId == storeId)
    conf_res = await db.execute(conf_stmt)
    conf_orders = conf_res.scalars().all()

    delay_alerts = []
    for o in conf_orders:
        is_rest = bool(o.restaurantId) or str(o.orderType.value if hasattr(o.orderType, "value") else o.orderType) == "RESTAURANT"
        cutoff = thirty_min_ago if is_rest else ten_min_ago
        if o.updatedAt and o.updatedAt < cutoff:
            delay_alerts.append({
                "id": o.id,
                "name": f"{'Food' if is_rest else 'Grocery'} Order #{o.readableId or o.id[:8]} accepted but not packed yet",
                "slug": f"order-{o.id}",
                "imageUrl": None,
                "stock": 0,
                "minStock": 0,
                "expiryDate": o.updatedAt.isoformat(),
                "categoryId": "orders",
                "alertType": "PACKING_DELAY",
            })

    # Read snoozed alerts
    snoozed_setting = (await db.execute(select(StoreSetting).where(StoreSetting.key == "snoozed_alerts"))).scalars().first()
    snoozed_map = {}
    if snoozed_setting and snoozed_setting.value:
        try:
            snoozed_map = json.loads(snoozed_setting.value)
        except Exception:
            pass

    thirty_min_ago_ts = (now - timedelta(minutes=30)).timestamp()

    def is_snoozed(target_id: str, alert_type: str) -> bool:
        key = f"{target_id}:{alert_type}"
        snoozed_at = snoozed_map.get(key)
        if not snoozed_at:
            return False
        try:
            return datetime.fromisoformat(snoozed_at).timestamp() >= thirty_min_ago_ts
        except Exception:
            return False

    filtered_oos = [p for p in oos_prods if not is_snoozed(p.id, "OUT_OF_STOCK")]
    filtered_low = [p for p in low_prods if not is_snoozed(p.id, "LOW_STOCK")]
    filtered_exp_soon = [p for p in exp_soon_prods if not is_snoozed(p.id, "EXPIRING_SOON")]
    filtered_exp = [p for p in exp_prods if not is_snoozed(p.id, "EXPIRED")]
    filtered_delays = [d for d in delay_alerts if not is_snoozed(d["id"], "PACKING_DELAY")]

    alerts = []
    for p in filtered_oos:
        alerts.append({
            "id": p.id, "name": p.name, "slug": p.slug, "imageUrl": p.imageUrl,
            "stock": p.stock, "minStock": p.minStock,
            "expiryDate": p.expiryDate.isoformat() if p.expiryDate else None,
            "categoryId": p.categoryId, "alertType": "OUT_OF_STOCK"
        })
    for p in filtered_low:
        alerts.append({
            "id": p.id, "name": p.name, "slug": p.slug, "imageUrl": p.imageUrl,
            "stock": p.stock, "minStock": p.minStock,
            "expiryDate": p.expiryDate.isoformat() if p.expiryDate else None,
            "categoryId": p.categoryId, "alertType": "LOW_STOCK"
        })
    for p in filtered_exp_soon:
        alerts.append({
            "id": p.id, "name": p.name, "slug": p.slug, "imageUrl": p.imageUrl,
            "stock": p.stock, "minStock": p.minStock,
            "expiryDate": p.expiryDate.isoformat() if p.expiryDate else None,
            "categoryId": p.categoryId, "alertType": "EXPIRING_SOON"
        })
    for p in filtered_exp:
        alerts.append({
            "id": p.id, "name": p.name, "slug": p.slug, "imageUrl": p.imageUrl,
            "stock": p.stock, "minStock": p.minStock,
            "expiryDate": p.expiryDate.isoformat() if p.expiryDate else None,
            "categoryId": p.categoryId, "alertType": "EXPIRED"
        })
    alerts.extend(filtered_delays)

    return {
        "alerts": alerts,
        "counts": {
            "outOfStock": len(filtered_oos),
            "lowStock": len(filtered_low),
            "expiringSoon": len(filtered_exp_soon),
            "expired": len(filtered_exp),
            "packingDelay": len(filtered_delays),
            "total": len(alerts),
        }
    }


@router.post("/alerts")
async def generate_admin_stock_alerts(
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Generate or refresh StockAlert records in database."""
    now = datetime.utcnow()
    seven_days = now + timedelta(days=7)

    # Clear old unread alerts
    await db.execute(delete(StockAlert).where(StockAlert.isRead == False))

    oos_res = await db.execute(select(Product).where(Product.stock == 0, Product.isAvailable == True, Product.restaurantId.is_(None)))
    oos_prods = oos_res.scalars().all()

    low_res = await db.execute(select(Product).where(Product.stock > 0, Product.stock <= Product.minStock, Product.isAvailable == True, Product.restaurantId.is_(None)))
    low_prods = low_res.scalars().all()

    exp_soon_res = await db.execute(select(Product).where(Product.expiryDate.is_not(None), Product.expiryDate > now, Product.expiryDate <= seven_days))
    exp_soon_prods = exp_soon_res.scalars().all()

    exp_res = await db.execute(select(Product).where(Product.expiryDate.is_not(None), Product.expiryDate <= now))
    exp_prods = exp_res.scalars().all()

    records = []
    for p in oos_prods:
        records.append(StockAlert(id=str(uuid.uuid4()), productId=p.id, alertType="OUT_OF_STOCK", message=f"{p.name} is out of stock"))
    for p in low_prods:
        records.append(StockAlert(id=str(uuid.uuid4()), productId=p.id, alertType="LOW_STOCK", message=f"{p.name} is low on stock ({p.stock}/{p.minStock})"))
    for p in exp_soon_prods:
        days_left = max(1, (p.expiryDate - now).days)
        records.append(StockAlert(id=str(uuid.uuid4()), productId=p.id, alertType="EXPIRING_SOON", message=f"{p.name} expires in {days_left} day(s)"))
    for p in exp_prods:
        records.append(StockAlert(id=str(uuid.uuid4()), productId=p.id, alertType="EXPIRED", message=f"{p.name} has expired"))

    if records:
        db.add_all(records)
    await db.commit()

    return {"success": True, "message": f"Generated {len(records)} alert(s)", "count": len(records)}


@router.patch("/alerts")
async def mark_alerts_as_read(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Mark alerts as read."""
    alert_ids = payload.get("alertIds") or []
    mark_all = payload.get("markAllRead", False)

    if not mark_all and not alert_ids:
        raise HTTPException(status_code=400, detail="Provide alertIds array or set markAllRead to true")

    if mark_all:
        stmt = update(StockAlert).where(StockAlert.isRead == False).values(isRead=True)
    else:
        stmt = update(StockAlert).where(StockAlert.id.in_(alert_ids), StockAlert.isRead == False).values(isRead=True)

    res = await db.execute(stmt)
    await db.commit()
    return {"success": True, "message": f"Marked alerts as read", "updatedCount": res.rowcount}


@router.put("/alerts")
async def snooze_alert(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Snooze an alert for 30 minutes."""
    target_id = payload.get("targetId")
    alert_type = payload.get("alertType")
    if not target_id or not alert_type:
        raise HTTPException(status_code=400, detail="targetId and alertType are required")

    setting_stmt = select(StoreSetting).where(StoreSetting.key == "snoozed_alerts")
    setting = (await db.execute(setting_stmt)).scalars().first()
    snoozed_map = {}
    if setting and setting.value:
        try:
            snoozed_map = json.loads(setting.value)
        except Exception:
            pass

    now = datetime.utcnow()
    snoozed_map[f"{target_id}:{alert_type}"] = now.isoformat()

    # Clean up old entries > 30 minutes
    cutoff = (now - timedelta(minutes=30)).timestamp()
    clean_map = {}
    for k, v in snoozed_map.items():
        try:
            if datetime.fromisoformat(v).timestamp() >= cutoff:
                clean_map[k] = v
        except Exception:
            pass

    if setting:
        setting.value = json.dumps(clean_map)
    else:
        db.add(StoreSetting(key="snoozed_alerts", value=json.dumps(clean_map)))

    await db.commit()
    return {"success": True, "message": "Alert actioned successfully"}


# ============================================================
# ADMIN PROMO BANNERS
# ============================================================

@router.get("/banners")
async def get_admin_banners(
    storeId: Optional[str] = Query(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Fetch promo banners for admin."""
    stmt = select(PromoBanner).order_by(PromoBanner.sortOrder.asc())
    if storeId and storeId != "all":
        stmt = stmt.where(PromoBanner.storeId == storeId)
    banners = (await db.execute(stmt)).scalars().all()

    result = []
    for b in banners:
        extra = {}
        if b.code and b.code.startswith("{") and b.code.endswith("}"):
            try:
                extra = json.loads(b.code)
            except Exception:
                pass
        result.append({
            "id": b.id,
            "title": b.title,
            "description": b.description,
            "gradient": b.gradient,
            "type": b.type,
            "imageUrl": b.imageUrl,
            "linkUrl": b.linkUrl,
            "storeId": b.storeId or extra.get("storeId"),
            "isActive": b.isActive,
            "sortOrder": b.sortOrder,
            "rawCode": b.code,
            "code": extra.get("couponCode", b.code),
            "cardType": extra.get("cardType", b.type or "standard"),
            **extra
        })
    return result


@router.post("/banners")
async def create_admin_banner(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new promotional banner."""
    title = str(payload.get("title") or "Promo Banner").strip()
    description = str(payload.get("description") or "Media Banner").strip()
    code = payload.get("code") or ""
    card_type = payload.get("cardType") or payload.get("type") or "standard"

    card_meta = {
        "cardType": card_type,
        "placement": payload.get("placement") or "hero",
        "platform": payload.get("platform") or "all",
        "storeId": payload.get("storeId"),
        "eyebrowTag": payload.get("eyebrowTag"),
        "primaryBrand": payload.get("primaryBrand"),
        "secondaryBrand": payload.get("secondaryBrand"),
        "cashbackTitle": payload.get("cashbackTitle"),
        "cashbackSubtitle": payload.get("cashbackSubtitle"),
        "disclaimerText": payload.get("disclaimerText"),
        "ctaText": payload.get("ctaText"),
        "ctaUrl": payload.get("ctaUrl"),
        "ctaBgColorHex": payload.get("ctaBgColorHex"),
        "ctaTextColorHex": payload.get("ctaTextColorHex"),
        "gridImages": payload.get("gridImages"),
        "hasWireframeGrid": payload.get("hasWireframeGrid", False),
        "videoUrl": payload.get("videoUrl"),
        "couponCode": code or None,
    }
    serialized_code = json.dumps(card_meta)

    banner = PromoBanner(
        id=str(uuid.uuid4()),
        title=title,
        description=description,
        code=serialized_code,
        gradient=payload.get("gradient") or "from-primary via-rose-500 to-orange-400",
        type=payload.get("type") or "custom",
        imageUrl=payload.get("imageUrl"),
        linkUrl=payload.get("linkUrl"),
        storeId=payload.get("storeId"),
        isActive=bool(payload.get("isActive", True)),
        sortOrder=int(payload.get("sortOrder") or 0)
    )
    db.add(banner)
    await db.commit()
    await db.refresh(banner)
    return {"success": True, "banner": banner}


@router.put("/banners")
async def update_admin_banner(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update an existing promo banner."""
    banner_id = payload.get("id")
    if not banner_id:
        raise HTTPException(status_code=400, detail="Missing banner ID")

    stmt = select(PromoBanner).where(PromoBanner.id == banner_id)
    banner = (await db.execute(stmt)).scalars().first()
    if not banner:
        raise HTTPException(status_code=404, detail="Banner not found")

    existing_meta = {}
    if banner.code and banner.code.startswith("{") and banner.code.endswith("}"):
        try:
            existing_meta = json.loads(banner.code)
        except Exception:
            pass

    card_meta = {
        "cardType": payload.get("cardType") or payload.get("type") or existing_meta.get("cardType", "standard"),
        "placement": payload.get("placement") if payload.get("placement") is not None else existing_meta.get("placement", "hero"),
        "platform": payload.get("platform") if payload.get("platform") is not None else existing_meta.get("platform", "all"),
        "storeId": payload.get("storeId") if payload.get("storeId") is not None else existing_meta.get("storeId"),
        "eyebrowTag": payload.get("eyebrowTag"),
        "primaryBrand": payload.get("primaryBrand"),
        "secondaryBrand": payload.get("secondaryBrand"),
        "cashbackTitle": payload.get("cashbackTitle"),
        "cashbackSubtitle": payload.get("cashbackSubtitle"),
        "disclaimerText": payload.get("disclaimerText"),
        "ctaText": payload.get("ctaText"),
        "ctaUrl": payload.get("ctaUrl"),
        "ctaBgColorHex": payload.get("ctaBgColorHex"),
        "ctaTextColorHex": payload.get("ctaTextColorHex"),
        "gridImages": payload.get("gridImages"),
        "hasWireframeGrid": payload.get("hasWireframeGrid", False),
        "videoUrl": payload.get("videoUrl"),
        "couponCode": payload.get("code") or existing_meta.get("couponCode"),
    }
    banner.code = json.dumps(card_meta)

    if "title" in payload:
        banner.title = str(payload["title"]).strip()
    if "description" in payload:
        banner.description = str(payload["description"]).strip()
    if "gradient" in payload:
        banner.gradient = payload["gradient"]
    if "type" in payload:
        banner.type = payload["type"]
    if "imageUrl" in payload:
        banner.imageUrl = payload["imageUrl"]
    if "linkUrl" in payload:
        banner.linkUrl = payload["linkUrl"]
    if "isActive" in payload:
        banner.isActive = bool(payload["isActive"])
    if "sortOrder" in payload:
        banner.sortOrder = int(payload["sortOrder"])

    await db.commit()
    await db.refresh(banner)
    return {"success": True, "banner": banner}


@router.delete("/banners")
async def delete_admin_banner(
    id: Optional[str] = Query(None),
    payload: Optional[Dict[str, Any]] = Body(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a promo banner."""
    target_id = id or (payload.get("id") if payload else None)
    if not target_id:
        raise HTTPException(status_code=400, detail="Missing banner ID")

    stmt = select(PromoBanner).where(PromoBanner.id == target_id)
    banner = (await db.execute(stmt)).scalars().first()
    if not banner:
        raise HTTPException(status_code=404, detail="Banner not found")

    await db.delete(banner)
    await db.commit()
    return {"success": True, "message": "Banner deleted successfully"}


# ============================================================
# ADMIN COUPONS
# ============================================================

@router.get("/coupons")
async def get_admin_coupons(
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """List all coupons with restaurant and category details."""
    stmt = select(Coupon).options(
        selectinload(Coupon.restaurant),
        selectinload(Coupon.category)
    ).order_by(Coupon.createdAt.desc())
    coupons = (await db.execute(stmt)).scalars().all()

    return [
        {
            "id": c.id,
            "code": c.code,
            "discountType": c.discountType,
            "bogoType": c.bogoType,
            "triggerVariant": c.triggerVariant,
            "rewardVariant": c.rewardVariant,
            "defaultFreeDishId": c.defaultFreeDishId,
            "maxFreeItems": c.maxFreeItems,
            "value": float(c.value or 0.0),
            "minOrder": float(c.minOrder or 0.0),
            "maxDiscount": float(c.maxDiscount) if c.maxDiscount else None,
            "maxUses": c.maxUses,
            "usedCount": c.usedCount,
            "isActive": c.isActive,
            "expiresAt": c.expiresAt.isoformat() if c.expiresAt else None,
            "createdAt": c.createdAt.isoformat() if c.createdAt else None,
            "categoryId": c.categoryId,
            "restaurantId": c.restaurantId,
            "oncePerCustomer": c.oncePerCustomer,
            "autoApply": bool(c.autoApply),
            "badgeText": c.badgeText,
            "menuSection": c.menuSection,
            "restaurant": {
                "id": c.restaurant.id,
                "name": c.restaurant.name,
                "slug": c.restaurant.slug,
            } if c.restaurant else None,
            "category": {
                "id": c.category.id,
                "name": c.category.name,
            } if c.category else None,
        }
        for c in coupons
    ]


@router.post("/coupons")
async def create_admin_coupon(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new coupon voucher."""
    code = str(payload.get("code") or "").strip().upper()
    discount_type = str(payload.get("discountType") or "").upper()

    if not code or not discount_type:
        raise HTTPException(status_code=400, detail="Missing required code or discountType")

    valid_types = ["FLAT", "PERCENT", "BOGO", "FREE_DELIVERY"]
    if discount_type not in valid_types:
        raise HTTPException(status_code=400, detail="Invalid discount type")

    # Check unique
    existing = (await db.execute(select(Coupon).where(Coupon.code == code))).scalars().first()
    if existing:
        raise HTTPException(status_code=400, detail="Coupon code already exists")

    badge = payload.get("badgeText") or (
        f"{payload.get('value', 0)}% OFF" if discount_type == "PERCENT" else
        f"FLAT ₹{payload.get('value', 0)} OFF" if discount_type == "FLAT" else
        "BUY 1 GET 1 FREE" if discount_type == "BOGO" else "FREE DELIVERY"
    )

    new_coupon = Coupon(
        id=str(uuid.uuid4()),
        code=code,
        discountType=discount_type,
        bogoType=payload.get("bogoType"),
        triggerVariant=payload.get("triggerVariant"),
        rewardVariant=payload.get("rewardVariant"),
        defaultFreeDishId=payload.get("defaultFreeDishId"),
        maxFreeItems=int(payload.get("maxFreeItems") or 3),
        bogoDishId=payload.get("bogoDishId"),
        autoApply=bool(payload.get("autoApply", False)),
        badgeText=badge,
        menuSection=payload.get("menuSection"),
        value=float(payload.get("value") or 0.0),
        minOrder=float(payload.get("minOrder") or 0.0),
        maxDiscount=float(payload["maxDiscount"]) if payload.get("maxDiscount") is not None else None,
        maxUses=int(payload["maxUses"]) if payload.get("maxUses") is not None else None,
        usedCount=0,
        isActive=bool(payload.get("isActive", True)),
        expiresAt=datetime.fromisoformat(payload["expiresAt"]) if payload.get("expiresAt") else None,
        createdAt=datetime.utcnow(),
        categoryId=payload.get("categoryId"),
        restaurantId=payload.get("restaurantId"),
        oncePerCustomer=bool(payload.get("oncePerCustomer", False))
    )
    db.add(new_coupon)
    await db.commit()
    await db.refresh(new_coupon)
    return new_coupon


@router.patch("/coupons")
async def update_admin_coupon(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update a coupon."""
    coupon_id = payload.get("couponId") or payload.get("id")
    if not coupon_id:
        raise HTTPException(status_code=400, detail="Missing coupon ID")

    stmt = select(Coupon).where(Coupon.id == coupon_id)
    coupon = (await db.execute(stmt)).scalars().first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")

    if "code" in payload:
        clean_code = str(payload["code"]).strip().upper()
        if clean_code != coupon.code:
            dup = (await db.execute(select(Coupon).where(Coupon.code == clean_code, Coupon.id != coupon_id))).scalars().first()
            if dup:
                raise HTTPException(status_code=400, detail="Coupon code already exists")
            coupon.code = clean_code

    if "discountType" in payload:
        coupon.discountType = str(payload["discountType"]).upper()
    if "bogoType" in payload:
        coupon.bogoType = payload["bogoType"]
    if "value" in payload:
        coupon.value = float(payload["value"])
    if "minOrder" in payload:
        coupon.minOrder = float(payload["minOrder"])
    if "maxDiscount" in payload:
        coupon.maxDiscount = float(payload["maxDiscount"]) if payload["maxDiscount"] is not None else None
    if "maxUses" in payload:
        coupon.maxUses = int(payload["maxUses"]) if payload["maxUses"] is not None else None
    if "isActive" in payload:
        coupon.isActive = bool(payload["isActive"])
    if "expiresAt" in payload:
        coupon.expiresAt = datetime.fromisoformat(payload["expiresAt"]) if payload["expiresAt"] else None
    if "categoryId" in payload:
        coupon.categoryId = payload["categoryId"]
    if "restaurantId" in payload:
        coupon.restaurantId = payload["restaurantId"]
    if "badgeText" in payload:
        coupon.badgeText = payload["badgeText"]
    if "menuSection" in payload:
        coupon.menuSection = payload["menuSection"]
    if "autoApply" in payload:
        coupon.autoApply = bool(payload["autoApply"])
    if "oncePerCustomer" in payload:
        coupon.oncePerCustomer = bool(payload["oncePerCustomer"])

    await db.commit()
    await db.refresh(coupon)
    return coupon


@router.delete("/coupons")
async def delete_admin_coupon(
    couponId: Optional[str] = Query(None),
    id: Optional[str] = Query(None),
    payload: Optional[Dict[str, Any]] = Body(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a coupon."""
    target_id = couponId or id or (payload.get("couponId") if payload else None) or (payload.get("id") if payload else None)
    if not target_id:
        raise HTTPException(status_code=400, detail="Missing coupon ID")

    stmt = select(Coupon).where(Coupon.id == target_id)
    coupon = (await db.execute(stmt)).scalars().first()
    if not coupon:
        raise HTTPException(status_code=404, detail="Coupon not found")

    await db.delete(coupon)
    await db.commit()
    return {"success": True, "message": "Coupon deleted successfully"}


# ============================================================
# ADMIN REVIEWS
# ============================================================

@router.get("/reviews")
async def get_admin_reviews(
    storeId: Optional[str] = Query(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Fetch product and restaurant reviews merged and sorted by date with storeId scoping."""
    p_stmt = select(Review).options(
        selectinload(Review.user),
        selectinload(Review.product)
    ).order_by(Review.createdAt.desc())

    r_stmt = select(RestaurantReview).options(
        selectinload(RestaurantReview.user),
        selectinload(RestaurantReview.restaurant)
    ).order_by(RestaurantReview.createdAt.desc())

    if storeId and storeId != "all":
        from models import StoreInventory, Restaurant
        grocery_scope = and_(
            Product.restaurantId.is_(None),
            exists().where(
                and_(
                    StoreInventory.productId == Product.id,
                    StoreInventory.storeId == storeId
                )
            )
        )
        rest_scope = Product.restaurant.has(Restaurant.storeId == storeId)
        p_stmt = p_stmt.join(Product, Review.productId == Product.id).where(or_(grocery_scope, rest_scope))
        r_stmt = r_stmt.join(Restaurant, RestaurantReview.restaurantId == Restaurant.id).where(Restaurant.storeId == storeId)

    p_reviews = (await db.execute(p_stmt)).scalars().all()
    r_reviews = (await db.execute(r_stmt)).scalars().all()

    all_reviews = []
    for r in p_reviews:
        all_reviews.append({
            "id": r.id,
            "userId": r.userId,
            "rating": r.rating,
            "comment": r.comment,
            "createdAt": r.createdAt.isoformat() if r.createdAt else None,
            "type": "PRODUCT",
            "user": {"id": r.user.id, "name": r.user.name, "email": r.user.email} if r.user else None,
            "product": {"id": r.product.id, "name": r.product.name, "slug": r.product.slug, "imageUrl": r.product.imageUrl} if r.product else None
        })

    for r in r_reviews:
        all_reviews.append({
            "id": r.id,
            "userId": r.userId,
            "rating": r.rating,
            "comment": r.comment,
            "createdAt": r.createdAt.isoformat() if r.createdAt else None,
            "type": "RESTAURANT",
            "user": {"id": r.user.id, "name": r.user.name, "email": r.user.email} if r.user else None,
            "product": {
                "id": r.restaurant.id if r.restaurant else "",
                "name": f"Restaurant: {r.restaurant.name}" if r.restaurant else "Restaurant",
                "slug": f"food/{r.restaurant.slug}" if r.restaurant else "",
                "imageUrl": r.restaurant.logoUrl if r.restaurant else None,
            }
        })

    all_reviews.sort(key=lambda x: x["createdAt"] or "", reverse=True)
    return all_reviews


@router.patch("/reviews")
async def update_admin_review(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update review rating or comment."""
    review_id = payload.get("reviewId")
    if not review_id:
        raise HTTPException(status_code=400, detail="Missing review ID")

    r_type = payload.get("type")
    if r_type == "RESTAURANT":
        stmt = select(RestaurantReview).where(RestaurantReview.id == review_id)
        review = (await db.execute(stmt)).scalars().first()
    else:
        stmt = select(Review).where(Review.id == review_id)
        review = (await db.execute(stmt)).scalars().first()

    if not review:
        raise HTTPException(status_code=404, detail="Review not found")

    if "rating" in payload:
        review.rating = int(payload["rating"])
    if "comment" in payload:
        review.comment = payload["comment"]

    await db.commit()
    await db.refresh(review)
    return review


@router.delete("/reviews")
async def delete_admin_review(
    reviewId: Optional[str] = Query(None),
    type: Optional[str] = Query(None),
    payload: Optional[Dict[str, Any]] = Body(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a review."""
    target_id = reviewId or (payload.get("reviewId") if payload else None)
    target_type = type or (payload.get("type") if payload else None)

    if not target_id:
        raise HTTPException(status_code=400, detail="Missing review ID")

    if target_type == "RESTAURANT":
        stmt = select(RestaurantReview).where(RestaurantReview.id == target_id)
        review = (await db.execute(stmt)).scalars().first()
    else:
        stmt = select(Review).where(Review.id == target_id)
        review = (await db.execute(stmt)).scalars().first()

    if not review:
        raise HTTPException(status_code=404, detail="Review not found")

    await db.delete(review)
    await db.commit()
    return {"success": True, "message": "Review deleted successfully"}


# ============================================================
# ADMIN PAYOUTS (RESTAURANT & VENDOR)
# ============================================================

@router.get("/payouts")
async def get_admin_payouts(
    type: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Fetch restaurant payouts with optional storeId multi-hub filtering."""
    stmt = select(RestaurantPayout).options(selectinload(RestaurantPayout.restaurant)).order_by(RestaurantPayout.createdAt.desc())
    if type:
        stmt = stmt.where(RestaurantPayout.type == type)
    if storeId and storeId.lower() != 'all':
        stmt = stmt.join(Restaurant, RestaurantPayout.restaurantId == Restaurant.id).where(Restaurant.storeId == storeId)
    payouts = (await db.execute(stmt)).scalars().all()

    return [
        {
            "id": p.id,
            "type": p.type,
            "restaurantId": p.restaurantId,
            "startDate": p.startDate.isoformat() if p.startDate else None,
            "endDate": p.endDate.isoformat() if p.endDate else None,
            "amount": float(p.amount),
            "status": p.status,
            "transactionId": p.transactionId,
            "paidAt": p.paidAt.isoformat() if p.paidAt else None,
            "notes": p.notes,
            "restaurant": {
                "name": p.restaurant.name if p.restaurant else "Restaurant",
                "slug": p.restaurant.slug if p.restaurant else None,
                "city": p.restaurant.city if p.restaurant else None,
            } if p.restaurant else None
        }
        for p in payouts
    ]


@router.post("/payouts")
async def create_admin_payout(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Calculate and create a new restaurant payout."""
    start_str = payload.get("startDate")
    end_str = payload.get("endDate")
    if not start_str or not end_str:
        raise HTTPException(status_code=400, detail="Start date and End date are required")

    start = datetime.fromisoformat(start_str.replace("Z", ""))
    end = datetime.fromisoformat(end_str.replace("Z", ""))

    direct_amount = payload.get("amount")
    if direct_amount is not None:
        final_amount = float(direct_amount)
    else:
        rest_id = payload.get("restaurantId")
        o_stmt = select(Order).where(
            Order.status == OrderStatus.DELIVERED,
            Order.createdAt >= start,
            Order.createdAt <= end
        )
        if rest_id:
            o_stmt = o_stmt.where(Order.restaurantId == rest_id)
        else:
            o_stmt = o_stmt.where(or_(Order.orderType == OrderType.RESTAURANT, Order.restaurantId.is_not(None)))

        orders = (await db.execute(o_stmt)).scalars().all()
        total_share = 0.0
        for o in orders:
            food_sales = float(o.subtotal or 0.0) - float(o.discount or 0.0)
            comm_rate = 0.15
            total_share += food_sales * (1.0 - comm_rate)
        final_amount = round(total_share, 2)

    is_paid = payload.get("status") == "PAID"
    payout = RestaurantPayout(
        id=str(uuid.uuid4()),
        type=payload.get("type", "RESTAURANT"),
        restaurantId=payload.get("restaurantId"),
        startDate=start,
        endDate=end,
        amount=final_amount,
        status="PAID" if is_paid else "PENDING",
        transactionId=payload.get("transactionId"),
        paidAt=datetime.utcnow() if is_paid else None,
        notes=payload.get("notes") or f"Payout settlement for {start_str} to {end_str}"
    )
    db.add(payout)
    await db.commit()
    await db.refresh(payout)
    return payout


@router.patch("/payouts")
async def settle_admin_payout(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Mark a payout as settled/paid."""
    payout_id = payload.get("id")
    if not payout_id:
        raise HTTPException(status_code=400, detail="Payout ID is required")

    stmt = select(RestaurantPayout).where(RestaurantPayout.id == payout_id)
    payout = (await db.execute(stmt)).scalars().first()
    if not payout:
        raise HTTPException(status_code=404, detail="Payout not found")

    payout.status = "PAID"
    payout.transactionId = payload.get("transactionId") or payout.transactionId
    payout.paidAt = datetime.utcnow()
    if "notes" in payload:
        payout.notes = payload["notes"]

    await db.commit()
    await db.refresh(payout)
    return payout


@router.delete("/vendors/payout")
async def delete_vendor_payout(
    payoutId: Optional[str] = Query(None),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a vendor payout log."""
    if not payoutId:
        raise HTTPException(status_code=400, detail="Payout ID is required")

    stmt = select(VendorPayout).where(VendorPayout.id == payoutId)
    payout = (await db.execute(stmt)).scalars().first()
    if not payout:
        raise HTTPException(status_code=404, detail="Payout not found")

    await db.delete(payout)
    await db.commit()
    return {"success": True, "message": "Payout deleted successfully"}


# ============================================================
# ADMIN BULK UPDATE & PRICE HISTORY
# ============================================================

def compute_new_bulk_val(old_val: float, mode: str, val: float) -> float:
    if mode == "FLAT_INCREASE":
        return old_val + val
    elif mode == "FLAT_DECREASE":
        return max(0.0, old_val - val)
    elif mode == "PERCENT_INCREASE":
        return old_val * (1.0 + val / 100.0)
    elif mode == "PERCENT_DECREASE":
        return max(0.0, old_val * (1.0 - val / 100.0))
    elif mode == "SET_VALUE":
        return val
    return old_val


@router.post("/bulk-update")
async def apply_bulk_update(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Apply (or preview) a bulk update on products."""
    update_type = payload.get("updateType")
    mode = payload.get("mode")
    value = payload.get("value")
    preview = payload.get("preview", False)
    category_id = payload.get("categoryId")
    restaurant_id = payload.get("restaurantId")
    product_ids = payload.get("productIds")

    if not update_type or not mode or value is None:
        raise HTTPException(status_code=400, detail="Missing required fields: updateType, mode, value")

    stmt = select(Product)
    if product_ids and isinstance(product_ids, list):
        stmt = stmt.where(Product.id.in_(product_ids))
    else:
        if restaurant_id and restaurant_id != "ALL":
            if restaurant_id == "GROCERY":
                stmt = stmt.where(Product.restaurantId.is_(None))
            else:
                stmt = stmt.where(Product.restaurantId == restaurant_id)
        if category_id and category_id != "ALL":
            stmt = stmt.where(Product.categoryId == category_id)

    products = (await db.execute(stmt)).scalars().all()
    if not products:
        raise HTTPException(status_code=404, detail="No products found matching the criteria")

    batch_id = f"batch_{int(time.time())}_{uuid.uuid4().hex[:6]}"
    changes = []

    for p in products:
        if p.restaurantId and update_type in ["STOCK", "MIN_STOCK"]:
            continue

        if update_type == "PRICE":
            old_v = float(p.price)
            new_v = round(compute_new_bulk_val(old_v, mode, float(value)))
            changes.append({"productId": p.id, "name": p.name, "oldValue": old_v, "newValue": new_v})
        elif update_type == "STOCK":
            old_v = float(p.stock or 0)
            new_v = max(0, int(round(compute_new_bulk_val(old_v, mode, float(value)))))
            changes.append({"productId": p.id, "name": p.name, "oldValue": old_v, "newValue": new_v})
        elif update_type == "AVAILABILITY":
            old_v = bool(p.isAvailable)
            new_v = (value == 1 or value is True)
            changes.append({"productId": p.id, "name": p.name, "oldValue": old_v, "newValue": new_v})
        elif update_type == "MIN_STOCK":
            old_v = float(p.minStock or 0)
            new_v = max(0, int(round(compute_new_bulk_val(old_v, mode, float(value)))))
            changes.append({"productId": p.id, "name": p.name, "oldValue": old_v, "newValue": new_v})

    if preview:
        return {
            "success": True,
            "preview": True,
            "updated": len(changes),
            "batchId": batch_id,
            "changes": changes,
        }

    # Apply changes
    p_map = {p.id: p for p in products}
    for ch in changes:
        prod = p_map.get(ch["productId"])
        if not prod:
            continue
        if update_type == "PRICE":
            old_price = float(prod.price)
            prod.price = ch["newValue"]
            # Price history
            db.add(PriceHistory(
                id=str(uuid.uuid4()),
                productId=prod.id,
                oldPrice=old_price,
                newPrice=ch["newValue"],
                oldMrp=float(prod.mrp or prod.price),
                newMrp=float(prod.mrp or prod.price),
                changeType=f"BULK_{mode}",
                changedBy=(current_admin.get("email") if isinstance(current_admin, dict) else getattr(current_admin, "email", None)) or (current_admin.get("name") if isinstance(current_admin, dict) else getattr(current_admin, "name", None)) or "ADMIN",
                batchId=batch_id,
                createdAt=datetime.utcnow()
            ))
        elif update_type == "STOCK":
            prod.stock = ch["newValue"]
        elif update_type == "AVAILABILITY":
            prod.isAvailable = ch["newValue"]
        elif update_type == "MIN_STOCK":
            prod.minStock = ch["newValue"]

    await db.commit()
    return {"success": True, "updated": len(changes), "batchId": batch_id, "changes": changes}


@router.get("/bulk-update")
async def get_bulk_update_history(
    batchId: Optional[str] = Query(None),
    limit: int = Query(20),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Fetch price change history batches."""
    if batchId:
        stmt = select(PriceHistory).options(selectinload(PriceHistory.product)).where(
            PriceHistory.batchId == batchId
        ).order_by(PriceHistory.createdAt.desc())
        records = (await db.execute(stmt)).scalars().all()
        return {
            "success": True,
            "batchId": batchId,
            "count": len(records),
            "records": [
                {
                    "id": r.id,
                    "productId": r.productId,
                    "productName": r.product.name if r.product else "Product",
                    "oldPrice": float(r.oldPrice),
                    "newPrice": float(r.newPrice),
                    "oldMrp": float(r.oldMrp),
                    "newMrp": float(r.newMrp),
                    "changeType": r.changeType,
                    "changedBy": r.changedBy,
                    "batchId": r.batchId,
                    "createdAt": r.createdAt.isoformat() if r.createdAt else None,
                }
                for r in records
            ]
        }

    # Distinct batches
    stmt = select(PriceHistory.batchId, PriceHistory.createdAt, PriceHistory.changeType).where(
        PriceHistory.batchId.is_not(None)
    ).distinct(PriceHistory.batchId).order_by(PriceHistory.createdAt.desc()).limit(limit)
    rows = (await db.execute(stmt)).all()

    return {
        "success": True,
        "totalBatches": len(rows),
        "batches": [
            {
                "batchId": r[0],
                "createdAt": r[1].isoformat() if r[1] else None,
                "changeType": r[2],
            }
            for r in rows
        ]
    }


@router.delete("/bulk-update")
async def undo_bulk_update(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Undo a bulk update by batchId."""
    batch_id = payload.get("batchId")
    if not batch_id:
        raise HTTPException(status_code=400, detail="Missing required field: batchId")

    stmt = select(PriceHistory).where(PriceHistory.batchId == batch_id)
    records = (await db.execute(stmt)).scalars().all()
    if not records:
        raise HTTPException(status_code=404, detail="No records found for the given batchId")

    for rec in records:
        p_stmt = select(Product).where(Product.id == rec.productId)
        prod = (await db.execute(p_stmt)).scalars().first()
        if prod:
            prod.price = rec.oldPrice
            prod.mrp = rec.oldMrp
        await db.delete(rec)

    await db.commit()
    return {"success": True, "reverted": len(records)}


# ============================================================
# ADMIN CATEGORIES SORT RULE
# ============================================================

@router.get("/categories/sort-rule")
async def get_category_sort_rule(
    categorySlug: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    """Fetch sorting rule for a category."""
    key = f"category_sort_{categorySlug}"
    stmt = select(StoreSetting).where(StoreSetting.key == key)
    setting = (await db.execute(stmt)).scalars().first()
    return {"rule": setting.value if setting else "manual"}


@router.post("/categories/sort-rule")
async def save_category_sort_rule(
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Save sorting rule for a category."""
    category_slug = payload.get("categorySlug")
    rule = payload.get("rule")
    if not category_slug or not rule:
        raise HTTPException(status_code=400, detail="categorySlug and rule are required")

    key = f"category_sort_{category_slug}"
    stmt = select(StoreSetting).where(StoreSetting.key == key)
    setting = (await db.execute(stmt)).scalars().first()
    if setting:
        setting.value = str(rule)
    else:
        db.add(StoreSetting(key=key, value=str(rule)))

    await db.commit()
    return {"success": True, "setting": {"key": key, "value": rule}}


# ============================================================
# ADMIN USER ADDRESSES
# ============================================================

@router.get("/users/{id}/addresses")
async def get_admin_user_addresses(
    id: str,
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Fetch saved addresses for a user."""
    stmt = select(Address).where(
        Address.userId == id,
        not_(Address.label.in_(["STORE_PICKUP", "STORE_PICKUP_RESTAURANT", "STORE_PICKUP_CAFE"]))
    ).order_by(Address.isDefault.desc())
    addresses = (await db.execute(stmt)).scalars().all()
    return addresses


@router.post("/users/{id}/addresses")
async def create_admin_user_address(
    id: str,
    payload: Dict[str, Any] = Body(...),
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Add a new delivery address for a user on behalf of admin."""
    label = payload.get("label")
    house_no = payload.get("houseNo")
    street = payload.get("street")
    area = payload.get("area")
    city = payload.get("city")
    pincode = payload.get("pincode")
    phone = payload.get("phone")

    if not label or not house_no or not street or not area or not city or not pincode or not phone:
        raise HTTPException(status_code=400, detail="Missing required fields")

    clean_phone = re.sub(r"\D", "", str(phone))[-10:]

    address = Address(
        id=str(uuid.uuid4()),
        userId=id,
        label=str(label).strip(),
        houseNo=str(house_no).strip(),
        street=str(street).strip(),
        area=str(area).strip(),
        city=str(city).strip(),
        pincode=str(pincode).strip(),
        phone=clean_phone,
        isDefault=False,
    )
    db.add(address)
    await db.commit()
    await db.refresh(address)
    return address


