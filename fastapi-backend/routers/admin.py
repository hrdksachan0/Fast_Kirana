from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from sqlalchemy import func, and_, desc, text
from datetime import datetime, date
import uuid
from database import get_db
from models import User, Order, RiderWallet, CashDepositTransaction, Role, OrderStatus, PaymentMethod, PaymentStatus
from schemas import CashDepositRequest, FinancialSummaryOut
from routers.auth import require_admin

router = APIRouter(prefix="/admin", tags=["Admin Reconciliation"])

@router.get("/rider-cash")
async def get_admin_rider_cash_summary(
    current_admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Real-time financial reconciliation & rider cash balances
    """
    today_start = datetime.combine(date.today(), datetime.min.time())

    # 1. Fetch riders using standard SQLAlchemy enum filter
    rider_stmt = select(User).options(selectinload(User.riderWallet)).where(User.role == Role.DELIVERY)
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

        pending_rider_cash += wallet.cashInHand

        # Fetch today's COD stats for rider
        cod_stmt = select(func.count(Order.id), func.coalesce(func.sum(Order.total), 0.0)).where(
            and_(
                Order.deliveryUserId == r.id,
                Order.paymentMethod == PaymentMethod.COD,
                Order.status == OrderStatus.DELIVERED,
                Order.createdAt >= today_start
            )
        )
        cod_res = await db.execute(cod_stmt)
        today_cod_count, today_cod_total = cod_res.first() or (0, 0.0)

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
            "cashInHand": wallet.cashInHand,
            "cashLimit": wallet.cashLimit,
            "totalCollected": wallet.totalCollected,
            "totalDeposited": wallet.totalDeposited,
            "todayCodOrdersCount": today_cod_count,
            "todayCodTotal": float(today_cod_total),
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
            Order.createdAt >= today_start
        )
    )
    delivered_cod_today = (await db.execute(delivered_cod_stmt)).scalar() or 0.0

    counter_cash_stmt = select(func.coalesce(func.sum(Order.total), 0.0)).where(
        and_(
            Order.paymentMethod == PaymentMethod.COD,
            Order.status == OrderStatus.DELIVERED,
            Order.deliveryUserId.is_(None),
            Order.createdAt >= today_start
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
                "amount": d.amount,
                "notes": d.notes,
                "createdAt": d.createdAt
            } for d in recent_deps
        ]
    }

@router.post("/rider-cash")
async def settle_rider_cash(
    payload: CashDepositRequest,
    current_admin: User = Depends(require_admin),
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
    wallet.cashInHand = max(0.0, wallet.cashInHand - deposit_amount)
    wallet.totalDeposited += deposit_amount

    transaction = CashDepositTransaction(
        id=f"tx_{uuid.uuid4().hex[:12]}",
        riderId=payload.riderId,
        adminId=current_admin.id,
        amount=deposit_amount,
        status="APPROVED",
        notes=payload.notes
    )
    db.add(transaction)

    await db.commit()
    await db.refresh(wallet)

    return {
        "success": True,
        "message": f"Successfully settled {deposit_amount:.2f} cash for rider!",
        "newCashInHand": wallet.cashInHand
    }


@router.get("/orders")
async def get_admin_all_orders(
    status_filter: Optional[str] = None,
    limit: int = 50,
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all orders across system for Admin view.
    """
    stmt = select(Order).options(selectinload(Order.items), selectinload(Order.user), selectinload(Order.address))
    if status_filter:
        stmt = stmt.where(text(f"orders.status::text = '{status_filter}'"))
    stmt = stmt.order_by(desc(Order.createdAt)).limit(limit)

    res = await db.execute(stmt)
    orders = res.scalars().all()
    return orders


@router.get("/dashboard")
async def get_admin_dashboard(
    current_admin: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Get Admin dashboard overview statistics.
    """
    today_start = datetime.combine(date.today(), datetime.min.time())

    # Total orders today
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
        "timestamp": datetime.utcnow()
    }

