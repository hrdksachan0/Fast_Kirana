from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import func, and_, or_, desc, text, update, delete, case
from datetime import datetime, date, time, timedelta
import uuid
import re
import json
import math
from typing import List, Dict, Any, Optional

from database import get_db
from models import (
    User, Order, RiderWallet, CashDepositTransaction, Role, 
    OrderStatus, PaymentMethod, PaymentStatus, StoreSetting, 
    Product, Category, OrderItem, Restaurant, DarkStore, Address
)
from schemas import CashDepositRequest, FinancialSummaryOut
from routers.auth import require_admin
from routers.websockets import manager
from routers.stores_service import clear_stores_cache
import logging

logger = logging.getLogger(__name__)

def _get_admin_attr(admin_obj: Any, attr: str, default: Any = None) -> Any:
    if isinstance(admin_obj, dict):
        return admin_obj.get(attr, default)
    return getattr(admin_obj, attr, default)

def to_iso_utc(dt: Any) -> Optional[str]:
    if not dt:
        return None
    iso = dt.isoformat()
    return iso if iso.endswith("Z") else f"{iso}Z"

router = APIRouter(prefix="/admin", tags=["Admin Reconciliation & Reports"])


@router.get("/rider-cash")
async def get_admin_rider_cash_summary(
    storeId: Optional[str] = Query(None),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Real-time financial reconciliation & rider cash balances
    """
    today_start = datetime.combine(date.today(), time.min)

    # 1. Fetch riders using standard SQLAlchemy enum filter scoped by store
    rider_stmt = select(User).options(selectinload(User.riderWallet)).where(
        User.role == Role.DELIVERY
    )
    effective_store = storeId or _get_admin_attr(current_admin, "assignedStoreId")
    if effective_store and effective_store.lower() != 'all':
        rider_stmt = rider_stmt.where(User.assignedStoreId == effective_store)

    rider_res = await db.execute(rider_stmt)
    riders = rider_res.scalars().all()

    # Ensure wallet exists for every rider
    rider_list = []
    pending_rider_cash = 0.0

    for r in riders:
        wallet = r.riderWallet
        if not wallet:
            wallet = RiderWallet(
                id=f"rw_{r.id}",
                userId=r.id,
                cashInHand=0.0,
                cashLimit=2000.0,
                totalCollected=0.0,
                totalDeposited=0.0
            )
            db.add(wallet)
            await db.commit()
            await db.refresh(wallet)

        pending_rider_cash += float(wallet.cashInHand)

        # Fetch today's COD stats for rider (M15 FIX: deliveredAt filtering)
        cod_stmt = select(func.count(Order.id), func.coalesce(func.sum(Order.total), 0.0)).where(
            and_(
                Order.deliveryUserId == r.id,
                Order.paymentMethod == PaymentMethod.COD,
                Order.status == OrderStatus.DELIVERED,
                func.coalesce(Order.deliveredAt, Order.createdAt) >= today_start
            )
        )
        cod_res = await db.execute(cod_stmt)
        today_cod_count, today_cod_total = cod_res.first() or (0, 0.0)

        # M16 FIX: Fetch today's Online/UPI stats for rider
        online_rider_stmt = select(func.count(Order.id), func.coalesce(func.sum(Order.total), 0.0)).where(
            and_(
                Order.deliveryUserId == r.id,
                Order.paymentMethod.in_([PaymentMethod.UPI, PaymentMethod.CARD, PaymentMethod.WALLET]),
                Order.status == OrderStatus.DELIVERED,
                func.coalesce(Order.deliveredAt, Order.createdAt) >= today_start
            )
        )
        online_rider_res = await db.execute(online_rider_stmt)
        today_online_count, today_online_total = online_rider_res.first() or (0, 0.0)

        # Fetch today's deposits
        dep_stmt = select(func.coalesce(func.sum(CashDepositTransaction.amount), 0.0)).where(
            and_(
                CashDepositTransaction.riderId == r.id,
                CashDepositTransaction.createdAt >= today_start
            )
        )
        dep_res = await db.execute(dep_stmt)
        today_dep_total = dep_res.scalar() or 0.0

        rider_list.append({
            "id": r.id,
            "name": r.name or "Rider",
            "email": r.email,
            "phone": r.phone or "",
            "image": r.image,
            "cashInHand": float(wallet.cashInHand),
            "cashLimit": float(wallet.cashLimit),
            "totalCollected": float(wallet.totalCollected),
            "totalDeposited": float(wallet.totalDeposited),
            "todayCodOrdersCount": today_cod_count,
            "todayCodTotal": float(today_cod_total),
            "todayOnlineOrdersCount": today_online_count,
            "todayOnlineTotal": float(today_online_total),
            "todayDepositedTotal": float(today_dep_total)
        })

    # 2. Overall Financial Summary Today
    online_stmt = select(func.coalesce(func.sum(Order.total), 0.0)).where(
        and_(
            Order.paymentMethod != PaymentMethod.COD,
            Order.paymentStatus == PaymentStatus.PAID,
            Order.createdAt >= today_start
        )
    )
    online_revenue = (await db.execute(online_stmt)).scalar() or 0.0

    delivered_cod_stmt = select(func.coalesce(func.sum(Order.total), 0.0)).where(
        and_(
            Order.paymentMethod == PaymentMethod.COD,
            Order.status == OrderStatus.DELIVERED,
            func.coalesce(Order.deliveredAt, Order.createdAt) >= today_start
        )
    )
    delivered_cod_today = (await db.execute(delivered_cod_stmt)).scalar() or 0.0

    counter_cash_stmt = select(func.coalesce(func.sum(Order.total), 0.0)).where(
        and_(
            Order.paymentMethod == PaymentMethod.COD,
            Order.status == OrderStatus.DELIVERED,
            Order.deliveryUserId.is_(None),
            func.coalesce(Order.deliveredAt, Order.createdAt) >= today_start
        )
    )
    counter_cash_today = (await db.execute(counter_cash_stmt)).scalar() or 0.0

    total_dep_stmt = select(func.coalesce(func.sum(CashDepositTransaction.amount), 0.0)).where(
        CashDepositTransaction.createdAt >= today_start
    )
    total_dep_today = (await db.execute(total_dep_stmt)).scalar() or 0.0

    # 3. Recent Deposit Logs
    recent_dep_stmt = select(CashDepositTransaction).order_by(desc(CashDepositTransaction.createdAt)).limit(20)
    recent_dep_res = await db.execute(recent_dep_stmt)
    recent_deps = recent_dep_res.scalars().all()

    return {
        "riders": rider_list,
        "summary": {
            "onlineRevenueToday": float(online_revenue),
            "deliveredCodToday": float(delivered_cod_today),
            "counterCashToday": float(counter_cash_today),
            "totalCashDepositedToday": float(total_dep_today),
            "pendingRiderCash": float(pending_rider_cash),
            "activeRidersCount": len(riders)
        },
        "recentDeposits": [
            {
                "id": d.id,
                "riderId": d.riderId,
                "amount": float(d.amount),
                "notes": d.notes,
                "createdAt": d.createdAt
            } for d in recent_deps
        ]
    }


@router.post("/rider-cash")
async def settle_rider_cash(
    payload: CashDepositRequest,
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    1-Click Cash Settlement: Reduces rider cash in hand and logs transaction
    """
    stmt = select(RiderWallet).where(RiderWallet.userId == payload.riderId)
    res = await db.execute(stmt)
    wallet = res.scalars().first()

    if not wallet:
        raise HTTPException(status_code=404, detail="Rider wallet not found")

    deposit_amount = payload.amount
    wallet.cashInHand = max(0.0, float(wallet.cashInHand) - deposit_amount)
    wallet.totalDeposited += deposit_amount

    transaction = CashDepositTransaction(
        id=f"tx_{uuid.uuid4().hex[:12]}",
        riderId=payload.riderId,
        adminId=_get_admin_attr(current_admin, "id"),
        amount=deposit_amount,
        status="APPROVED",
        notes=payload.notes
    )
    db.add(transaction)

    # H22 FIX: Mark delivered COD orders for this rider as settled to admin
    now = datetime.utcnow()
    settle_stmt = (
        update(Order)
        .where(
            Order.deliveryUserId == payload.riderId,
            Order.status == OrderStatus.DELIVERED,
            Order.paymentMethod == PaymentMethod.COD,
            Order.cashSettledToAdmin == False
        )
        .values(cashSettledToAdmin=True, cashSettledAt=now)
    )
    await db.execute(settle_stmt)

    await db.commit()
    await db.refresh(wallet)

    return {
        "success": True,
        "message": f"Successfully settled {deposit_amount:.2f} cash for rider!",
        "newCashInHand": float(wallet.cashInHand)
    }


@router.delete("/rider-cash")
async def delete_rider_cash_log(
    id: Optional[str] = Query(None),
    clearAll: Optional[bool] = Query(False),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a specific cash deposit log or clear all deposit logs."""
    try:
        if id:
            stmt = delete(CashDepositTransaction).where(CashDepositTransaction.id == id)
            await db.execute(stmt)
            await db.commit()
            return {"success": True, "message": "Cash deposit log deleted."}

        if clearAll:
            stmt = delete(CashDepositTransaction)
            res = await db.execute(stmt)
            await db.commit()
            return {"success": True, "message": "Cleared cash deposit logs."}

        raise HTTPException(status_code=400, detail="Missing id or clearAll parameter")
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))



@router.patch("/settings")
async def save_admin_settings(
    payload: Dict[str, Any] = Body(...),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Update administrative store configuration settings (run database writes only for changed keys).
    Supports storeId scoped overrides and synchronizes dark stores table and in-memory caches.
    """
    try:
        store_id = payload.pop("storeId", None)
        is_store_scoped = bool(store_id and store_id != "all")
        prefix = f"store:{store_id}:" if is_store_scoped else ""

        stmt = select(StoreSetting)
        res = await db.execute(stmt)
        current_settings = res.scalars().all()
        current_map = {s.key: s.value for s in current_settings}

        for key, val in payload.items():
            str_val = str(val)
            scoped_key = f"{prefix}{key}" if is_store_scoped else key
            
            stmt_key = select(StoreSetting).where(StoreSetting.key == scoped_key)
            res_key = await db.execute(stmt_key)
            existing = res_key.scalars().first()
            if existing:
                existing.value = str_val
            else:
                new_s = StoreSetting(id=f"ss_{uuid.uuid4().hex[:16]}", key=scoped_key, value=str_val)
                db.add(new_s)

            # If base Ghatampur hub, sync un-scoped legacy keys too
            if store_id == "hub-209206":
                base_stmt = select(StoreSetting).where(StoreSetting.key == key)
                base_res = await db.execute(base_stmt)
                base_existing = base_res.scalars().first()
                if base_existing:
                    base_existing.value = str_val
                else:
                    db.add(StoreSetting(id=f"ss_{uuid.uuid4().hex[:16]}", key=key, value=str_val))

        # Sync DarkStore table fields for this specific hub or default central hub
        target_hub_id = store_id if is_store_scoped else "hub-209206"
        hub_res = await db.execute(select(DarkStore).where(DarkStore.id == target_hub_id))
        hub_obj = hub_res.scalars().first()
        if hub_obj:
            if "grocery_mart_open" in payload:
                is_open = str(payload["grocery_mart_open"]).lower() == "true"
                hub_obj.groceryOpen = is_open
                if is_open:
                    hub_obj.closeReason = None
                    hub_obj.pauseUntil = None
                else:
                    hub_obj.closeReason = "MANUAL_OFF"
            if "delivery_radius" in payload:
                try:
                    hub_obj.deliveryRadiusKm = float(payload["delivery_radius"])
                except Exception:
                    pass
            if "store_lat" in payload and "store_lng" in payload:
                try:
                    hub_obj.latitude = float(payload["store_lat"])
                    hub_obj.longitude = float(payload["store_lng"])
                except Exception:
                    pass

        # M14 FIX: Sync active restaurants if restaurant timings updated
        r_open = payload.get("restaurant_open_time")
        r_close = payload.get("restaurant_close_time")
        if r_open or r_close:
            try:
                r_update = {}
                if r_open:
                    r_update["openTime"] = str(r_open)
                if r_close:
                    r_update["closeTime"] = str(r_close)
                if r_update:
                    await db.execute(update(Restaurant).where(Restaurant.isActive == True).values(**r_update))
            except Exception as r_err:
                pass

        await db.commit()
        clear_stores_cache()

        return {"success": True}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to save settings: {str(e)}")


@router.get("/reports")
async def get_sales_reports(
    startDate: Optional[str] = Query(None),
    endDate: Optional[str] = Query(None),
    storeId: Optional[str] = Query(None),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Generate dynamic sales dashboards reporting overall revenue, product breakdowns, and restaurant commissions.
    """
    try:
        now_utc = datetime.utcnow()
        ist_offset = timedelta(hours=5, minutes=30)
        now_ist = now_utc + ist_offset

        if startDate:
            start_local = datetime.strptime(f"{startDate} 00:00:00", "%Y-%m-%d %H:%M:%S")
            start = start_local - ist_offset
        else:
            start_local = datetime.combine((now_ist - timedelta(days=30)).date(), time.min)
            start = start_local - ist_offset
            startDate = start_local.strftime("%Y-%m-%d")

        if endDate:
            end_local = datetime.strptime(f"{endDate} 23:59:59", "%Y-%m-%d %H:%M:%S")
            end = end_local - ist_offset
        else:
            end_local = datetime.combine(now_ist.date(), time.max)
            end = end_local - ist_offset
            endDate = end_local.strftime("%Y-%m-%d")

        # 1. Fetch delivered orders with storeId filtering
        effective_store = storeId or _get_admin_attr(current_admin, "assignedStoreId")
        orders_stmt = select(Order).where(
            Order.status.in_([OrderStatus.DELIVERED, "DELIVERED"]),
            Order.createdAt >= start,
            Order.createdAt <= end
        )
        if effective_store and effective_store.lower() != 'all':
            orders_stmt = orders_stmt.where(Order.storeId == effective_store)

        orders_stmt = orders_stmt.order_by(Order.createdAt.asc())
        orders_res = await db.execute(orders_stmt)
        orders = orders_res.scalars().all()

        # 2. Fetch order items with LEFT JOINs to avoid dropping items missing categories/products
        store_clause = 'AND o."storeId" = :store_id' if effective_store and effective_store.lower() != 'all' else ''
        items_sql = f"""
            SELECT oi."orderId", oi."productId", oi.price, COALESCE(p.mrp, oi.price) as mrp, oi.quantity, oi.name, 
                   COALESCE(NULLIF(oi."costPrice", 0), p."costPrice", 0) as "costPrice", 
                   COALESCE(p.vendor, 'Direct / FastKirana') as "vendor",
                   COALESCE(c.name, CASE WHEN p."restaurantId" IS NOT NULL THEN r.name ELSE 'General Grocery' END) as "categoryName",
                   COALESCE(c.slug, CASE WHEN p."restaurantId" IS NOT NULL THEN r.slug ELSE 'general-grocery' END) as "categorySlug",
                   p.tags as "productTags",
                   COALESCE(oi.variants, p.variants) as "variants", 
                   oi."selectedVariant",
                   o."shopName" as "shopName",
                   p."restaurantId" as "prodRestaurantId",
                   o."restaurantId" as "orderRestaurantId",
                   r.name as "restaurantName",
                   r."commissionRate" as "restaurantCommissionRate",
                   o."orderType"::text as "orderType",
                   COALESCE(oi."refundAmount", 0)::float as "refundAmount",
                   COALESCE(oi."isRefunded", false) as "isRefunded",
                   CASE WHEN p.id IS NOT NULL AND p."restaurantId" IS NULL THEN true ELSE false END as "isGroceryProduct"
            FROM order_items oi
            JOIN orders o ON oi."orderId" = o.id
            LEFT JOIN products p ON oi."productId" = p.id
            LEFT JOIN categories c ON p."categoryId" = c.id
            LEFT JOIN restaurants r ON p."restaurantId" = r.id
            WHERE o.status::text = 'DELIVERED'
              AND o."createdAt" >= :start
              AND o."createdAt" <= :end
              {store_clause}
        """
        params = {"start": start, "end": end}
        if effective_store and effective_store.lower() != 'all':
            params["store_id"] = effective_store
        items_res = await db.execute(text(items_sql), params)
        order_items = [dict(r._mapping) for r in items_res.all()]

        items_by_order = {}
        for item in order_items:
            oid = item["orderId"]
            if oid not in items_by_order:
                items_by_order[oid] = []
            items_by_order[oid].append(item)

        # Load restaurants for commission checks
        rest_stmt = select(Restaurant)
        rest_res = await db.execute(rest_stmt)
        all_restaurants = rest_res.scalars().all()

        restaurant_by_id = {r.id: r for r in all_restaurants}
        restaurant_by_name = {r.name.lower().strip(): r for r in all_restaurants}
        restaurant_by_slug = {r.slug.lower().strip(): r for r in all_restaurants}

        # Load settings
        settings_stmt = select(StoreSetting).where(StoreSetting.key.in_(["restaurant_commission"]))
        settings_res = await db.execute(settings_stmt)
        settings_map = {s.key: s.value for s in settings_res.scalars().all()}
        dynamic_commission_rate = float(settings_map.get("restaurant_commission", "10.0")) / 100.0

        def resolve_restaurant_for_item(item):
            # If it's a catalog grocery product with no restaurantId on the product, it is NEVER a restaurant item
            if item.get("isGroceryProduct"):
                return None

            r_id = item.get("prodRestaurantId")
            if r_id and r_id in restaurant_by_id:
                return restaurant_by_id[r_id]

            # Only for custom items where productId is NULL (e.g. restaurant manual chef item)
            if not item.get("productId"):
                o_rid = item.get("orderRestaurantId")
                if o_rid and o_rid in restaurant_by_id:
                    return restaurant_by_id[o_rid]

            # Exact category name or slug match only
            cat_name = (item.get("categoryName") or "").strip().lower()
            cat_slug = (item.get("categorySlug") or "").strip().lower()
            for r in all_restaurants:
                if r.name.lower() == cat_name or r.slug.lower() == cat_slug:
                    return r

            return None

        missing_cost_products_map = {}

        def get_item_metrics(item):
            gross_rev = float(item["price"] or 0.0) * float(item["quantity"] or 1)
            item_refund = float(item.get("refundAmount") or 0.0)
            item_rev = max(0.0, gross_rev - item_refund)
            
            if item.get("isRefunded") and item_rev == 0:
                return 0.0, 0.0, 0.0, None

            # Catalog grocery products (p.restaurantId IS NULL) are NEVER restaurant items
            if item.get("isGroceryProduct"):
                matched_rest = None
                is_r = False
            else:
                matched_rest = resolve_restaurant_for_item(item)
                is_r = bool(matched_rest) or bool(item.get("prodRestaurantId"))

            if is_r:
                comm_rate = dynamic_commission_rate
                if matched_rest and matched_rest.commissionRate is not None:
                    raw_rate = float(matched_rest.commissionRate)
                    comm_rate = raw_rate / 100.0 if raw_rate > 1.0 else raw_rate
                elif item.get("restaurantCommissionRate") is not None:
                    raw_rate = float(item["restaurantCommissionRate"])
                    comm_rate = raw_rate / 100.0 if raw_rate > 1.0 else raw_rate

                item_profit = item_rev * comm_rate
                item_cost = item_rev * (1.0 - comm_rate)
                return item_cost, item_rev, item_profit, matched_rest

            cost_price = float(item.get("costPrice") or 0.0)

            if item.get("selectedVariant") and item.get("variants"):
                try:
                    variants_list = item["variants"]
                    if isinstance(variants_list, str):
                        variants_list = json.loads(variants_list)
                    if isinstance(variants_list, list):
                        mv = next((v for v in variants_list if v.get("name") == item["selectedVariant"]), None)
                        if mv and "costPrice" in mv:
                            cost_price = float(mv["costPrice"])
                except Exception:
                    pass

            has_cost = cost_price > 0
            cost_per_unit = cost_price if has_cost else (float(item["price"] or 0.0) * 0.75)
            prod_key = item.get("productId") or f"manual_{re.sub(r'[^a-z0-9]', '_', (item.get('name') or 'item').lower())}"
            if not has_cost:
                missing_cost_products_map[prod_key] = {
                    "id": prod_key,
                    "name": item.get("name") or "Unnamed Product",
                    "price": float(item.get("price") or 0.0)
                }

            item_cost = cost_per_unit * float(item.get("quantity") or 1)
            item_profit = item_rev - item_cost

            return item_cost, item_rev, item_profit, None

        # Aggregation metrics
        total_rev = 0.0
        total_profit = 0.0
        total_cost = 0.0
        total_misc_fee = 0.0
        total_taxes = 0.0
        total_delivery_fee = 0.0
        total_product_sales = 0.0

        # Treat combined sub-orders sharing combinedId as 1 single customer order
        unique_delivered_order_ids = set(
            (o.combinedId or o.id) for o in orders if o.deliveryMethod != "RETAIL"
        )
        total_orders = len(unique_delivered_order_ids)

        daily_data = {}
        curr_d = start_local.date()
        end_d = end_local.date()
        while curr_d <= end_d:
            d_str = curr_d.strftime("%Y-%m-%d")
            daily_data[d_str] = {"date": d_str, "sales": 0.0, "profit": 0.0, "orders": 0}
            curr_d += timedelta(days=1)

        category_data = {}
        product_data = {}

        delivery_orders_count = 0
        delivery_sales = 0.0
        delivery_profit = 0.0
        pickup_orders_count = 0
        pickup_sales = 0.0
        pickup_profit = 0.0
        retail_orders_count = 0
        retail_sales = 0.0
        retail_profit = 0.0

        seen_daily_combined = set()
        seen_delivery_combined = set()
        seen_pickup_combined = set()
        seen_retail_combined = set()

        for order in orders:
            is_pickup = order.deliveryMethod == "PICKUP"
            is_retail = order.deliveryMethod == "RETAIL"
            order_master_key = order.combinedId or order.id
            created_at_ist = (order.createdAt + ist_offset) if order.createdAt else now_ist
            date_str = created_at_ist.strftime("%Y-%m-%d")

            raw_sales = float(order.total or order.subtotal or 0.0) if is_retail else (float(order.subtotal or 0.0) - float(order.discount or 0.0))
            order_sales = max(0.0, raw_sales - float(getattr(order, 'refundAmount', 0.0) or 0.0))

            if date_str not in daily_data:
                daily_data[date_str] = {"date": date_str, "sales": 0.0, "profit": 0.0, "orders": 0}

            if not is_retail:
                daily_key = f"{date_str}_{order_master_key}"
                if daily_key not in seen_daily_combined:
                    seen_daily_combined.add(daily_key)
                    daily_data[date_str]["orders"] += 1

                daily_data[date_str]["sales"] += order_sales
                total_rev += order_sales
                total_misc_fee += float(order.miscFee or 0.0)
                total_taxes += float(order.taxes or 0.0)
                total_delivery_fee += float(order.deliveryFee or 0.0)
                total_product_sales += order_sales

            order_items_list = items_by_order.get(order.id, [])
            order_cost = 0.0

            for item in order_items_list:
                cost, rev, profit, matched_rest = get_item_metrics(item)
                order_cost += cost

                if is_retail:
                    continue

                is_grocery_prod = bool(item.get("isGroceryProduct"))
                
                if is_grocery_prod:
                    target_category_name = item.get("categoryName") or "Grocery Essentials"
                    target_type = "grocery"
                elif matched_rest:
                    target_category_name = matched_rest.name
                    target_type = "restaurant"
                elif item.get("prodRestaurantId"):
                    r_obj = restaurant_by_id.get(item["prodRestaurantId"])
                    target_category_name = r_obj.name if r_obj else (item.get("restaurantName") or "Restaurant Food")
                    target_type = "restaurant"
                else:
                    target_category_name = item.get("categoryName") or "General Store"
                    target_type = "grocery"

                # Category aggregation
                if target_category_name not in category_data:
                    category_data[target_category_name] = {
                        "categoryName": target_category_name,
                        "sales": 0.0,
                        "cost": 0.0,
                        "profit": 0.0,
                        "quantity": 0,
                        "type": target_type
                    }
                category_data[target_category_name]["sales"] += rev
                category_data[target_category_name]["cost"] += cost
                category_data[target_category_name]["profit"] += profit
                category_data[target_category_name]["quantity"] += int(item.get("quantity") or 1)

                # Product aggregation
                p_id = item.get("productId") or f"manual_{re.sub(r'[^a-z0-9]', '_', (item.get('name') or 'item').lower())}"
                if p_id not in product_data:
                    product_data[p_id] = {
                        "productId": p_id,
                        "name": item.get("name") or "Unnamed Product",
                        "mrp": float(item.get("mrp") or item.get("price") or 0.0),
                        "price": float(item.get("price") or 0.0),
                        "costPrice": float(item.get("costPrice") or 0.0),
                        "quantity": 0,
                        "sales": 0.0,
                        "profit": 0.0,
                        "categoryName": target_category_name,
                        "vendor": item.get("vendor") or "Direct / FastKirana",
                        "type": target_type
                    }
                product_data[p_id]["quantity"] += int(item.get("quantity") or 1)
                product_data[p_id]["sales"] += rev
                product_data[p_id]["profit"] += profit

            order_profit = float(order.total or 0.0) - order_cost

            if not is_retail:
                daily_data[date_str]["profit"] += order_profit
                total_profit += order_profit
                total_cost += order_cost

            if is_pickup:
                if order_master_key not in seen_pickup_combined:
                    seen_pickup_combined.add(order_master_key)
                    pickup_orders_count += 1
                pickup_sales += order_sales
                pickup_profit += order_profit
            elif is_retail:
                if order_master_key not in seen_retail_combined:
                    seen_retail_combined.add(order_master_key)
                    retail_orders_count += 1
                retail_sales += order_sales
                retail_profit += order_profit
            else:
                if order_master_key not in seen_delivery_combined:
                    seen_delivery_combined.add(order_master_key)
                    delivery_orders_count += 1
                delivery_sales += order_sales
                delivery_profit += order_profit

        daily_list = sorted(list(daily_data.values()), key=lambda x: x["date"])
        category_list = sorted(list(category_data.values()), key=lambda x: x["sales"], reverse=True)
        product_list = sorted(list(product_data.values()), key=lambda x: x["sales"], reverse=True)[:200]

        average_order_value = total_rev / total_orders if total_orders > 0 else 0.0
        profit_margin = (total_profit / total_rev) * 100.0 if total_rev > 0 else 0.0

        return {
            "success": True,
            "summary": {
                "totalSales": round(total_rev, 2),
                "totalCollected": round(total_rev + total_delivery_fee + total_taxes + total_misc_fee, 2),
                "totalProfit": round(total_profit, 2),
                "totalCost": round(total_cost, 2),
                "totalOrders": total_orders,
                "averageOrderValue": round(average_order_value, 2),
                "profitMargin": round(profit_margin, 1),
                "totalMiscFee": round(total_misc_fee, 2),
                "totalTaxes": round(total_taxes, 2),
                "totalDeliveryFee": round(total_delivery_fee, 2),
                "productSales": round(total_product_sales, 2),
                "missingCostCount": len(missing_cost_products_map),
                "delivery": {
                    "ordersCount": delivery_orders_count,
                    "sales": round(delivery_sales, 2),
                    "profit": round(delivery_profit, 2)
                },
                "pickup": {
                    "ordersCount": pickup_orders_count,
                    "sales": round(pickup_sales, 2),
                    "profit": round(pickup_profit, 2)
                },
                "retail": {
                    "ordersCount": retail_orders_count,
                    "sales": round(retail_sales, 2),
                    "profit": round(retail_profit, 2)
                }
            },
            "dailySales": daily_list,
            "categorySales": category_list,
            "topProducts": product_list,
            "missingCostProducts": list(missing_cost_products_map.values())
        }

    except Exception as e:
        logger.error(f"Reports API error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate reports: {str(e)}")


@router.get("/orders")
async def get_admin_all_orders(
    status_filter: Optional[str] = None,
    storeId: Optional[str] = None,
    limit: int = 100,
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all orders across system for Admin view.
    """
    stmt = select(Order).options(
        selectinload(Order.items),
        selectinload(Order.user),
        selectinload(Order.address),
        selectinload(Order.deliveryUser)
    )
    if status_filter and status_filter != 'ALL':
        from sqlalchemy import cast, String as SAString
        stmt = stmt.where(cast(Order.status, SAString) == status_filter)
    if storeId:
        stmt = stmt.where(Order.storeId == storeId)
    stmt = stmt.order_by(desc(Order.createdAt)).limit(limit)

    res = await db.execute(stmt)
    orders = res.scalars().all()
    
    # Return formatted list matching Next.js Order response
    return [
        {
            "id": o.id,
            "readableId": o.readableId,
            "userId": o.userId,
            "addressId": o.addressId,
            "restaurantId": o.restaurantId,
            "combinedId": o.combinedId,
            "orderType": o.orderType.value if hasattr(o.orderType, 'value') else str(o.orderType),
            "deliveryMethod": o.deliveryMethod or "DELIVERY",
            "storeId": o.storeId,
            "notes": o.notes,
            "isB2B": bool(o.isB2B),
            "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
            "subtotal": float(o.subtotal or 0.0),
            "discount": float(o.discount or 0.0),
            "deliveryFee": float(o.deliveryFee or 0.0),
            "taxes": float(o.taxes or 0.0),
            "miscFee": float(o.miscFee or 0.0),
            "total": float(o.total or 0.0),
            "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, 'value') else str(o.paymentMethod),
            "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, 'value') else str(o.paymentStatus),
            "estimatedDelivery": to_iso_utc(o.estimatedDelivery),
            "createdAt": to_iso_utc(o.createdAt),
            "updatedAt": to_iso_utc(o.updatedAt),
            "confirmedAt": to_iso_utc(o.confirmedAt),
            "packedAt": to_iso_utc(o.packedAt),
            "shippedAt": to_iso_utc(o.shippedAt),
            "deliveredAt": to_iso_utc(o.deliveredAt),
            "deliveryUserId": o.deliveryUserId,
            "assignedPickerId": o.assignedPickerId,
            "assignedChefId": o.assignedChefId,
            "deliveryLat": float(o.deliveryLat) if o.deliveryLat is not None else None,
            "deliveryLng": float(o.deliveryLng) if o.deliveryLng is not None else None,
            "shopName": o.shopName,
            "shopPhone": o.shopPhone,
            "couponCode": o.couponCode,
            "userName": (o.user.name.strip() if (o.user and o.user.name) else None) or "Customer",
            "userEmail": (o.user.email if o.user else None) or "",
            "userPhone": (o.address.phone if (o.address and o.address.phone) else None) or (o.user.phone if (o.user and o.user.phone) else None) or o.shopPhone or None,
            "deliveryBoyName": o.deliveryUser.name if o.deliveryUser else None,
            "deliveryBoyPhone": o.deliveryUser.phone if o.deliveryUser else None,
            "user": {
                "id": o.user.id if o.user else None,
                "name": (o.user.name.strip() if (o.user and o.user.name) else None) or "Customer",
                "phone": o.user.phone,
                "email": o.user.email
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
            "deliveryUser": {
                "id": o.deliveryUser.id if o.deliveryUser else None,
                "name": o.deliveryUser.name if o.deliveryUser else "Rider",
                "phone": o.deliveryUser.phone if o.deliveryUser else "",
            } if o.deliveryUser else None,
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
                    "variants": i.variants,
                } for i in (o.items or [])
            ]
        } for o in orders
    ]


@router.get("/dashboard")
async def get_admin_dashboard(
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get Admin dashboard overview statistics.
    """
    # Total orders
    total_orders_stmt = select(func.count(Order.id))
    total_orders = (await db.execute(total_orders_stmt)).scalar() or 0

    # Total revenue
    total_rev_stmt = select(func.coalesce(func.sum(Order.total), 0.0)).where(text("orders.\"paymentStatus\"::text = 'PAID'"))
    total_revenue = (await db.execute(total_rev_stmt)).scalar() or 0.0

    # Pending orders count
    pending_stmt = select(func.count(Order.id)).where(text("orders.status::text IN ('PENDING', 'CONFIRMED', 'PREPARING')"))
    pending_orders = (await db.execute(pending_stmt)).scalar() or 0

    # Total users count
    total_users_stmt = select(func.count(User.id))
    total_users = (await db.execute(total_users_stmt)).scalar() or 0

    return {
        "totalOrders": total_orders,
        "totalRevenue": float(total_revenue),
        "pendingOrders": pending_orders,
        "totalUsers": total_users,
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/forecast")
@router.get("/inventory/forecast")
async def get_admin_inventory_forecast(
    storeId: Optional[str] = Query(None),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Generate inventory reorder suggestions and risk alerts based on 30-day velocity metrics with storeId scoping.
    """
    try:
        from models import StoreInventory
        
        # Check if storeId has localized inventory; if 0, fall back to hub-209206 (Ghatampur Central Hub)
        effective_store_id = storeId
        if storeId and storeId.lower() != 'all':
            inv_cnt_stmt = select(func.count()).select_from(StoreInventory).where(StoreInventory.storeId == storeId)
            inv_cnt = (await db.execute(inv_cnt_stmt)).scalar() or 0
            if inv_cnt == 0:
                effective_store_id = "hub-209206"

        # Load active products from categories other than cafe
        products_stmt = select(Product).options(selectinload(Product.category)).join(Category).where(
            Product.isAvailable == True,
            Product.restaurantId.is_(None),
            Category.slug != "cafe"
        )
        if effective_store_id and effective_store_id.lower() != 'all':
            products_stmt = products_stmt.where(
                Product.id.in_(
                    select(StoreInventory.productId).where(StoreInventory.storeId == effective_store_id)
                )
            )
        products_res = await db.execute(products_stmt)
        products = products_res.scalars().all()

        local_stock_map = {}
        if effective_store_id and effective_store_id.lower() != 'all':
            inv_res = await db.execute(select(StoreInventory).where(StoreInventory.storeId == effective_store_id))
            for inv in inv_res.scalars().all():
                local_stock_map[inv.productId] = int(inv.stock or 0)

        # Fetch order items from the last 30 days
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        items_stmt = select(OrderItem, Order.createdAt).join(Order, OrderItem.orderId == Order.id).where(
            Order.status.in_([OrderStatus.DELIVERED, OrderStatus.SHIPPED, OrderStatus.PACKED, OrderStatus.CONFIRMED]),
            Order.createdAt >= thirty_days_ago
        )
        if effective_store_id and effective_store_id.lower() != 'all':
            # Check if store has orders; if not, fall back to all orders for velocity
            store_orders_cnt = (await db.execute(select(func.count()).select_from(Order).where(Order.storeId == effective_store_id))).scalar() or 0
            if store_orders_cnt > 0:
                items_stmt = items_stmt.where(Order.storeId == effective_store_id)
        items_res = await db.execute(items_stmt)
        order_items = items_res.all()

        product_sales_map = {}
        for item, o_created_at in order_items:
            if not item.productId:
                continue
            day = o_created_at.weekday()  # Monday is 0, Sunday is 6
            # Weekend definition: Friday (4), Saturday (5), Sunday (6)
            is_weekend = day in [4, 5, 6]

            if item.productId not in product_sales_map:
                product_sales_map[item.productId] = {"totalQty": 0, "weekdayQty": 0, "weekendQty": 0}

            product_sales_map[item.productId]["totalQty"] += item.quantity
            if is_weekend:
                product_sales_map[item.productId]["weekendQty"] += item.quantity
            else:
                product_sales_map[item.productId]["weekdayQty"] += item.quantity

        forecast_list = []
        for p in products:
            p_stock = local_stock_map.get(p.id, p.stock) if (storeId and storeId.lower() != 'all') else p.stock
            sales = product_sales_map.get(p.id, {"totalQty": 0, "weekdayQty": 0, "weekendQty": 0})

            # Calculate velocities
            daily_velocity = round(sales["totalQty"] / 30.0, 2)
            weekday_velocity = round(sales["weekdayQty"] / 16.0, 2) # 16 weekdays in 30 days
            weekend_velocity = round(sales["weekendQty"] / 14.0, 2) # 14 weekend days in 30 days

            # Fallbacks simulated velocity for sparse items (Demo mode parity)
            if sales["totalQty"] == 0:
                name_lower = p.name.lower()
                if "milk" in name_lower or "dairy" in name_lower:
                    daily_velocity = 6.4
                    weekday_velocity = 4.2
                    weekend_velocity = 8.9
                elif "egg" in name_lower or "bread" in name_lower:
                    daily_velocity = 4.8
                    weekday_velocity = 3.0
                    weekend_velocity = 6.9
                elif "potato" in name_lower or "tomato" in name_lower or "onion" in name_lower:
                    daily_velocity = 3.5
                    weekday_velocity = 2.8
                    weekend_velocity = 4.3
                elif "chips" in name_lower or "snack" in name_lower or "coke" in name_lower:
                    daily_velocity = 2.9
                    weekday_velocity = 1.8
                    weekend_velocity = 4.2
                else:
                    hash_val = sum(ord(c) for c in p.id)
                    daily_velocity = round(0.2 + (hash_val % 10) / 10.0, 2)
                    weekday_velocity = round(daily_velocity * 0.8, 2)
                    weekend_velocity = round(daily_velocity * 1.25, 2)

            weekend_boost = round(weekend_velocity / weekday_velocity, 2) if weekday_velocity > 0 else 1.0
            days_remaining = max(0, int(p_stock / daily_velocity)) if daily_velocity > 0 else 999
            
            is_at_risk = days_remaining <= 6 or p_stock <= p.minStock
            raw_reorder = daily_velocity * 14
            recommended_reorder = max(50, int(math.ceil(raw_reorder / 10.0) * 10)) if is_at_risk else 0

            reorder_by_day = "N/A"
            suggestion = "Stock levels healthy."

            if is_at_risk:
                if p_stock == 0:
                    reorder_by_day = "TODAY"
                    suggestion = f"🔴 Out of stock! Reorder {recommended_reorder} units immediately."
                elif days_remaining <= 1:
                    reorder_by_day = "TODAY"
                    suggestion = f"🚨 Critical: Stock runs out in 1 day. Reorder {recommended_reorder} units today."
                else:
                    days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                    target_date = datetime.utcnow() + timedelta(days=max(1, days_remaining - 1))
                    reorder_by_day = days_of_week[target_date.weekday()]

                    if weekend_boost >= 1.5:
                        reorder_by_day = "Thursday"
                        suggestion = f"⚠️ High weekend sales (velocity increases {weekend_boost}x)! Reorder {recommended_reorder} units before Friday."
                    else:
                        suggestion = f"Reorder {recommended_reorder} units before {reorder_by_day} (stock depleting in {days_remaining} days)."

            forecast_list.append({
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "imageUrl": p.imageUrl,
                "stock": p_stock,
                "minStock": p.minStock,
                "costPrice": p.costPrice or round(p.price * 0.75, 2),
                "price": float(p.price),
                "category": {
                    "id": p.category.id,
                    "name": p.category.name,
                    "slug": p.category.slug
                } if p.category else None,
                "salesVelocity": daily_velocity,
                "weekdayVelocity": weekday_velocity,
                "weekendVelocity": weekend_velocity,
                "weekendBoost": weekend_boost,
                "daysRemaining": days_remaining,
                "recommendedReorder": recommended_reorder,
                "reorderByDay": reorder_by_day,
                "suggestion": suggestion,
                "isAtRisk": is_at_risk,
                "revenueAtRisk": round(p.price * recommended_reorder, 2) if is_at_risk else 0.0
            })

        # Sort: At-risk items with soonest depletion first, then by velocity descending
        forecast_list.sort(key=lambda x: (not x["isAtRisk"], x["daysRemaining"] if x["isAtRisk"] else -x["salesVelocity"]))

        items_at_risk = len([f for f in forecast_list if f["isAtRisk"]])
        total_rev_at_risk = sum(f["revenueAtRisk"] for f in forecast_list)
        average_velocity = round(sum(f["salesVelocity"] for f in forecast_list) / len(forecast_list), 2) if forecast_list else 0.0

        return {
            "forecast": forecast_list,
            "metrics": {
                "itemsAtRisk": items_at_risk,
                "totalRevenueAtRisk": total_rev_at_risk,
                "averageVelocity": average_velocity
            }
        }
    except Exception as e:
        logger.error(f"Failed to generate inventory forecast: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate inventory forecast: {str(e)}")


@router.get("/me")
async def get_admin_me(
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current logged in admin info and assigned store/hub.
    """
    admin_id = _get_admin_attr(current_admin, "id")
    admin_name = _get_admin_attr(current_admin, "name")
    admin_email = _get_admin_attr(current_admin, "email")
    admin_phone = _get_admin_attr(current_admin, "phone")
    admin_role = _get_admin_attr(current_admin, "role")
    admin_store = _get_admin_attr(current_admin, "assignedStoreId")

    store_name = None
    if admin_store:
        st_res = await db.execute(select(DarkStore).where(DarkStore.id == admin_store))
        store_obj = st_res.scalars().first()
        if store_obj:
            store_name = store_obj.name

    return {
        "user": {
            "id": admin_id,
            "name": admin_name,
            "email": admin_email,
            "phone": admin_phone,
            "role": admin_role.value if hasattr(admin_role, 'value') else str(admin_role or "ADMIN"),
            "assignedStoreId": admin_store,
        },
        "assignedStoreId": admin_store,
        "storeName": store_name
    }


@router.get("/riders")
async def get_admin_riders(
    storeId: Optional[str] = None,
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get active delivery riders/partners for order assignment.
    """
    stmt = select(User).where(User.role == Role.DELIVERY)
    effective_store = storeId or _get_admin_attr(current_admin, "assignedStoreId")
    if effective_store and effective_store.lower() != 'all':
        stmt = stmt.where(User.assignedStoreId == effective_store)
    stmt = stmt.order_by(User.name.asc())

    res = await db.execute(stmt)
    riders = res.scalars().all()
    return {
        "success": True,
        "riders": [
            {
                "id": r.id,
                "name": r.name or "Delivery Partner",
                "phone": r.phone or "",
                "role": r.role.value if hasattr(r.role, 'value') else str(r.role),
                "assignedStoreId": r.assignedStoreId,
            } for r in riders
        ]
    }


@router.get("/users/{user_id}/addresses")
async def get_admin_user_addresses(
    user_id: str,
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get addresses saved by a specific user for admin support.
    """
    stmt = select(Address).where(Address.userId == user_id).order_by(desc(Address.createdAt))
    res = await db.execute(stmt)
    addresses = res.scalars().all()
    return [
        {
            "id": a.id,
            "userId": a.userId,
            "label": a.label,
            "houseNo": a.houseNo,
            "street": a.street,
            "area": a.area,
            "city": a.city,
            "pincode": a.pincode,
            "phone": a.phone,
            "lat": a.lat,
            "lng": a.lng,
            "isDefault": a.isDefault,
        } for a in addresses
    ]


@router.patch("/users/block")
async def block_user_alias(
    payload: dict = Body(...),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Block or unblock user account by payload { userId, isBlocked, blockReason }.
    """
    user_id = payload.get("userId") or payload.get("id")
    is_blocked = bool(payload.get("isBlocked", True))
    block_reason = payload.get("blockReason") or "Blocked by administrator"

    if not user_id:
        raise HTTPException(status_code=400, detail="userId is required")

    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalars().first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == Role.ADMIN:
        raise HTTPException(status_code=400, detail="Administrator accounts cannot be blocked")
    admin_id = _get_admin_attr(current_admin, "id")
    if user.id == admin_id:
        raise HTTPException(status_code=400, detail="You cannot block your own admin account")

    user.isBlocked = is_blocked
    user.blockReason = block_reason if is_blocked else None
    user.blockedAt = datetime.utcnow() if is_blocked else None
    await db.commit()

    return {
        "success": True,
        "message": f"User {'blocked' if is_blocked else 'unblocked'} successfully",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "isBlocked": user.isBlocked,
            "blockReason": user.blockReason,
        }
    }


@router.patch("/users")
async def admin_update_user(
    payload: dict = Body(...),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    H19 FIX: Admin updates user details (role, name, phone, assignedStoreId).
    Includes safeguard to prevent downgrading master/superadmin accounts.
    """
    user_id = payload.get("userId") or payload.get("id")
    if not user_id:
        raise HTTPException(status_code=400, detail="Missing required userId")

    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    name = payload.get("name")
    phone = payload.get("phone")
    role_str = payload.get("role")
    assigned_store_id = payload.get("assignedStoreId")

    if name:
        user.name = str(name).strip()
    if phone:
        user.phone = str(phone).strip()
    if "assignedStoreId" in payload:
        user.assignedStoreId = assigned_store_id if assigned_store_id else None

    if role_str:
        allowed_roles = [r.value for r in Role]
        if role_str not in allowed_roles:
            raise HTTPException(status_code=400, detail=f"Invalid role. Allowed: {allowed_roles}")

        # Root admin downgrade safeguard
        is_root_admin = (
            user.email in ["admin@fastkirana.com", "superadmin@fastkirana.com"]
            or (user.phone and ("7054470303" in user.phone or "9170942500" in user.phone))
        )
        if is_root_admin and role_str != Role.ADMIN.value:
            raise HTTPException(status_code=403, detail="Root Admin accounts cannot be downgraded")

        user.role = Role(role_str)

    user.updatedAt = datetime.utcnow()
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
            "assignedStoreId": user.assignedStoreId
        }
    }


@router.post("/users")
@router.post("/users/password")
async def admin_set_user_password(
    payload: dict = Body(...),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    H20 FIX: Admin sets or resets password for staff/worker/customer accounts.
    Syncs password across all alternate phone representations.
    """
    from routers.auth import hash_password

    user_id = payload.get("userId") or payload.get("id")
    password = payload.get("password")

    if not user_id or not password:
        raise HTTPException(status_code=400, detail="userId and password are required")

    if len(str(password)) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")

    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    new_hash = hash_password(str(password))

    # If user has phone, sync to all matching phone accounts
    if user.phone:
        raw_digits = re.sub(r"\D", "", user.phone)[-10:]
        phone_variants = [user.phone, raw_digits, f"+91{raw_digits}"]
        sync_stmt = (
            update(User)
            .where(
                or_(
                    User.id == user.id,
                    User.phone.in_(phone_variants),
                    User.email == f"wa-{raw_digits}@fastkirana.com"
                )
            )
            .values(passwordHash=new_hash, updatedAt=datetime.utcnow())
        )
        await db.execute(sync_stmt)
    else:
        user.passwordHash = new_hash
        user.updatedAt = datetime.utcnow()

    await db.commit()

    return {
        "success": True,
        "message": f"Password updated successfully for user {user.name or user.email or user.phone}"
    }


@router.post("/orders/sync-razorpay")
async def admin_sync_razorpay_order(
    payload: dict = Body(...),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Reconcile pending order with Razorpay payment ID.
    """
    import httpx
    from config import settings
    payment_id = payload.get("paymentId")
    order_id = payload.get("orderId")

    if not payment_id and not order_id:
        raise HTTPException(status_code=400, detail="Either paymentId or orderId is required")

    target_order = None
    if order_id:
        stmt = select(Order).where(or_(Order.id == order_id, Order.readableId == str(order_id)))
        res = await db.execute(stmt)
        target_order = res.scalars().first()

    if not target_order:
        raise HTTPException(status_code=404, detail="Order not found")

    # If Razorpay payment ID is provided, verify directly with Razorpay API
    if payment_id and settings.RAZORPAY_KEY_ID and settings.RAZORPAY_KEY_SECRET:
        import base64
        auth_str = base64.b64encode(f"{settings.RAZORPAY_KEY_ID}:{settings.RAZORPAY_KEY_SECRET}".encode()).decode()
        async with httpx.AsyncClient() as client:
            try:
                rzp_res = await client.get(
                    f"https://api.razorpay.com/v1/payments/{payment_id}",
                    headers={"Authorization": f"Basic {auth_str}"}
                )
                if rzp_res.status_code == 200:
                    rzp_data = rzp_res.json()
                    if rzp_data.get("status") in ["captured", "authorized"]:
                        target_order.paymentStatus = PaymentStatus.PAID
                        if target_order.status in [OrderStatus.PENDING, OrderStatus.ADMIN_PENDING]:
                            target_order.status = OrderStatus.CONFIRMED
                        await db.commit()
                        return {"success": True, "message": f"Payment {payment_id} verified. Order marked PAID."}
                    else:
                        raise HTTPException(status_code=400, detail=f"Razorpay status is {rzp_data.get('status')}")
            except HTTPException:
                raise
            except Exception as rzp_err:
                logger.warning(f"Razorpay live check error: {rzp_err}")

    # Direct fallback: Mark order as verified by admin
    target_order.paymentStatus = PaymentStatus.PAID
    if target_order.status in [OrderStatus.PENDING, OrderStatus.ADMIN_PENDING]:
        target_order.status = OrderStatus.CONFIRMED
    await db.commit()

    try:
        status_evt = {
            "event": "STATUS_UPDATE",
            "orderId": target_order.id,
            "status": target_order.status.value,
            "restaurantId": target_order.restaurantId,
            "order": {
                "id": target_order.id,
                "readableId": target_order.readableId,
                "status": target_order.status.value,
                "restaurantId": target_order.restaurantId,
                "total": float(target_order.total),
                "updatedAt": target_order.updatedAt.isoformat() if target_order.updatedAt else datetime.utcnow().isoformat()
            }
        }
        await manager.broadcast_to_channel("general", status_evt)
        await manager.broadcast_to_channel(f"order_{target_order.id}", status_evt)
        if target_order.restaurantId:
            await manager.broadcast_to_channel(f"restaurant_{target_order.restaurantId}", status_evt)
    except Exception:
        pass

    return {"success": True, "message": f"Order #{target_order.readableId or target_order.id} marked PAID."}


@router.get("/reports/orders")
async def get_admin_detailed_orders_report(
    startDate: Optional[str] = None,
    endDate: Optional[str] = None,
    storeId: Optional[str] = None,
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed breakdown of orders with customers and financial totals.
    """
    stmt = select(Order).options(selectinload(Order.user), selectinload(Order.address))
    if storeId and storeId.lower() != 'all':
        stmt = stmt.where(Order.storeId == storeId)
    if startDate:
        try:
            s_date = datetime.strptime(startDate, "%Y-%m-%d")
            stmt = stmt.where(Order.createdAt >= s_date)
        except Exception:
            pass
    if endDate:
        try:
            e_date = datetime.strptime(endDate, "%Y-%m-%d") + timedelta(days=1)
            stmt = stmt.where(Order.createdAt < e_date)
        except Exception:
            pass

    stmt = stmt.order_by(desc(Order.createdAt)).limit(500)
    res = await db.execute(stmt)
    orders = res.scalars().all()

    return {
        "orders": [
            {
                "id": o.id,
                "readableId": o.readableId,
                "status": o.status.value if hasattr(o.status, 'value') else str(o.status),
                "total": float(o.total),
                "subtotal": float(o.subtotal),
                "discount": float(o.discount),
                "deliveryFee": float(o.deliveryFee),
                "taxes": float(o.taxes),
                "miscFee": float(o.miscFee),
                "paymentMethod": o.paymentMethod.value if hasattr(o.paymentMethod, 'value') else str(o.paymentMethod),
                "paymentStatus": o.paymentStatus.value if hasattr(o.paymentStatus, 'value') else str(o.paymentStatus),
                "createdAt": o.createdAt.isoformat() if o.createdAt else None,
                "shopName": o.shopName,
                "customerName": o.user.name if o.user else "Customer",
                "customerPhone": o.user.phone if o.user else "",
            } for o in orders
        ]
    }


superadmin_router = APIRouter(prefix="/superadmin", tags=["Superadmin Dashboard"])

@superadmin_router.get("/stats")
async def get_superadmin_stats(
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Superadmin overview stats across all DarkStore hubs, staff, and multi-tenant stores.
    """
    now = datetime.utcnow()
    # IST midnight offset
    ist_now = now + timedelta(hours=5, minutes=30)
    ist_start = datetime(ist_now.year, ist_now.month, ist_now.day)
    start_of_today = ist_start - timedelta(hours=5, minutes=30)

    # 1. Fetch dark stores
    stores_stmt = select(DarkStore).order_by(DarkStore.createdAt.desc())
    stores_res = await db.execute(stores_stmt)
    stores = stores_res.scalars().all()

    # 2. Today's orders
    today_agg_stmt = select(
        func.coalesce(func.sum(Order.total), 0.0),
        func.count(Order.id)
    ).where(and_(
        Order.createdAt >= start_of_today,
        Order.status != OrderStatus.CANCELLED
    ))
    today_total, today_count = (await db.execute(today_agg_stmt)).first() or (0.0, 0)

    # 3. Delivered orders
    del_agg_stmt = select(
        func.coalesce(func.sum(Order.total), 0.0),
        func.count(Order.id)
    ).where(and_(
        Order.createdAt >= start_of_today,
        Order.status == OrderStatus.DELIVERED
    ))
    del_total, del_count = (await db.execute(del_agg_stmt)).first() or (0.0, 0)

    # 4. Store-wise sales
    store_sales_stmt = select(
        Order.storeId,
        func.count(Order.id).label("orderCount"),
        func.coalesce(func.sum(case((Order.status != OrderStatus.CANCELLED, Order.total), else_=0.0)), 0.0).label("totalSales"),
        func.coalesce(func.sum(case((Order.status == OrderStatus.DELIVERED, Order.total), else_=0.0)), 0.0).label("deliveredSales"),
        func.coalesce(func.sum(case((and_(Order.status != OrderStatus.DELIVERED, Order.status != OrderStatus.CANCELLED), 1), else_=0)), 0).label("activeOrders"),
        func.coalesce(func.sum(case((Order.status == OrderStatus.DELIVERED, 1), else_=0)), 0).label("deliveredOrders")
    ).where(Order.createdAt >= start_of_today).group_by(Order.storeId)
    store_sales_res = await db.execute(store_sales_stmt)
    store_sales_rows = store_sales_res.all()

    store_map = {s.id: s.name for s in stores}
    formatted_store_wise_sales = [
        {
            "storeId": row.storeId,
            "storeName": store_map.get(row.storeId, "Unassigned"),
            "orderCount": int(row.orderCount),
            "totalSales": float(row.totalSales),
            "deliveredSales": float(row.deliveredSales),
            "activeOrders": int(row.activeOrders),
            "deliveredOrders": int(row.deliveredOrders)
        }
        for row in store_sales_rows
    ]

    # 5. Staff list
    staff_stmt = select(User).where(User.role != Role.USER).order_by(User.createdAt.desc())
    staff_res = await db.execute(staff_stmt)
    staff_list = staff_res.scalars().all()

    formatted_staff = [
        {
            "id": s.id,
            "name": s.name,
            "phone": s.phone,
            "email": s.email,
            "role": s.role.value if hasattr(s.role, "value") else str(s.role),
            "assignedStoreId": s.assignedStoreId,
            "storeName": store_map.get(s.assignedStoreId, s.assignedStoreId or "Unassigned"),
            "assignedRestaurantId": s.assignedRestaurantId
        }
        for s in staff_list
    ]

    return {
        "combined": {
            "todaySales": float(today_total),
            "todayNetRevenue": float(del_total),
            "todayOrders": int(today_count),
            "todayDeliveredOrders": int(del_count),
            "totalStaff": len(staff_list),
            "totalStores": len(stores),
        },
        "stores": [
            {
                "id": s.id,
                "name": s.name,
                "isActive": s.isActive,
                "groceryOpen": s.groceryOpen,
                "latitude": s.latitude,
                "longitude": s.longitude,
                "deliveryRadiusKm": s.deliveryRadiusKm,
            }
            for s in stores
        ],
        "storeWiseSales": formatted_store_wise_sales,
        "staff": formatted_staff,
    }


# ============================================================
# 3-PILLAR DAILY FINANCE & CASH RECONCILIATION API
# ============================================================
@router.get("/finance/daily")
async def get_daily_finance_reconciliation(
    date_str: Optional[str] = Query(None, alias="date"),
    storeId: Optional[str] = Query(None),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    3-Pillar Daily Finance & Reconciliation:
    1. Bank / Cashfree Online Total
    2. Counter Cash (Galla) Total
    3. Rider Cash In-Hand (Pending Settlement)
    Plus detailed audit ledger of every transaction and who verified it.
    """
    # 1. Parse target date in IST (UTC + 5:30)
    now_utc = datetime.utcnow()
    now_ist = now_utc + timedelta(hours=5, minutes=30)

    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            target_date = now_ist.date()
    else:
        target_date = now_ist.date()

    # Convert IST day range back to UTC for database queries
    ist_start = datetime.combine(target_date, time.min)
    ist_end = datetime.combine(target_date, time.max)
    utc_start = ist_start - timedelta(hours=5, minutes=30)
    utc_end = ist_end - timedelta(hours=5, minutes=30)

    # 2. Build base query for orders
    order_stmt = select(Order).options(
        selectinload(Order.user),
        selectinload(Order.deliveryUser)
    ).where(
        Order.createdAt >= utc_start,
        Order.createdAt <= utc_end
    )

    effective_store = storeId or _get_admin_attr(current_admin, "assignedStoreId")
    if effective_store and effective_store.lower() != "all":
        order_stmt = order_stmt.where(Order.storeId == effective_store)

    order_stmt = order_stmt.order_by(desc(Order.createdAt))
    order_res = await db.execute(order_stmt)
    all_orders = order_res.scalars().all()

    # 3. Categorize transactions and compute metrics
    cashfree_online_total = 0.0
    cashfree_online_count = 0

    rider_qr_total = 0.0
    rider_qr_count = 0

    counter_cash_total = 0.0
    counter_cash_count = 0

    rider_cash_total = 0.0
    rider_cash_count = 0

    pending_cod_total = 0.0
    pending_cod_count = 0

    pending_online_total = 0.0
    pending_online_count = 0

    transactions = []

    for o in all_orders:
        tot = float(o.total or 0.0)
        p_status = str(o.paymentStatus.value if hasattr(o.paymentStatus, "value") else o.paymentStatus).upper()
        p_method = str(o.paymentMethod.value if hasattr(o.paymentMethod, "value") else o.paymentMethod).upper()
        o_status = str(o.status.value if hasattr(o.status, "value") else o.status).upper()
        notes = str(o.notes or "")
        is_doorstep_qr = "Doorstep UPI" in notes or "QR Scan" in notes or "Rider QR" in notes

        if o_status == "CANCELLED":
            verified_by = "Order Cancelled"
            category = "CANCELLED"
        elif p_status == "PAID":
            if is_doorstep_qr:
                rider_qr_total += tot
                rider_qr_count += 1
                category = "RIDER_QR"
                verified_by = f"Rider QR ({o.deliveryUser.name if o.deliveryUser else 'Rider'})"
            elif p_method in ["UPI", "CARD", "WALLET", "ONLINE", "RAZORPAY", "CASHFREE"]:
                cashfree_online_total += tot
                cashfree_online_count += 1
                category = "CASHFREE_ONLINE"
                verified_by = "Cashfree Gateway (Auto)"
            else:
                # COD marked as PAID in cash
                if o.cashSettledToAdmin:
                    counter_cash_total += tot
                    counter_cash_count += 1
                    category = "COUNTER_CASH"
                    verified_by = "Settled to Counter"
                elif o_status == "DELIVERED":
                    rider_cash_total += tot
                    rider_cash_count += 1
                    category = "RIDER_CASH"
                    verified_by = f"Rider Cash ({o.deliveryUser.name if o.deliveryUser else 'Rider'})"
                else:
                    counter_cash_total += tot
                    counter_cash_count += 1
                    category = "COUNTER_CASH"
                    verified_by = "Cash Paid"
        else:
            # Payment status PENDING / FAILED
            if p_method == "COD":
                if o_status == "DELIVERED":
                    # Delivered but cash settlement pending
                    rider_cash_total += tot
                    rider_cash_count += 1
                    category = "RIDER_CASH"
                    verified_by = f"Rider Cash ({o.deliveryUser.name if o.deliveryUser else 'Rider'})"
                else:
                    pending_cod_total += tot
                    pending_cod_count += 1
                    category = "PENDING_DELIVERY"
                    verified_by = "COD at Doorstep"
            else:
                pending_online_total += tot
                pending_online_count += 1
                category = "PENDING_ONLINE"
                verified_by = "Awaiting Online Payment"

        # Format readable created time in IST
        order_ist = o.createdAt + timedelta(hours=5, minutes=30) if o.createdAt else None
        time_ist_str = order_ist.strftime("%I:%M %p") if order_ist else ""

        transactions.append({
            "id": o.id,
            "readableId": str(o.readableId or o.id[-6:]).upper(),
            "createdAt": to_iso_utc(o.createdAt),
            "timeStr": time_ist_str,
            "total": tot,
            "customerName": o.user.name if o.user else "Customer",
            "customerPhone": o.user.phone if o.user else "",
            "shopName": o.shopName or ("FastKirana Grocery" if not o.restaurantId else "Restaurant"),
            "paymentMethod": p_method,
            "paymentStatus": p_status,
            "orderStatus": o_status,
            "category": category,
            "verifiedBy": verified_by,
            "riderName": o.deliveryUser.name if o.deliveryUser else None,
            "cashSettled": bool(o.cashSettledToAdmin),
            "cashSettledAt": to_iso_utc(o.cashSettledAt) if o.cashSettledAt else None,
        })

    # 4. Fetch Active Riders & their In-Hand Cash
    rider_query = select(User).options(selectinload(User.riderWallet)).where(
        User.role == Role.DELIVERY
    )
    if effective_store and effective_store.lower() != "all":
        rider_query = rider_query.where(User.assignedStoreId == effective_store)

    rider_res = await db.execute(rider_query)
    riders = rider_res.scalars().all()

    rider_summary = []
    for r in riders:
        wallet = r.riderWallet
        cash_in_hand = float(wallet.cashInHand) if wallet else 0.0

        # Today's delivered orders for this rider
        r_del_orders = [t for t in transactions if t.get("riderName") == r.name and t.get("orderStatus") == "DELIVERED"]

        if cash_in_hand > 0 or len(r_del_orders) > 0:
            rider_summary.append({
                "id": r.id,
                "name": r.name or "Rider",
                "phone": r.phone or "",
                "cashInHand": cash_in_hand,
                "todayDeliveredCount": len(r_del_orders),
                "todayDeliveredTotal": sum(t["total"] for t in r_del_orders),
            })

    online_bank_total = cashfree_online_total + rider_qr_total
    online_order_count = cashfree_online_count + rider_qr_count
    total_reconciled = online_bank_total + counter_cash_total + rider_cash_total

    return {
        "date": target_date.strftime("%Y-%m-%d"),
        "isToday": (target_date == now_ist.date()),
        "summary": {
            "cashfreeOnlineTotal": round(cashfree_online_total, 2),
            "cashfreeOnlineCount": cashfree_online_count,
            "riderQrTotal": round(rider_qr_total, 2),
            "riderQrCount": rider_qr_count,
            "onlineBankTotal": round(online_bank_total, 2),
            "onlineOrderCount": online_order_count,
            "counterCashTotal": round(counter_cash_total, 2),
            "counterCashCount": counter_cash_count,
            "riderCashTotal": round(rider_cash_total, 2),
            "riderCashCount": rider_cash_count,
            "pendingCodTotal": round(pendingCod_total, 2),
            "pendingCodCount": pending_cod_count,
            "pendingOnlineTotal": round(pending_online_total, 2),
            "pendingOnlineCount": pending_online_count,
            "totalReconciled": round(total_reconciled, 2),
            "totalOrdersCount": len(all_orders),
        },
        "riders": rider_summary,
        "transactions": transactions,
    }

