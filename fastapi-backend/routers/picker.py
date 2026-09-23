from fastapi import APIRouter, Depends, HTTPException, status, Query, Body, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, or_, text, not_
from sqlalchemy.orm import selectinload
from typing import List, Dict, Any, Optional
from datetime import datetime
import re
import uuid
import logging

from database import get_db
from models import (
    Order, OrderItem, User, Product, Address, Restaurant, 
    OrderStatus, OrderType, Role, Category, StoreInventory, DarkStore
)
from routers.auth import get_current_user, require_auth

logger = logging.getLogger(__name__)

picker_router = APIRouter(prefix="/picker", tags=["Picker & Chef Operations"])


def require_picker_or_chef(current_user: dict) -> dict:
    role = current_user.get("role")
    if role not in ["PICKER", "CHEF", "RESTAURANT_OWNER", "ADMIN"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    return current_user


async def get_current_picker_or_admin(
    request: Request,
    current_user: Optional[dict] = Depends(get_current_user)
) -> dict:
    """Authenticate picker, admin, or staff via JWT or x-user-role header."""
    if current_user:
        role = current_user.get("role")
        if role in ["PICKER", "ADMIN", "CHEF", "RESTAURANT_OWNER"]:
            return current_user
    header_role = (request.headers.get("x-user-role") or "").upper()
    if header_role in ["PICKER", "ADMIN", "CHEF"]:
        return {
            "id": request.headers.get("x-user-id") or "staff-picker",
            "role": header_role,
            "email": "picker@fastkirana.com",
            "name": "Picker Staff",
            "assignedStoreId": request.headers.get("x-store-id") or "hub-209206"
        }
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized: Picker or Admin access required"
        )
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Forbidden: Picker or Admin role required"
    )


def format_picker_product(p: Product, inv: Optional[dict] = None) -> dict:
    """Format product for picker app with optional store-inventory stock/price overlay."""
    inv_stock = inv.get("stock") if inv else None
    inv_avail = inv.get("isAvailable") if inv else None
    inv_price = inv.get("priceOverride") if inv else None
    inv_loc = inv.get("aisleLocation") if inv else None

    price = float(inv_price if inv_price is not None else (p.price or 0))
    mrp = float(p.mrp if p.mrp is not None else price)
    stock = int(inv_stock if inv_stock is not None else (p.stock or 0))
    is_available = bool(inv_avail if inv_avail is not None else (p.isAvailable if p.isAvailable is not None else stock > 0))
    discount = int(p.discount or (round(((mrp - price) / mrp) * 100) if mrp > price > 0 else 0))

    return {
        "id": p.id,
        "name": p.name,
        "slug": p.slug,
        "readableId": p.readableId,
        "categoryId": p.categoryId,
        "restaurantId": p.restaurantId,
        "mrp": mrp,
        "price": price,
        "discount": discount,
        "unit": (p.unit or "1 pc").strip(),
        "stock": stock,
        "minStock": p.minStock or 5,
        "location": inv_loc or p.location,
        "barcode": p.barcode,
        "imageUrl": p.imageUrl or "",
        "description": p.description,
        "expiryDate": p.expiryDate.isoformat() if p.expiryDate else None,
        "isAvailable": is_available,
        "variants": p.variants or [],
        "tags": p.tags or [],
        "category": {
            "id": p.category.id,
            "name": p.category.name,
            "slug": p.category.slug
        } if p.category else None,
        "createdAt": p.createdAt.isoformat() if p.createdAt else None,
        "updatedAt": p.updatedAt.isoformat() if p.updatedAt else None
    }


# ─── PICKER PRODUCTS CRUD (Matching Next.js & Flutter) ─────────────────────────

@picker_router.get("/products")
async def get_picker_products(
    request: Request,
    search: Optional[str] = Query(None),
    categoryId: Optional[str] = Query(None),
    barcode: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    user: dict = Depends(get_current_picker_or_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Fetch dark store grocery products for Picker pricing & stock management.
    Strictly restricted to grocery items (restaurantId is None).
    Supports per-store inventory overlay (e.g. Ghatampur hub-209206).
    """
    effective_store_id = storeId or user.get("assignedStoreId") or "hub-209206"

    filters = [Product.restaurantId.is_(None)]

    if barcode and barcode.strip():
        clean_barcode = barcode.strip()
        filters.append(Product.barcode == clean_barcode)
    else:
        if categoryId and categoryId.strip() and categoryId.upper() != "ALL":
            filters.append(Product.categoryId == categoryId.strip())
        if search and search.strip():
            s = search.strip()
            filters.append(or_(
                Product.name.ilike(f"%{s}%"),
                Product.barcode.ilike(f"%{s}%"),
                Product.location.ilike(f"%{s}%")
            ))

    stmt = select(Product).options(
        selectinload(Product.category)
    ).where(*filters).order_by(desc(Product.createdAt)).limit(limit)

    res = await db.execute(stmt)
    products = res.scalars().all()

    # Hydrate per-store inventory overlay for effective_store_id
    inv_map = {}
    if products and effective_store_id:
        prod_ids = [p.id for p in products]
        inv_stmt = text("""
            SELECT "productId", stock, "isAvailable", "priceOverride", "aisleLocation"
            FROM store_inventories
            WHERE "storeId" = :sid AND "productId" = ANY(:pids)
        """)
        inv_res = await db.execute(inv_stmt, {"sid": effective_store_id, "pids": prod_ids})
        for row in inv_res.fetchall():
            inv_map[row[0]] = {
                "stock": row[1],
                "isAvailable": row[2],
                "priceOverride": row[3],
                "aisleLocation": row[4],
            }

    formatted_products = [
        format_picker_product(p, inv_map.get(p.id))
        for p in products
    ]

    return {"products": formatted_products, "storeId": effective_store_id}


@picker_router.post("/products", status_code=status.HTTP_201_CREATED)
async def create_picker_product(
    payload: Dict[str, Any] = Body(...),
    user: dict = Depends(get_current_picker_or_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new dark store grocery product.
    Strictly grocery domain (restaurantId = None).
    Auto-seeds store_inventories for local hubs.
    """
    name = (payload.get("name") or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Product name is required")

    try:
        mrp = float(payload.get("mrp", 0))
        price = float(payload.get("price", 0))
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="Valid MRP and selling price are required")

    if mrp <= 0 or price <= 0:
        raise HTTPException(status_code=400, detail="Price and MRP must be greater than 0")
    if price > mrp:
        raise HTTPException(status_code=400, detail="Selling price cannot exceed MRP")

    category_id = payload.get("categoryId")
    if not category_id:
        cat_stmt = select(Category).where(
            not_(Category.slug.in_(["restaurant-food", "restaurant", "cafe", "fast-food-kitchen"]))
        ).order_by(Category.sortOrder.asc()).limit(1)
        cat_res = await db.execute(cat_stmt)
        cat_obj = cat_res.scalars().first()
        if cat_obj:
            category_id = cat_obj.id
    else:
        cat_stmt = select(Category).where(Category.id == category_id)
        cat_res = await db.execute(cat_stmt)
        cat_obj = cat_res.scalars().first()
        if not cat_obj:
            raise HTTPException(status_code=400, detail="Invalid category selected")
        cat_slug = cat_obj.slug.lower()
        if "restaurant" in cat_slug or "cafe" in cat_slug or cat_slug == "fast-food-kitchen":
            raise HTTPException(status_code=400, detail="Pickers cannot add products to restaurant/cafe categories")

    if not category_id:
        raise HTTPException(status_code=400, detail="No valid grocery category found")

    barcode = (payload.get("barcode") or "").strip() or None
    if barcode:
        dup_stmt = select(Product).where(Product.barcode == barcode)
        dup_res = await db.execute(dup_stmt)
        existing = dup_res.scalars().first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A product with barcode '{barcode}' already exists: '{existing.name}' (Stock: {existing.stock})"
            )

    stock = int(payload.get("stock", 10))
    min_stock = int(payload.get("minStock", 5))
    unit = (payload.get("unit") or "1 pc").strip()
    location = (payload.get("location") or "").strip() or None
    image_url = payload.get("imageUrl") or None
    description = payload.get("description") or None

    parsed_expiry = None
    if payload.get("expiryDate"):
        try:
            parsed_expiry = datetime.fromisoformat(str(payload["expiryDate"]).replace("Z", "+00:00"))
        except Exception:
            pass

    tags = list(payload.get("tags") or [])
    if "grocery" not in tags:
        tags.append("grocery")
    if "darkstore" not in tags:
        tags.append("darkstore")

    discount = round(((mrp - price) / mrp) * 100) if mrp > price else 0

    base_slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-') or f"item-{int(datetime.utcnow().timestamp())}"
    slug_count_stmt = select(func.count()).select_from(Product).where(Product.slug.startswith(base_slug))
    slug_count_res = await db.execute(slug_count_stmt)
    slug_count = slug_count_res.scalar() or 0
    final_slug = f"{base_slug}-{slug_count + 1}-{str(int(datetime.utcnow().timestamp()))[-4:]}" if slug_count > 0 else base_slug

    max_rid_stmt = select(func.max(Product.readableId))
    max_rid_res = await db.execute(max_rid_stmt)
    max_rid = max_rid_res.scalar()
    next_readable_id = (max_rid + 1) if max_rid else 200001

    new_prod_id = f"cm{uuid.uuid4().hex[:23]}"

    product = Product(
        id=new_prod_id,
        name=name,
        slug=final_slug,
        readableId=next_readable_id,
        categoryId=category_id,
        restaurantId=None,
        mrp=mrp,
        price=price,
        discount=discount,
        unit=unit,
        stock=stock,
        minStock=min_stock,
        location=location,
        barcode=barcode,
        imageUrl=image_url,
        description=description,
        expiryDate=parsed_expiry,
        tags=tags,
        isAvailable=stock > 0
    )
    db.add(product)
    await db.flush()

    # Seed store_inventories for local hub (Ghatampur hub-209206 or payload storeId)
    target_store_id = payload.get("storeId") or user.get("assignedStoreId") or "hub-209206"
    try:
        await db.execute(text("""
            INSERT INTO store_inventories ("productId", "storeId", stock, "isAvailable", "minStockAlert", "aisleLocation", "updatedAt")
            VALUES (:pid, :sid, :stock, :avail, :min_stock, :location, NOW())
            ON CONFLICT ("productId", "storeId") DO UPDATE
            SET stock = EXCLUDED.stock, "isAvailable" = EXCLUDED."isAvailable", "updatedAt" = NOW()
        """), {
            "pid": product.id,
            "sid": target_store_id,
            "stock": stock,
            "avail": stock > 0,
            "min_stock": min_stock,
            "location": location
        })
    except Exception as e:
        logger.warning(f"Could not seed store_inventory for {product.id}: {e}")

    await db.commit()

    # Reload with category relation
    stmt = select(Product).options(selectinload(Product.category)).where(Product.id == product.id)
    res = await db.execute(stmt)
    full_prod = res.scalars().first()

    return {"product": format_picker_product(full_prod), "success": True}


@picker_router.patch("/products")
async def update_picker_product(
    payload: Dict[str, Any] = Body(...),
    user: dict = Depends(get_current_picker_or_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Update pricing, stock, unit, location, and variants for dark store grocery items.
    Strictly grocery domain (restaurantId must be None).
    Updates both Product master record and store_inventories for localized hub.
    """
    target_id = payload.get("id") or payload.get("productId")
    barcode = (payload.get("barcode") or "").strip()

    if not target_id and not barcode:
        raise HTTPException(status_code=400, detail="Product ID or Barcode is required")

    stmt = select(Product).options(selectinload(Product.category))
    if target_id:
        stmt = stmt.where(Product.id == target_id)
    else:
        stmt = stmt.where(Product.barcode == barcode)

    res = await db.execute(stmt)
    product = res.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    if product.restaurantId is not None:
        raise HTTPException(
            status_code=403,
            detail="Pickers are strictly restricted to dark store / grocery products. Restaurant items cannot be edited by pickers."
        )

    # Variant processing
    variants = payload.get("variants")
    sorted_variants = None
    if variants and isinstance(variants, list) and len(variants) > 0:
        for v in variants:
            v_name = (v.get("name") or "").strip()
            if not v_name:
                raise HTTPException(status_code=400, detail="All variants must have a name (e.g. 500g, 1kg)")
            try:
                v_price = float(v.get("price", 0))
                v_mrp = float(v.get("mrp") or v_price)
            except (ValueError, TypeError):
                raise HTTPException(status_code=400, detail=f"Variant '{v_name}' has invalid price or MRP")
            if v_price <= 0:
                raise HTTPException(status_code=400, detail=f"Variant '{v_name}' must have a price greater than 0")
            if v_price > v_mrp:
                raise HTTPException(status_code=400, detail=f"Variant '{v_name}' price (₹{v_price}) cannot exceed MRP (₹{v_mrp})")

        sorted_variants = sorted(
            [
                {
                    "name": (v.get("name") or "").strip(),
                    "price": float(v.get("price")),
                    "mrp": float(v.get("mrp") or v.get("price")),
                    "stock": int(v.get("stock", 20) or 0),
                    "unit": str(v.get("unit") or "").strip() or None,
                }
                for v in variants
            ],
            key=lambda x: x["price"]
        )
        product.variants = sorted_variants
    elif variants is not None and isinstance(variants, list) and len(variants) == 0:
        product.variants = []

    # MRP & Price validation
    current_mrp = float(product.mrp if product.mrp is not None else product.price)
    current_price = float(product.price)

    if payload.get("mrp") is not None:
        try:
            mrp_val = float(payload["mrp"])
            if mrp_val <= 0:
                raise HTTPException(status_code=400, detail="MRP must be greater than 0")
            current_mrp = mrp_val
            product.mrp = mrp_val
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="MRP must be a valid number")
    elif sorted_variants and len(sorted_variants) > 0:
        current_mrp = sorted_variants[0]["mrp"]
        product.mrp = current_mrp

    if payload.get("price") is not None:
        try:
            price_val = float(payload["price"])
            if price_val <= 0:
                raise HTTPException(status_code=400, detail="Selling price must be greater than 0")
            current_price = price_val
            product.price = price_val
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Price must be a valid number")
    elif sorted_variants and len(sorted_variants) > 0:
        current_price = sorted_variants[0]["price"]
        product.price = current_price

    if current_price > current_mrp:
        raise HTTPException(
            status_code=400,
            detail=f"Selling price (₹{current_price}) cannot exceed MRP (₹{current_mrp})"
        )

    product.discount = round(((current_mrp - current_price) / current_mrp) * 100) if current_mrp > current_price else 0

    # Stock & Availability
    if payload.get("stock") is not None:
        try:
            stock_val = int(payload["stock"])
            if stock_val >= 0:
                product.stock = stock_val
                if payload.get("isAvailable") is None:
                    product.isAvailable = stock_val > 0
        except (ValueError, TypeError):
            pass

    if payload.get("isAvailable") is not None:
        product.isAvailable = bool(payload["isAvailable"])

    if payload.get("unit") and str(payload["unit"]).strip():
        product.unit = str(payload["unit"]).strip()

    if payload.get("location") is not None:
        product.location = str(payload["location"]).strip() or None

    # Sync to store_inventories for local hub (Ghatampur hub-209206 or payload storeId)
    target_store_id = payload.get("storeId") or user.get("assignedStoreId") or "hub-209206"
    try:
        await db.execute(text("""
            INSERT INTO store_inventories ("productId", "storeId", stock, "isAvailable", "priceOverride", "aisleLocation", "updatedAt")
            VALUES (:pid, :sid, :stock, :avail, :price, :location, NOW())
            ON CONFLICT ("productId", "storeId") DO UPDATE
            SET stock = EXCLUDED.stock,
                "isAvailable" = EXCLUDED."isAvailable",
                "priceOverride" = EXCLUDED."priceOverride",
                "aisleLocation" = EXCLUDED."aisleLocation",
                "updatedAt" = NOW()
        """), {
            "pid": product.id,
            "sid": target_store_id,
            "stock": product.stock,
            "avail": product.isAvailable,
            "price": product.price,
            "location": product.location
        })
    except Exception as e:
        logger.warning(f"Could not update store_inventory for {product.id}: {e}")

    product.updatedAt = datetime.utcnow()
    await db.commit()
    await db.refresh(product)

    return {
        "success": True,
        "product": format_picker_product(product),
        "message": f"Updated pricing for {product.name}: ₹{product.price} (MRP: ₹{product.mrp}, {product.discount}% OFF)"
    }


# ─── PICKER ORDERS QUEUE ───────────────────────────────────────────────────────

@picker_router.get("/orders")
async def get_picker_orders(
    request: Request,
    type: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_picker_or_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get list of active PENDING/CONFIRMED/PACKED orders to pick or cook (returns flat array matching Next.js).
    Scoped to assigned dark store hub / restaurant.
    """
    require_picker_or_chef(current_user)
    user_role = current_user.get("role")
    assigned_restaurant_id = current_user.get("assignedRestaurantId")
    assigned_store_id = current_user.get("assignedStoreId")
    effective_store_id = storeId or assigned_store_id

    # Staff checks
    if user_role in ["CHEF", "RESTAURANT_OWNER"]:
        email_str = current_user.get("email", "").lower()
        is_restaurant_chef = email_str.startswith("restaurant") or user_role == "RESTAURANT_OWNER"
        if is_restaurant_chef and type != "restaurant":
            raise HTTPException(status_code=401, detail="Unauthorized")
        if not is_restaurant_chef and type != "cafe":
            raise HTTPException(status_code=401, detail="Unauthorized")

    if user_role == "PICKER" and type in ["cafe", "restaurant"]:
        raise HTTPException(status_code=401, detail="Unauthorized")

    # Build filters: Include PENDING, CONFIRMED, and PACKED orders
    filters = [Order.status.in_([OrderStatus.PENDING, OrderStatus.CONFIRMED, OrderStatus.PACKED])]

    if effective_store_id and effective_store_id != "all":
        filters.append(or_(Order.storeId == effective_store_id, Order.storeId.is_(None)))

    if type == "cafe":
        if assigned_restaurant_id:
            filters.append(Order.restaurantId == assigned_restaurant_id)
        else:
            filters.append(or_(Order.restaurantId != None, Order.orderType == OrderType.RESTAURANT))
    elif type == "restaurant":
        if assigned_restaurant_id:
            filters.append(Order.restaurantId == assigned_restaurant_id)
        else:
            filters.append(or_(Order.restaurantId != None, Order.orderType == OrderType.RESTAURANT))
    else:
        filters.append(Order.restaurantId == None)
        filters.append(or_(Order.orderType == OrderType.GROCERY, Order.orderType == None))

    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.address),
        selectinload(Order.user)
    ).where(*filters).order_by(Order.createdAt.asc())

    res = await db.execute(stmt)
    orders = res.scalars().all()

    if not orders:
        return []

    # Get companion orders sharing combinedId
    combined_ids = list(set([o.combinedId for o in orders if o.combinedId]))
    companion_orders = []
    if combined_ids:
        comp_stmt = select(Order).options(selectinload(Order.items)).where(Order.combinedId.in_(combined_ids))
        comp_res = await db.execute(comp_stmt)
        companion_orders = comp_res.scalars().all()

    # Hydrate active worker names
    picker_ids = [o.assignedPickerId for o in orders if o.assignedPickerId]
    chef_ids = [o.assignedChefId for o in orders if o.assignedChefId]
    worker_ids = list(set(picker_ids + chef_ids))
    
    workers = {}
    if worker_ids:
        w_stmt = select(User.id, User.name, User.phone, User.role, User.email).where(User.id.in_(worker_ids))
        w_res = await db.execute(w_stmt)
        for w in w_res.all():
            workers[w.id] = {"name": w.name or "Staff", "phone": w.phone, "role": str(w.role), "email": w.email}

    # Fetch restaurants
    restaurant_ids = list(set([o.restaurantId for o in orders if o.restaurantId]))
    restaurants = {}
    if restaurant_ids:
        r_stmt = select(Restaurant).where(Restaurant.id.in_(restaurant_ids))
        r_res = await db.execute(r_stmt)
        for r in r_res.scalars().all():
            restaurants[r.id] = r

    result = []
    for o in orders:
        order_items = []
        for i in o.items:
            # Query product details to populate relations
            p_stmt = select(Product).options(selectinload(Product.category)).where(Product.id == i.productId)
            p_res = await db.execute(p_stmt)
            p_obj = p_res.scalars().first()
            
            p_unit = (p_obj.unit or "").strip() if p_obj and p_obj.unit else None
            effective_variant = i.selectedVariant or p_unit

            order_items.append({
                "id": i.id,
                "productId": i.productId,
                "name": i.name,
                "price": float(i.price),
                "quantity": i.quantity,
                "imageUrl": i.imageUrl,
                "selectedVariant": effective_variant,
                "unit": p_unit or effective_variant,
                "notes": i.notes,
                "product": {
                    "id": p_obj.id,
                    "name": p_obj.name,
                    "imageUrl": p_obj.imageUrl,
                    "unit": p_unit,
                    "variants": p_obj.variants,
                    "category": {
                        "id": p_obj.category.id,
                        "name": p_obj.category.name,
                        "slug": p_obj.category.slug
                    } if p_obj and p_obj.category else None
                } if p_obj else None
            })

        assigned_picker = workers.get(o.assignedPickerId)
        if assigned_picker:
            picker_phone = str(assigned_picker.get("phone") or "")
            picker_email = str(assigned_picker.get("email") or "").lower()
            picker_role = str(assigned_picker.get("role") or "").upper()
            if "7054470303" in picker_phone or "9170942500" in picker_phone or "admin" in picker_role or picker_email.startswith("admin") or picker_email.startswith("superadmin"):
                assigned_picker = None
        assigned_chef = workers.get(o.assignedChefId)
        rest_obj = restaurants.get(o.restaurantId)

        # Companion order formatting
        companion_data = None
        if o.combinedId:
            matching = next((c for c in companion_orders if c.combinedId == o.combinedId and c.id != o.id), None)
            if matching:
                companion_data = {
                    "id": matching.id,
                    "status": matching.status.value,
                    "shopName": matching.shopName,
                    "items": [{"id": i.id, "name": i.name, "quantity": i.quantity} for i in matching.items]
                }

        result.append({
            "id": o.id,
            "readableId": o.readableId,
            "userId": o.userId,
            "addressId": o.addressId,
            "status": o.status.value,
            "subtotal": float(o.subtotal),
            "discount": float(o.discount),
            "deliveryFee": float(o.deliveryFee),
            "taxes": float(o.taxes),
            "miscFee": float(o.miscFee),
            "total": float(o.total),
            "paymentMethod": o.paymentMethod.value,
            "paymentStatus": o.paymentStatus.value,
            "estimatedDelivery": o.estimatedDelivery.isoformat() if o.estimatedDelivery else None,
            "createdAt": o.createdAt.isoformat() if o.createdAt else None,
            "deliveryMethod": o.deliveryMethod,
            "shopName": o.shopName,
            "notes": o.notes,
            "restaurantId": o.restaurantId,
            "items": order_items,
            "user": {"name": o.user.name, "phone": o.user.phone, "email": o.user.email} if o.user else None,
            "assignedPicker": assigned_picker,
            "assignedChef": assigned_chef,
            "address": {
                "houseNo": o.address.houseNo if o.address else "",
                "street": o.address.street if o.address else "",
                "area": o.address.area if o.address else "",
                "city": o.address.city if o.address else "",
                "pincode": o.address.pincode if o.address else "",
                "phone": o.address.phone if o.address else None,
            } if o.address else None,
            "restaurant": {
                "id": rest_obj.id,
                "name": rest_obj.name,
                "address": rest_obj.address,
                "logoUrl": rest_obj.logoUrl,
                "ownerPhone": rest_obj.ownerPhone
            } if rest_obj else None,
            "restaurantName": rest_obj.name if rest_obj else o.shopName,
            "companionOrder": companion_data
        })

    return result