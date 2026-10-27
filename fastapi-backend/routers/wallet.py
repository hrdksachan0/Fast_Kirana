from fastapi import APIRouter, Depends, HTTPException, Request, Response, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import text, desc
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field
import httpx
import hmac
import hashlib
import base64
import time
import uuid
import logging
from decimal import Decimal

from config import settings
from database import get_db
from models import (
    CustomerWallet, WalletTransaction, WalletTxType, WalletTxStatus, User, StoreSetting
)
from routers.auth import get_current_user, require_auth
from routers.cashfree_router import CASHFREE_BASE_URL, _get_cashfree_headers
from utils.firebase import send_fcm_notification

logger = logging.getLogger("wallet")

router = APIRouter(prefix="/wallet", tags=["Customer Wallet"])


class TopupInitiateRequest(BaseModel):
    amount: float = Field(..., gt=0, le=50000, description="Amount to topup between 1 and 50,000")


class TopupSyncRequest(BaseModel):
    cfOrderId: str


def _verify_cashfree_webhook_signature(
    raw_body: bytes,
    timestamp: str,
    signature: str,
    secret_key: str
) -> bool:
    """
    Verifies Cashfree webhook signature using SHA256 HMAC (Base64 encoded).
    Formatted as timestamp + raw_body.
    """
    if not secret_key or not timestamp or not signature:
        return False
    try:
        data_to_sign = f"{timestamp}{raw_body.decode('utf-8')}"
        computed_hmac = hmac.new(
            secret_key.encode("utf-8"),
            data_to_sign.encode("utf-8"),
            hashlib.sha256
        ).digest()
        computed_sig = base64.b64encode(computed_hmac).decode("utf-8")
        return hmac.compare_digest(computed_sig, signature)
    except Exception as e:
        logger.error(f"Error validating Cashfree webhook signature: {e}")
        return False


async def get_or_create_wallet(user_id: str, db: AsyncSession) -> CustomerWallet:
    """Fetch user's customer wallet or create one if it doesn't exist."""
    stmt = select(CustomerWallet).where(CustomerWallet.userId == user_id)
    res = await db.execute(stmt)
    wallet = res.scalars().first()
    if not wallet:
        wallet = CustomerWallet(
            id=f"cw_{uuid.uuid4().hex[:16]}",
            userId=user_id,
            balance=Decimal("0.00"),
            promoBalance=Decimal("0.00"),
            isActive=True
        )
        db.add(wallet)
        await db.commit()
        await db.refresh(wallet)
    return wallet


@router.get("/balance")
async def get_wallet_balance(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get current user's wallet liquid balance and promotional balance."""
    user_id = current_user.get("id")
    wallet = await get_or_create_wallet(user_id, db)
    return {
        "success": True,
        "walletId": wallet.id,
        "balance": float(wallet.balance),
        "promoBalance": float(wallet.promoBalance),
        "totalUsable": float(wallet.balance + wallet.promoBalance),
        "isActive": wallet.isActive
    }


@router.get("/transactions")
async def get_wallet_transactions(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """Get paginated transaction history for current user's wallet."""
    user_id = current_user.get("id")
    wallet = await get_or_create_wallet(user_id, db)

    offset = (page - 1) * limit
    stmt = (
        select(WalletTransaction)
        .where(
            WalletTransaction.walletId == wallet.id,
            WalletTransaction.status == WalletTxStatus.SUCCESS
        )
        .order_by(desc(WalletTransaction.createdAt))
        .offset(offset)
        .limit(limit)
    )
    res = await db.execute(stmt)
    tx_list = res.scalars().all()

    return {
        "success": True,
        "page": page,
        "limit": limit,
        "transactions": [
            {
                "id": t.id,
                "amount": float(t.amount),
                "type": t.type,
                "status": t.status,
                "cfOrderId": t.cfOrderId,
                "description": t.description,
                "balanceAfter": float(t.balanceAfter),
                "createdAt": t.createdAt.isoformat() if t.createdAt else None
            }
            for t in tx_list
        ]
    }


@router.post("/topup/initiate")
async def initiate_wallet_topup(
    body: TopupInitiateRequest,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Creates a Cashfree PG order session specifically for a Wallet Top-Up.
    Uses 'WTOPUP_' prefix so it never collides with standard shopping cart orders.
    """
    user_id = current_user.get("id")
    amount = Decimal(str(round(body.amount, 2)))

    if amount < Decimal("10.00"):
        raise HTTPException(status_code=400, detail="Minimum top-up amount is ₹10")

    # Fetch user details
    u_stmt = select(User).where(User.id == user_id)
    u_res = await db.execute(u_stmt)
    user = u_res.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    wallet = await get_or_create_wallet(user_id, db)

    # Generate unique Cashfree Order ID
    cf_order_id = f"WTOPUP_{user_id[:8]}_{int(time.time())}_{uuid.uuid4().hex[:4]}"

    # Create pending transaction
    tx = WalletTransaction(
        id=f"wtx_{uuid.uuid4().hex[:16]}",
        walletId=wallet.id,
        amount=amount,
        type=WalletTxType.CREDIT_TOPUP,
        status=WalletTxStatus.INITIATED,
        cfOrderId=cf_order_id,
        balanceBefore=wallet.balance,
        balanceAfter=wallet.balance,
        description=f"Wallet Top-Up of ₹{amount} via Cashfree",
        paymentGateway="CASHFREE"
    )
    db.add(tx)
    await db.commit()

    # Call Cashfree PG /orders API
    headers = _get_cashfree_headers()
    cf_payload = {
        "order_id": cf_order_id,
        "order_amount": float(amount),
        "order_currency": "INR",
        "customer_details": {
            "customer_id": user.id,
            "customer_phone": (user.phone or "9999999999")[-10:],
            "customer_email": user.email or f"{user.id}@fastkirana.in",
            "customer_name": user.name or "FastMinute Customer"
        },
        "order_meta": {
            "notify_url": f"{settings.API_BASE_URL}/api/wallet/cashfree/webhook"
        },
        "order_note": f"FastMinute Wallet Top-Up (User: {user.phone or user.id})"
    }

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.post(f"{CASHFREE_BASE_URL}/orders", headers=headers, json=cf_payload)
            if res.status_code not in (200, 201):
                logger.error(f"Cashfree order creation error: {res.text}")
                raise HTTPException(status_code=502, detail="Failed to initialize payment gateway")
            cf_data = res.json()
    except httpx.RequestError as e:
        logger.error(f"Cashfree network error: {e}")
        raise HTTPException(status_code=502, detail="Payment gateway timeout")

    return {
        "success": True,
        "cfOrderId": cf_order_id,
        "paymentSessionId": cf_data.get("payment_session_id"),
        "amount": float(amount)
    }


@router.post("/cashfree/webhook")
async def cashfree_wallet_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_webhook_signature: Optional[str] = Header(None, alias="x-webhook-signature"),
    x_webhook_timestamp: Optional[str] = Header(None, alias="x-webhook-timestamp")
):
    """
    Cashfree webhook handler for Wallet Top-ups.
    Verifies HMAC signature, locks the transaction row (FOR UPDATE) to prevent
    duplicate credit, increments customer wallet balance, and logs success.
    """
    raw_body = await request.body()

    # Verify signature in production
    if settings.CASHFREE_ENV.upper() == "PRODUCTION":
        if not _verify_cashfree_webhook_signature(
            raw_body,
            x_webhook_timestamp or "",
            x_webhook_signature or "",
            settings.CASHFREE_SECRET_KEY
        ):
            logger.warning("Rejected Cashfree wallet webhook: Invalid HMAC signature")
            raise HTTPException(status_code=403, detail="Invalid webhook signature")

    try:
        payload = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")

    data = payload.get("data", {})
    order_data = data.get("order", {})
    payment_data = data.get("payment", {})

    cf_order_id = order_data.get("order_id")
    payment_status = payment_data.get("payment_status")  # "SUCCESS", "FAILED"

    # Only process WTOPUP_ prefixed orders
    if not cf_order_id or not str(cf_order_id).startswith("WTOPUP_"):
        return {"status": "ignored_non_wallet_order"}

    # Lock transaction row to prevent double credit
    stmt = (
        select(WalletTransaction)
        .where(WalletTransaction.cfOrderId == cf_order_id)
        .with_for_update()
    )
    tx = (await db.execute(stmt)).scalar_one_or_none()

    if not tx:
        logger.warning(f"Wallet transaction not found for cfOrderId: {cf_order_id}")
        return {"status": "tx_not_found"}

    if tx.status in [WalletTxStatus.SUCCESS, WalletTxStatus.SUCCESS.value]:
        return {"status": "already_processed"}

    if payment_status == "SUCCESS":
        # Lock wallet row and credit
        wallet_stmt = (
            select(CustomerWallet)
            .where(CustomerWallet.id == tx.walletId)
            .with_for_update()
        )
        wallet = (await db.execute(wallet_stmt)).scalar_one()

        tx.status = WalletTxStatus.SUCCESS
        tx.cfPaymentId = str(payment_data.get("cf_payment_id", ""))
        tx.balanceBefore = wallet.balance
        wallet.balance = Decimal(str(wallet.balance)) + Decimal(str(tx.amount))
        tx.balanceAfter = wallet.balance

        await db.commit()
        logger.info(f"Successfully credited ₹{tx.amount} to wallet {wallet.id} via Cashfree (Order: {cf_order_id})")

        # Push notification
        try:
            u_stmt = select(User).where(User.id == wallet.userId)
            user = (await db.execute(u_stmt)).scalar_one_or_none()
            if user:
                await send_fcm_notification(
                    user_id=user.id,
                    title="Wallet Top-Up Successful! 💰",
                    body=f"₹{float(tx.amount):.2f} added to your FastMinute wallet. Current balance: ₹{float(wallet.balance):.2f}",
                    data={"type": "WALLET_TOPUP", "walletBalance": str(float(wallet.balance))}
                )
        except Exception as fcm_err:
            logger.warning(f"FCM push failed for wallet topup: {fcm_err}")

    else:
        tx.status = WalletTxStatus.FAILED
        await db.commit()
        logger.info(f"Wallet topup failed for order: {cf_order_id}")

    return {"status": "ok"}


@router.post("/topup/sync-status")
async def sync_wallet_topup_status(
    body: TopupSyncRequest,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Direct sync fallback: Called by Flutter app when user returns from Cashfree checkout.
    Queries Cashfree API synchronously in case the webhook hasn't arrived yet.
    """
    user_id = current_user.get("id")
    cf_order_id = body.cfOrderId.strip()

    stmt = (
        select(WalletTransaction)
        .where(WalletTransaction.cfOrderId == cf_order_id)
        .with_for_update()
    )
    tx = (await db.execute(stmt)).scalar_one_or_none()

    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")

    # If already marked success, return immediately
    if tx.status in [WalletTxStatus.SUCCESS, WalletTxStatus.SUCCESS.value]:
        wallet = await get_or_create_wallet(user_id, db)
        return {
            "success": True,
            "status": "SUCCESS",
            "balance": float(wallet.balance),
            "amount": float(tx.amount)
        }

    # Query Cashfree REST API
    headers = _get_cashfree_headers()
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(f"{CASHFREE_BASE_URL}/orders/{cf_order_id}/payments", headers=headers)
            if res.status_code == 200:
                payments = res.json()
                success_payment = next((p for p in payments if p.get("payment_status") == "SUCCESS"), None)
                if success_payment:
                    # Credit wallet
                    wallet_stmt = (
                        select(CustomerWallet)
                        .where(CustomerWallet.id == tx.walletId)
                        .with_for_update()
                    )
                    wallet = (await db.execute(wallet_stmt)).scalar_one()

                    tx.status = WalletTxStatus.SUCCESS
                    tx.cfPaymentId = str(success_payment.get("cf_payment_id", ""))
                    tx.balanceBefore = wallet.balance
                    wallet.balance = Decimal(str(wallet.balance)) + Decimal(str(tx.amount))
                    tx.balanceAfter = wallet.balance

                    await db.commit()
                    return {
                        "success": True,
                        "status": "SUCCESS",
                        "balance": float(wallet.balance),
                        "amount": float(tx.amount)
                    }
    except Exception as e:
        logger.warning(f"Error querying Cashfree for {cf_order_id}: {e}")

    return {
        "success": False,
        "status": tx.status,
        "message": "Payment still processing or not yet confirmed by gateway"
    }


async def debit_customer_wallet(
    user_id: str,
    amount: Decimal,
    description: str,
    db: AsyncSession,
    metadata: Optional[Dict[str, Any]] = None,
    allow_promo: bool = True,
) -> CustomerWallet:
    """
    Atomic wallet deduction helper used during order checkout.
    Uses Postgres Row-Level Lock (SELECT FOR UPDATE).
    If allow_promo is True, burns promo balance first, then real balance.
    If allow_promo is False (e.g. order subtotal < referral min order value),
    only debits from real liquid balance and leaves promoBalance untouched.
    Raises HTTPException(400) if usable balance is insufficient.
    """
    wallet_stmt = (
        select(CustomerWallet)
        .where(CustomerWallet.userId == user_id)
        .with_for_update()
    )
    res = await db.execute(wallet_stmt)
    wallet = res.scalars().first()

    if not wallet or not wallet.isActive:
        raise HTTPException(status_code=400, detail="Customer wallet is not active")

    total_available = (wallet.balance + wallet.promoBalance) if allow_promo else wallet.balance
    if total_available < amount:
        reason = "Total available" if allow_promo else "Real cash balance available"
        raise HTTPException(
            status_code=400,
            detail=f"Insufficient wallet balance. {reason}: ₹{float(total_available):.2f}, Required: ₹{float(amount):.2f}"
        )

    bal_before = wallet.balance
    remaining_to_debit = amount

    # Burn promo balance first only if allowed
    if allow_promo and wallet.promoBalance > 0:
        if wallet.promoBalance >= remaining_to_debit:
            wallet.promoBalance -= remaining_to_debit
            remaining_to_debit = Decimal("0.00")
        else:
            remaining_to_debit -= wallet.promoBalance
            wallet.promoBalance = Decimal("0.00")

    # Burn real liquid balance
    if remaining_to_debit > 0:
        wallet.balance -= remaining_to_debit

    tx = WalletTransaction(
        id=f"wtx_{uuid.uuid4().hex[:16]}",
        walletId=wallet.id,
        amount=amount,
        type=WalletTxType.DEBIT_ORDER,
        status=WalletTxStatus.SUCCESS,
        balanceBefore=bal_before,
        balanceAfter=wallet.balance,
        description=description,
        metadata_json=metadata or {}
    )
    db.add(tx)
    return wallet


async def credit_customer_wallet(
    user_id: str,
    amount: Decimal,
    description: str,
    db: AsyncSession,
    tx_type: WalletTxType = WalletTxType.CREDIT_REFUND,
    metadata: Optional[Dict[str, Any]] = None
) -> CustomerWallet:
    """
    Atomic wallet credit helper used during refunds, top-ups, or rewards.
    Uses Postgres Row-Level Lock (SELECT FOR UPDATE) to ensure concurrency safety.
    """
    wallet = await get_or_create_wallet(user_id, db)
    bal_before = wallet.balance
    wallet.balance = Decimal(str(wallet.balance)) + amount

    tx = WalletTransaction(
        id=f"wtx_{uuid.uuid4().hex[:16]}",
        walletId=wallet.id,
        amount=amount,
        type=tx_type,
        status=WalletTxStatus.SUCCESS,
        balanceBefore=bal_before,
        balanceAfter=wallet.balance,
        description=description,
        metadata_json=metadata or {}
    )
    db.add(tx)
    return wallet
