from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, desc, and_
from typing import Optional, Dict, Any
from decimal import Decimal
import random
import string
import uuid
import logging

from database import get_db
from models import User, Referral, ReferralStatus, CustomerWallet, WalletTransaction, WalletTxType, WalletTxStatus, Order, OrderStatus, StoreSetting
from routers.auth import require_auth
from routers.wallet import get_or_create_wallet
from utils.firebase import send_fcm_notification

logger = logging.getLogger("referral")

router = APIRouter(prefix="/referral", tags=["Refer & Earn"])


class ApplyReferralRequest(BaseModel):
    referralCode: str


def generate_unique_referral_code() -> str:
    """Generate a clean referral code like FAST9872"""
    digits = ''.join(random.choices(string.digits, k=4))
    return f"FAST{digits}"


async def get_referral_settings(db: AsyncSession) -> Dict[str, str]:
    """Fetch referral program settings from StoreSetting with defaults."""
    from routers.settings import DEFAULT_SETTINGS
    stmt = select(StoreSetting).where(StoreSetting.key.like("referral_%"))
    res = await db.execute(stmt)
    settings_rows = res.scalars().all()
    
    config = {
        "enabled": DEFAULT_SETTINGS.get("referral_enabled", "true"),
        "referrer_reward": DEFAULT_SETTINGS.get("referral_referrer_reward", "100"),
        "referee_discount": DEFAULT_SETTINGS.get("referral_referee_discount", "50"),
        "min_order_value": DEFAULT_SETTINGS.get("referral_min_order_value", "199"),
        "monthly_cap": DEFAULT_SETTINGS.get("referral_monthly_cap", "1500"),
        "whatsapp_message": DEFAULT_SETTINGS.get("referral_whatsapp_message", "🛒 FastMinute se grocery order karo aur mere code {CODE} se paao ₹{DISCOUNT} OFF!\n\n📲 Download App on Play Store:\nhttps://play.google.com/store/apps/details?id=com.fastkirana.app\n\n🌐 Ya Order karo: https://fastkirana.in"),
    }
    
    for row in settings_rows:
        if row.key == "referral_enabled":
            config["enabled"] = row.value
        elif row.key == "referral_referrer_reward":
            config["referrer_reward"] = row.value
        elif row.key == "referral_referee_discount":
            config["referee_discount"] = row.value
        elif row.key == "referral_min_order_value":
            config["min_order_value"] = row.value
        elif row.key == "referral_monthly_cap":
            config["monthly_cap"] = row.value
        elif row.key == "referral_whatsapp_message":
            msg = row.value
            if "Fastkirana" in msg:
                msg = msg.replace("Fastkirana", "FastMinute")
            if "play.google.com" not in msg:
                msg = (
                    f"🛒 FastMinute se grocery order karo aur mere code {{CODE}} se paao ₹{{DISCOUNT}} OFF!\n\n"
                    f"📲 Download App on Play Store:\nhttps://play.google.com/store/apps/details?id=com.fastkirana.app\n\n"
                    f"🌐 Ya Order karo: https://fastkirana.in"
                )
            config["whatsapp_message"] = msg

    return config


@router.get("/my-code")
async def get_my_referral_code(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's referral code.
    If the user doesn't have one yet, auto-generates and persists it.
    """
    user_id = current_user.get("id")
    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalars().first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not user.referralCode:
        # Generate unique code
        code = generate_unique_referral_code()
        # Ensure uniqueness
        while True:
            chk = await db.execute(select(User).where(User.referralCode == code))
            if not chk.scalars().first():
                break
            code = generate_unique_referral_code()
        
        user.referralCode = code
        await db.commit()
        await db.refresh(user)

    config = await get_referral_settings(db)
    app_link = "https://fastkirana.in"
    play_store_link = "https://play.google.com/store/apps/details?id=com.fastkirana.app"
    discount_val = config.get("referee_discount", "50")

    share_text = (
        f"🛒 FastMinute Grocery se order karo aur mere referral code *{user.referralCode}* se paao ₹{discount_val} OFF!\n\n"
        f"📲 Download Android App:\n{play_store_link}\n\n"
        f"🌐 Ya Online Order karo: {app_link}\n\n"
        f"Referral Code: *{user.referralCode}*"
    )

    return {
        "success": True,
        "referralCode": user.referralCode,
        "shareLink": play_store_link,
        "webLink": f"{app_link}?ref={user.referralCode}",
        "whatsappShareText": share_text,
        "referrerReward": float(config["referrer_reward"]),
        "refereeDiscount": float(config["referee_discount"]),
        "minOrderValue": float(config["min_order_value"]),
        "isEnabled": config["enabled"].lower() == "true"
    }


@router.post("/apply")
async def apply_referral_code(
    body: ApplyReferralRequest,
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Apply a friend's referral code.
    Validations:
    - Referral program is enabled in admin settings
    - Code is valid and exists in users table
    - Cannot refer self (user cannot enter their own code or phone match)
    - User has not already used a referral code
    - User has not already placed a delivered order (first order only)
    """
    user_id = current_user.get("id")
    stmt = select(User).where(User.id == user_id)
    res = await db.execute(stmt)
    user = res.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    config = await get_referral_settings(db)
    if config["enabled"].lower() != "true":
        raise HTTPException(status_code=400, detail="Referral program is currently unavailable")

    clean_code = body.referralCode.strip().upper()
    if not clean_code or len(clean_code) < 3:
        raise HTTPException(status_code=400, detail="Please enter a valid referral code")

    # Find referrer
    ref_stmt = select(User).where(User.referralCode == clean_code)
    referrer = (await db.execute(ref_stmt)).scalars().first()
    if not referrer:
        raise HTTPException(status_code=400, detail="Invalid referral code. Please check and try again.")

    if referrer.id == user.id or (referrer.phone and user.phone and referrer.phone == user.phone):
        raise HTTPException(status_code=400, detail="You cannot apply your own referral code")

    # Check if already referred
    existing_ref = (await db.execute(
        select(Referral).where(Referral.refereeId == user.id)
    )).scalars().first()
    if existing_ref:
        raise HTTPException(status_code=400, detail="You have already applied a referral code")

    # Check if user already placed delivered orders (only first-time customers are eligible)
    delivered_orders = (await db.execute(
        select(func.count(Order.id)).where(
            Order.userId == user.id,
            Order.status == OrderStatus.DELIVERED
        )
    )).scalar() or 0
    if delivered_orders > 0:
        raise HTTPException(status_code=400, detail="Referral code can only be used on your first order")

    # Link referral
    user.referredById = referrer.id
    referee_discount = Decimal(config["referee_discount"])

    new_referral = Referral(
        id=f"ref_{uuid.uuid4().hex[:16]}",
        referrerId=referrer.id,
        refereeId=user.id,
        codeUsed=clean_code,
        status=ReferralStatus.PENDING,
        refereeDiscount=referee_discount,
        referrerReward=Decimal(config["referrer_reward"]),
    )
    db.add(new_referral)

    await db.commit()
    logger.info(f"Referral code {clean_code} applied by user {user.id} (referred by {referrer.id})")

    return {
        "success": True,
        "message": f"🎉 Referral code applied! You unlocked ₹{int(referee_discount)} OFF on your first order.",
        "discountAmount": float(referee_discount),
        "codeUsed": clean_code
    }


@router.get("/stats")
async def get_referral_stats(
    current_user: dict = Depends(require_auth),
    db: AsyncSession = Depends(get_db)
):
    """
    Get live referral summary:
    - total friends invited (PENDING + COMPLETED)
    - successful referrals (COMPLETED)
    - total wallet cash earned via referrals
    """
    user_id = current_user.get("id")
    
    # Total count
    count_stmt = select(func.count(Referral.id)).where(Referral.referrerId == user_id)
    total_invited = (await db.execute(count_stmt)).scalar() or 0

    # Completed count
    completed_stmt = select(func.count(Referral.id)).where(
        Referral.referrerId == user_id,
        Referral.status == ReferralStatus.COMPLETED
    )
    completed_count = (await db.execute(completed_stmt)).scalar() or 0

    # Total earned sum
    earned_stmt = select(func.coalesce(func.sum(Referral.referrerReward), 0.0)).where(
        Referral.referrerId == user_id,
        Referral.status == ReferralStatus.COMPLETED
    )
    total_earned = (await db.execute(earned_stmt)).scalar() or 0.0

    # Recent list
    recent_stmt = (
        select(Referral, User)
        .join(User, Referral.refereeId == User.id)
        .where(Referral.referrerId == user_id)
        .order_by(desc(Referral.createdAt))
        .limit(15)
    )
    recent_res = await db.execute(recent_stmt)
    records = recent_res.all()

    return {
        "success": True,
        "totalInvited": total_invited,
        "completedReferrals": completed_count,
        "totalEarned": float(total_earned),
        "recentReferrals": [
            {
                "id": ref.id,
                "friendName": (u.name or "Friend") if u else "Friend",
                "friendPhone": f"******{(u.phone or '0000')[-4:]}" if u and u.phone else "******",
                "status": ref.status.value if hasattr(ref.status, "value") else str(ref.status),
                "reward": float(ref.referrerReward),
                "date": ref.createdAt.isoformat() if ref.createdAt else None
            }
            for ref, u in records
        ]
    }


async def process_referral_reward_on_delivery(order: Order, db: AsyncSession):
    """
    Invoked when an Order transitions to DELIVERED.
    Checks if the order belongs to a referred user's FIRST DELIVERED order
    meeting the admin-configured min order value.
    If valid, awards the referrer reward directly into the referrer's wallet!
    """
    try:
        # 1. Fetch Referral record for this user
        stmt = (
            select(Referral)
            .where(
                Referral.refereeId == order.userId,
                Referral.status.in_([ReferralStatus.PENDING, ReferralStatus.FIRST_ORDER_PLACED])
            )
            .with_for_update()
        )
        referral = (await db.execute(stmt)).scalar_one_or_none()
        if not referral:
            return  # User wasn't referred, or referral already completed/flagged

        # 2. Check admin referral settings
        config = await get_referral_settings(db)
        if config["enabled"].lower() != "true":
            logger.info("Referral reward skipped: referral program is disabled in settings")
            return

        min_mov = Decimal(config["min_order_value"])
        order_total = Decimal(str(order.total or 0.0))
        if order_total < min_mov:
            logger.info(f"Referral reward skipped: Order total ₹{order_total} < MOV ₹{min_mov}")
            return

        reward_amount = Decimal(config["referrer_reward"])

        # 3. Monthly cap check on referrer
        monthly_cap = Decimal(config["monthly_cap"])
        # Calculate referrer's earnings this month
        month_start = order.deliveredAt.replace(day=1, hour=0, minute=0, second=0, microsecond=0) if order.deliveredAt else None
        if month_start:
            earnings_stmt = select(func.coalesce(func.sum(Referral.referrerReward), 0.0)).where(
                Referral.referrerId == referral.referrerId,
                Referral.status == ReferralStatus.COMPLETED,
                Referral.rewardCreditedAt >= month_start
            )
            current_month_earnings = Decimal(str((await db.execute(earnings_stmt)).scalar() or 0.0))
            if current_month_earnings >= monthly_cap:
                logger.info(f"Referral reward capped: Referrer reached monthly limit ₹{monthly_cap}")
                referral.status = ReferralStatus.COMPLETED
                referral.referrerReward = Decimal("0.00")
                await db.commit()
                return

        # 4. Credit Referrer Wallet
        referrer_wallet = await get_or_create_wallet(referral.referrerId, db)
        bal_before = referrer_wallet.balance
        referrer_wallet.balance = Decimal(str(referrer_wallet.balance)) + reward_amount

        # Log Wallet Transaction
        tx = WalletTransaction(
            id=f"wtx_{uuid.uuid4().hex[:16]}",
            walletId=referrer_wallet.id,
            amount=reward_amount,
            type=WalletTxType.CREDIT_REFERRAL,
            status=WalletTxStatus.SUCCESS,
            balanceBefore=bal_before,
            balanceAfter=referrer_wallet.balance,
            description=f"Referral reward: friend completed their first order! 🎉",
            metadata_json={"orderId": order.id, "refereeId": order.userId}
        )
        db.add(tx)

        # Update Referral record
        referral.status = ReferralStatus.COMPLETED
        referral.referrerReward = reward_amount
        referral.qualifyingOrderId = order.id
        referral.rewardCreditedAt = order.deliveredAt

        await db.commit()
        logger.info(f"Credited referral bonus of ₹{reward_amount} to referrer {referral.referrerId} for order {order.id}")

        # Send push notification to Referrer
        try:
            await send_fcm_notification(
                user_id=referral.referrerId,
                title="Referral Cash Earned! 🎁",
                body=f"Your friend just completed their first order! ₹{float(reward_amount):.2f} has been added to your FastMinute wallet.",
                data={"type": "REFERRAL_REWARD", "amount": str(float(reward_amount))}
            )
        except Exception as fcm_err:
            logger.warning(f"FCM push notification failed for referral bonus: {fcm_err}")

    except Exception as e:
        logger.error(f"Error processing referral reward for order {order.id}: {e}", exc_info=True)
