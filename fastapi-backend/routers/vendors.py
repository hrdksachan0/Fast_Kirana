from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, desc, or_, text
from sqlalchemy.orm import selectinload
from typing import List, Dict, Any, Optional
from datetime import datetime, date
import uuid

from database import get_db
from models import Vendor, VendorPayout, Product, Order, OrderItem, Category, StoreInventory, OrderStatus
from routers.auth import require_auth

from pydantic import BaseModel
import re
from utils.jwt import create_access_token

vendors_router = APIRouter(prefix="/vendors", tags=["Vendor Operations & Ledger"])


def require_admin(current_user: dict) -> dict:
    role = current_user.get("role")
    if role not in ["ADMIN", "RESTAURANT_OWNER"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


def check_vendor_or_admin_access(current_user: dict, vendor_id: str) -> dict:
    role = current_user.get("role")
    if role in ["ADMIN", "RESTAURANT_OWNER"]:
        return current_user
    if role == "VENDOR" and (current_user.get("vendorId") == vendor_id or current_user.get("id") == vendor_id):
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Access denied. Only authorized admin or this specific vendor can access this dashboard."
    )


class VendorLoginRequest(BaseModel):
    phone: Optional[str] = None
    vendorCode: Optional[str] = None
    email: Optional[str] = None


@vendors_router.post("/login")
async def vendor_login(
    body: VendorLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Dedicated Vendor Partner Login via registered Phone Number, Vendor Code, or Email.
    Returns JWT with role='VENDOR' and vendorId.
    """
    ident = (body.phone or body.vendorCode or body.email or "").strip()
    if not ident:
        raise HTTPException(status_code=400, detail="Please enter your registered phone number or vendor code")

    clean_digits = re.sub(r"\D", "", ident)
    vendor = None

    if len(clean_digits) >= 10:
        last10 = clean_digits[-10:]
        phone_patterns = [last10, f"+91{last10}", f"91{last10}"]
        stmt = select(Vendor).where(
            and_(
                Vendor.isActive.is_(True),
                or_(
                    Vendor.phone.in_(phone_patterns),
                    Vendor.vendorCode.ilike(ident),
                    Vendor.email.ilike(ident)
                )
            )
        )
        res = await db.execute(stmt)
        vendor = res.scalars().first()
    else:
        # Match vendorCode or name or email
        stmt = select(Vendor).where(
            and_(
                Vendor.isActive.is_(True),
                or_(
                    Vendor.vendorCode.ilike(ident),
                    Vendor.email.ilike(ident),
                    Vendor.name.ilike(ident)
                )
            )
        )
        res = await db.execute(stmt)
        vendor = res.scalars().first()

    if not vendor:
        raise HTTPException(
            status_code=404,
            detail="Vendor account not found or inactive. Please contact FastKirana Store Admin."
        )

    token = create_access_token({
        "id": vendor.id,
        "vendorId": vendor.id,
        "role": "VENDOR",
        "name": vendor.name,
        "phone": vendor.phone,
        "email": vendor.email,
    })

    return {
        "success": True,
        "token": token,
        "role": "VENDOR",
        "vendor": {
            "id": vendor.id,
            "name": vendor.name,
            "companyName": vendor.companyName or vendor.name,
            "phone": vendor.phone or "",
            "email": vendor.email or "",
            "vendorCode": vendor.vendorCode or "",
            "address": vendor.address or "",
            "upiId": vendor.upiId or "",
        }
    }


@vendors_router.get("")
async def get_vendors(
    storeId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get list of vendors with attached products and payouts count.
    """
    require_admin(current_user)

    filters = []
    if storeId and storeId != "all":
        filters.append(or_(Vendor.storeId == storeId, Vendor.storeId.is_(None)))

    stmt = select(Vendor).where(*filters).order_by(Vendor.name.asc())
    res = await db.execute(stmt)
    vendors_list = res.scalars().all()

    # Preload product counts & payout counts
    result = []
    for v in vendors_list:
        # Count attached products
        p_count_stmt = select(func.count(Product.id)).where(
            or_(
                Product.vendorId == v.id,
                func.lower(Product.vendor) == v.name.lower().strip()
            )
        )
        p_count_res = await db.execute(p_count_stmt)
        prod_count = p_count_res.scalar() or 0

        # Count payouts
        pay_count_stmt = select(func.count(VendorPayout.id)).where(VendorPayout.vendorId == v.id)
        pay_count_res = await db.execute(pay_count_stmt)
        pay_count = pay_count_res.scalar() or 0

        result.append({
            "id": v.id,
            "vendorCode": v.vendorCode or f"VND-{v.id[-4:].upper()}",
            "name": v.name,
            "phone": v.phone or "",
            "email": v.email or "",
            "companyName": v.companyName or "",
            "gstin": v.gstin or "",
            "upiId": v.upiId or "",
            "bankName": v.bankName or "",
            "accountNo": v.accountNo or "",
            "ifscCode": v.ifscCode or "",
            "address": v.address or "",
            "isActive": v.isActive,
            "storeId": v.storeId,
            "productCount": prod_count,
            "payoutCount": pay_count,
            "createdAt": v.createdAt.isoformat() if v.createdAt else None,
            "updatedAt": v.updatedAt.isoformat() if v.updatedAt else None,
        })

    return {
        "success": True,
        "vendors": result,
    }


@vendors_router.get("/{vendor_id}")
async def get_vendor_details(
    vendor_id: str,
    startDate: Optional[str] = Query(None),
    endDate: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get full vendor dashboard: financial KPIs, attached products catalog,
    itemized delivered sales at cost price, payouts ledger, and low-stock alerts.
    """
    check_vendor_or_admin_access(current_user, vendor_id)

    # 1. Fetch vendor
    v_stmt = select(Vendor).options(selectinload(Vendor.payouts)).where(Vendor.id == vendor_id)
    v_res = await db.execute(v_stmt)
    vendor = v_res.scalars().first()

    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")

    # Resolve date range
    now = datetime.utcnow()
    default_start = datetime(now.year, now.month, 1)
    if now.month == 12:
        default_end = datetime(now.year + 1, 1, 1)
    else:
        default_end = datetime(now.year, now.month + 1, 1)

    start_dt = datetime.fromisoformat(f"{startDate}T00:00:00") if startDate else default_start
    end_dt = datetime.fromisoformat(f"{endDate}T23:59:59") if endDate else default_end

    # 2. Fetch all attached products
    p_filters = [
        or_(
            Product.vendorId == vendor.id,
            func.lower(Product.vendor) == vendor.name.lower().strip()
        )
    ]
    p_stmt = select(Product).options(selectinload(Product.category)).where(*p_filters).order_by(Product.name.asc())
    p_res = await db.execute(p_stmt)
    attached_products = p_res.scalars().all()
    product_ids = [p.id for p in attached_products]
    product_map = {p.id: p for p in attached_products}

    # 3. Fetch Delivered Orders in period
    order_filters = [
        Order.status == OrderStatus.DELIVERED,
        Order.createdAt >= start_dt,
        Order.createdAt <= end_dt,
    ]
    if storeId and storeId != "all":
        order_filters.append(Order.storeId == storeId)

    item_sales_summary: Dict[str, Dict[str, Any]] = {}
    for p in attached_products:
        item_sales_summary[p.id] = {
            "productId": p.id,
            "name": p.name,
            "unit": p.unit or "",
            "categoryName": p.category.name if p.category else "General",
            "barcode": p.barcode or "",
            "unitsSold": 0,
            "unitCostPrice": float(p.costPrice or 0.0),
            "sellingPrice": float(p.price),
            "totalPayable": 0.0,
            "currentStock": p.stock,
            "imageUrl": p.imageUrl or "",
        }

    total_units_sold = 0
    total_payable_amount = 0.0

    if product_ids:
        # Query order items belonging to these products
        oi_stmt = (
            select(OrderItem)
            .join(Order, OrderItem.orderId == Order.id)
            .where(
                and_(
                    OrderItem.productId.in_(product_ids),
                    *order_filters
                )
            )
        )
        oi_res = await db.execute(oi_stmt)
        delivered_items = oi_res.scalars().all()

        for oi in delivered_items:
            if oi.isRefunded or not oi.productId:
                continue

            base_prod = product_map.get(oi.productId)
            effective_cost = float(oi.costPrice) if oi.costPrice and oi.costPrice > 0 else float(base_prod.costPrice if base_prod else 0.0)
            qty = int(oi.quantity or 0)
            item_payable = qty * effective_cost

            total_units_sold += qty
            total_payable_amount += item_payable

            if oi.productId in item_sales_summary:
                item_sales_summary[oi.productId]["unitsSold"] += qty
                item_sales_summary[oi.productId]["totalPayable"] += item_payable
                if effective_cost > 0:
                    item_sales_summary[oi.productId]["unitCostPrice"] = effective_cost

    itemized_sales = sorted(
        item_sales_summary.values(),
        key=lambda x: (x["unitsSold"] > 0, x["totalPayable"], x["unitsSold"]),
        reverse=True
    )

    # 4. Payouts & Balances
    payouts_list = vendor.payouts or []
    total_paid_lifetime = sum(float(p.amount) for p in payouts_list if p.status == "PAID")

    period_payouts = [
        p for p in payouts_list
        if p.createdAt and p.createdAt >= start_dt and p.createdAt <= end_dt
    ]
    total_paid_in_period = sum(float(p.amount) for p in period_payouts if p.status == "PAID")
    pending_balance = max(0.0, total_payable_amount - total_paid_in_period)

    # 5. Low stock alerts for PO
    low_stock_items = []
    for p in attached_products:
        min_stock = p.minStock or 5
        if p.stock <= min_stock:
            low_stock_items.append({
                "id": p.id,
                "name": p.name,
                "unit": p.unit or "",
                "barcode": p.barcode or "",
                "stock": p.stock,
                "minStock": min_stock,
                "costPrice": float(p.costPrice or 0.0),
                "isLow": True,
                "imageUrl": p.imageUrl or "",
            })

    return {
        "success": True,
        "vendor": {
            "id": vendor.id,
            "vendorCode": vendor.vendorCode or f"VND-{vendor.id[-4:].upper()}",
            "name": vendor.name,
            "phone": vendor.phone or "",
            "email": vendor.email or "",
            "companyName": vendor.companyName or "",
            "gstin": vendor.gstin or "",
            "upiId": vendor.upiId or "",
            "bankName": vendor.bankName or "",
            "accountNo": vendor.accountNo or "",
            "ifscCode": vendor.ifscCode or "",
            "address": vendor.address or "",
            "isActive": vendor.isActive,
            "storeId": vendor.storeId,
        },
        "period": {
            "startDate": start_dt.strftime("%Y-%m-%d"),
            "endDate": end_dt.strftime("%Y-%m-%d"),
        },
        "kpis": {
            "totalProducts": len(attached_products),
            "totalUnitsSold": total_units_sold,
            "totalPayableAmount": round(total_payable_amount, 2),
            "totalPaidInPeriod": round(total_paid_in_period, 2),
            "pendingBalance": round(pending_balance, 2),
            "totalPaidLifetime": round(total_paid_lifetime, 2),
            "lowStockCount": len(low_stock_items),
        },
        "products": [
            {
                "id": p.id,
                "name": p.name,
                "unit": p.unit or "",
                "barcode": p.barcode or "",
                "price": float(p.price),
                "mrp": float(p.mrp),
                "costPrice": float(p.costPrice or 0.0),
                "stock": p.stock,
                "category": p.category.name if p.category else "General",
                "imageUrl": p.imageUrl or "",
                "isAvailable": p.isAvailable,
            }
            for p in attached_products
        ],
        "itemizedSales": itemized_sales,
        "payouts": [
            {
                "id": p.id,
                "vendorId": p.vendorId,
                "amount": float(p.amount),
                "startDate": p.startDate.strftime("%Y-%m-%d") if p.startDate else None,
                "endDate": p.endDate.strftime("%Y-%m-%d") if p.endDate else None,
                "paymentMethod": p.paymentMethod or "UPI",
                "transactionId": p.transactionId or "",
                "paidAt": p.paidAt.isoformat() if p.paidAt else (p.createdAt.isoformat() if p.createdAt else None),
                "status": p.status or "PAID",
                "notes": p.notes or "",
            }
            for p in payouts_list
        ],
        "lowStockItems": low_stock_items,
    }


@vendors_router.post("/{vendor_id}/payouts")
async def record_vendor_payout(
    vendor_id: str,
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Record settlement payment made to a vendor (UPI, Bank, Cash, etc.)
    """
    require_admin(current_user)

    v_stmt = select(Vendor).where(Vendor.id == vendor_id)
    v_res = await db.execute(v_stmt)
    vendor = v_res.scalars().first()

    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")

    amount = float(payload.get("amount") or 0.0)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Payout amount must be greater than 0")

    payout = VendorPayout(
        id=str(uuid.uuid4()),
        vendorId=vendor_id,
        amount=amount,
        paymentMethod=str(payload.get("paymentMethod") or "UPI").upper(),
        transactionId=str(payload.get("transactionId") or "").strip() or None,
        notes=str(payload.get("notes") or "").strip() or None,
        status="PAID",
        paidAt=datetime.utcnow(),
        storeId=vendor.storeId,
    )

    db.add(payout)
    await db.commit()
    await db.refresh(payout)

    return {
        "success": True,
        "message": f"Recorded payout of ₹{amount} to {vendor.name}",
        "payoutId": payout.id,
    }


@vendors_router.post("")
async def create_or_update_vendor(
    payload: Dict[str, Any] = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new vendor or update existing vendor profile.
    """
    require_admin(current_user)

    vendor_id = payload.get("id")
    name = str(payload.get("name") or "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Vendor name is required")

    if vendor_id:
        v_stmt = select(Vendor).where(Vendor.id == vendor_id)
        v_res = await db.execute(v_stmt)
        vendor = v_res.scalars().first()
        if not vendor:
            raise HTTPException(status_code=404, detail="Vendor not found")
    else:
        vendor = Vendor(id=str(uuid.uuid4()), name=name)
        db.add(vendor)

    vendor.name = name
    vendor.phone = str(payload.get("phone") or "").strip() or None
    vendor.email = str(payload.get("email") or "").strip() or None
    vendor.companyName = str(payload.get("companyName") or "").strip() or None
    vendor.gstin = str(payload.get("gstin") or "").strip() or None
    vendor.upiId = str(payload.get("upiId") or "").strip() or None
    vendor.bankName = str(payload.get("bankName") or "").strip() or None
    vendor.accountNo = str(payload.get("accountNo") or "").strip() or None
    vendor.ifscCode = str(payload.get("ifscCode") or "").strip() or None
    vendor.address = str(payload.get("address") or "").strip() or None
    if "isActive" in payload:
        vendor.isActive = bool(payload.get("isActive"))
    if "storeId" in payload:
        vendor.storeId = str(payload.get("storeId") or "").strip() or None

    await db.commit()
    await db.refresh(vendor)

    return {
        "success": True,
        "vendorId": vendor.id,
        "message": f"Vendor '{vendor.name}' saved successfully",
    }


class UpdateVendorProductPricesRequest(BaseModel):
    costPrice: Optional[float] = None
    price: Optional[float] = None
    mrp: Optional[float] = None
    stock: Optional[int] = None


@vendors_router.patch("/products/{product_id}/prices")
async def update_vendor_product_prices(
    product_id: str,
    body: UpdateVendorProductPricesRequest,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Update cost price, selling price, MRP, and stock for an attached product.
    Authorized for Admins or the attached Vendor themselves.
    """
    p_stmt = select(Product).where(Product.id == product_id)
    p_res = await db.execute(p_stmt)
    product = p_res.scalars().first()

    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    role = current_user.get("role")
    user_vendor_id = current_user.get("vendorId") or current_user.get("id")

    # If role is VENDOR, verify they own this product
    if role == "VENDOR":
        vendor_owns = False
        if product.vendorId and product.vendorId == user_vendor_id:
            vendor_owns = True
        elif product.vendor and current_user.get("name") and product.vendor.lower().strip() == current_user.get("name").lower().strip():
            vendor_owns = True

        if not vendor_owns:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to modify another vendor's product."
            )
    elif role not in ["ADMIN", "RESTAURANT_OWNER"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied. Admin or Vendor role required."
        )

    # Apply updates
    if body.costPrice is not None:
        product.costPrice = max(0.0, float(body.costPrice))
    if body.price is not None:
        product.price = max(0.0, float(body.price))
    if body.mrp is not None:
        product.mrp = max(0.0, float(body.mrp))
    if body.stock is not None:
        product.stock = max(0, int(body.stock))

    # Recalculate discount if MRP > price
    if product.mrp > 0 and product.price <= product.mrp:
        product.discount = round(((product.mrp - product.price) / product.mrp) * 100, 1)

    product.updatedAt = datetime.utcnow()
    await db.commit()
    await db.refresh(product)

    profit = product.price - product.costPrice
    margin_pct = round((profit / product.price) * 100, 1) if product.price > 0 else 0.0

    return {
        "success": True,
        "message": f"Updated prices for '{product.name}'",
        "product": {
            "id": product.id,
            "name": product.name,
            "costPrice": product.costPrice,
            "price": product.price,
            "mrp": product.mrp,
            "stock": product.stock,
            "profit": profit,
            "marginPercent": margin_pct,
            "updatedAt": product.updatedAt.isoformat(),
        }
    }


@vendors_router.get("/{vendor_id}/live-orders")
async def get_vendor_live_orders(
    vendor_id: str,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get live incoming orders that contain products connected to this vendor.
    Like restaurants get kitchen orders!
    """
    check_vendor_or_admin_access(current_user, vendor_id)

    # 1. Fetch vendor to know their ID & Name
    v_stmt = select(Vendor).where(Vendor.id == vendor_id)
    v_res = await db.execute(v_stmt)
    vendor = v_res.scalars().first()
    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")

    # 2. Find active orders in last 48 hours
    cutoff = datetime.utcnow() - timedelta(hours=48)
    o_stmt = select(Order).options(
        selectinload(Order.items).selectinload(OrderItem.product)
    ).where(
        and_(
            Order.createdAt >= cutoff,
            Order.status.in_([
                OrderStatus.CONFIRMED,
                OrderStatus.PENDING,
                OrderStatus.PACKED,
                OrderStatus.SHIPPED,
                OrderStatus.ADMIN_PENDING,
                OrderStatus.DELIVERED,
            ])
        )
    ).order_by(desc(Order.createdAt))

    o_res = await db.execute(o_stmt)
    all_orders = o_res.scalars().all()

    vendor_name_clean = vendor.name.lower().strip() if vendor.name else ""

    live_orders = []
    for ord in all_orders:
        matched_items = []
        for it in ord.items:
            prod = it.product
            if not prod:
                continue
            is_match = False
            if prod.vendorId and prod.vendorId == vendor_id:
                is_match = True
            elif prod.vendor and prod.vendor.lower().strip() == vendor_name_clean:
                is_match = True

            if is_match:
                cost = float(prod.costPrice or prod.price or 0.0)
                matched_items.append({
                    "id": it.id,
                    "productId": prod.id,
                    "name": prod.name,
                    "quantity": it.quantity,
                    "cost": cost,
                    "totalCost": cost * it.quantity,
                    "unit": prod.unit or "",
                    "imageUrl": prod.imageUrl or "",
                    "variant": it.selectedVariant or "",
                })

        if matched_items:
            total_val = sum(i["totalCost"] for i in matched_items)
            live_orders.append({
                "orderId": ord.id,
                "readableId": ord.readableId or ord.id[-6:],
                "status": ord.status.value,
                "createdAt": ord.createdAt.isoformat() if ord.createdAt else "",
                "totalVendorValue": total_val,
                "itemCount": len(matched_items),
                "items": matched_items,
                "isDelivered": ord.status == OrderStatus.DELIVERED,
            })

    return {
        "success": True,
        "vendorId": vendor_id,
        "count": len(live_orders),
        "orders": live_orders,
    }


@vendors_router.post("/payout")
async def create_vendor_payout(
    payload: dict = Body(...),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Record vendor settlement/payout by Admin.
    """
    role = current_user.get("role")
    if role not in ["ADMIN", "RESTAURANT_OWNER"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")

    vendor_id = payload.get("vendorId")
    amount = float(payload.get("amount") or 0.0)
    if not vendor_id:
        raise HTTPException(status_code=400, detail="Vendor ID is required")
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Valid payment amount is required")

    v_stmt = select(Vendor).where(Vendor.id == vendor_id)
    v_res = await db.execute(v_stmt)
    vendor = v_res.scalars().first()
    if not vendor:
        raise HTTPException(status_code=404, detail="Vendor not found")

    payout = VendorPayout(
        id=f"vp_{uuid.uuid4().hex[:16]}",
        vendorId=vendor_id,
        amount=amount,
        startDate=datetime.fromisoformat(payload["startDate"]) if payload.get("startDate") else datetime.utcnow(),
        endDate=datetime.fromisoformat(payload["endDate"]) if payload.get("endDate") else datetime.utcnow(),
        paymentMethod=str(payload.get("paymentMethod", "UPI")).upper(),
        transactionId=payload.get("transactionId"),
        notes=payload.get("notes"),
        paidAt=datetime.utcnow(),
        status="PAID",
        storeId=payload.get("storeId"),
    )
    db.add(payout)
    await db.commit()
    await db.refresh(payout)

    return {
        "success": True,
        "payout": {
            "id": payout.id,
            "vendorId": payout.vendorId,
            "amount": payout.amount,
            "status": payout.status,
            "paymentMethod": payout.paymentMethod,
            "transactionId": payout.transactionId,
            "paidAt": payout.paidAt.isoformat() if payout.paidAt else None,
        }
    }
