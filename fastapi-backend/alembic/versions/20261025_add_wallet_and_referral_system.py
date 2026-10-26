"""Add Customer Wallet, WalletTransaction, Referral tables and User referral columns

Revision ID: a3f8b2c1d4e5
Revises: 47db795a0c6a
Create Date: 2026-10-25 20:50:00.000000
"""
from alembic import op
import sqlalchemy as sa
import uuid
import random
import string

# revision identifiers, used by Alembic.
revision = 'a3f8b2c1d4e5'
down_revision = '47db795a0c6a'
branch_labels = None
depends_on = None


def _generate_referral_code():
    """Generate a unique referral code like FAST1234"""
    digits = ''.join(random.choices(string.digits, k=4))
    return f"FAST{digits}"


def upgrade() -> None:
    # ── 1. Add referral columns to users table ──
    op.add_column('users', sa.Column('referralCode', sa.String(), nullable=True))
    op.add_column('users', sa.Column('referredById', sa.String(), nullable=True))
    op.create_unique_constraint('uq_users_referralCode', 'users', ['referralCode'])
    op.create_foreign_key(
        'fk_users_referredById', 'users', 'users',
        ['referredById'], ['id'],
        ondelete='SET NULL'
    )

    # ── 2. Create customer_wallets table ──
    op.create_table(
        'customer_wallets',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('userId', sa.String(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('balance', sa.Numeric(12, 2), nullable=False, server_default='0.00'),
        sa.Column('promoBalance', sa.Numeric(12, 2), nullable=False, server_default='0.00'),
        sa.Column('isActive', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('createdAt', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updatedAt', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint('balance >= 0', name='positive_wallet_balance'),
        sa.CheckConstraint('"promoBalance" >= 0', name='positive_promo_balance'),
    )

    # ── 3. Create wallet_transactions table ──
    op.create_table(
        'wallet_transactions',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('walletId', sa.String(), sa.ForeignKey('customer_wallets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('amount', sa.Numeric(12, 2), nullable=False),
        sa.Column('type', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False, server_default='INITIATED'),
        sa.Column('cfOrderId', sa.String(), nullable=True, unique=True),
        sa.Column('cfPaymentId', sa.String(), nullable=True),
        sa.Column('paymentGateway', sa.String(), nullable=False, server_default='CASHFREE'),
        sa.Column('balanceBefore', sa.Numeric(12, 2), nullable=False, server_default='0.00'),
        sa.Column('balanceAfter', sa.Numeric(12, 2), nullable=False, server_default='0.00'),
        sa.Column('description', sa.String(), nullable=False),
        sa.Column('metadata', sa.JSON(), nullable=True),
        sa.Column('createdAt', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updatedAt', sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_wallet_tx_wallet_created', 'wallet_transactions', ['walletId', 'createdAt'])
    op.create_index('ix_wallet_tx_cf_order', 'wallet_transactions', ['cfOrderId'])

    # ── 4. Create referrals table ──
    op.create_table(
        'referrals',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('referrerId', sa.String(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('refereeId', sa.String(), sa.ForeignKey('users.id'), nullable=False, unique=True),
        sa.Column('codeUsed', sa.String(), nullable=False),
        sa.Column('status', sa.String(), nullable=False, server_default='PENDING'),
        sa.Column('referrerReward', sa.Numeric(12, 2), nullable=False, server_default='0.00'),
        sa.Column('refereeDiscount', sa.Numeric(12, 2), nullable=False, server_default='0.00'),
        sa.Column('qualifyingOrderId', sa.String(), sa.ForeignKey('orders.id'), nullable=True, unique=True),
        sa.Column('rewardCreditedAt', sa.DateTime(), nullable=True),
        sa.Column('deviceUuid', sa.String(), nullable=True),
        sa.Column('ipAddress', sa.String(), nullable=True),
        sa.Column('createdAt', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updatedAt', sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_referral_referrer_status', 'referrals', ['referrerId', 'status'])
    op.create_index('ix_referral_code', 'referrals', ['codeUsed'])

    # ── 5. Backfill: Generate unique referral codes for all existing users ──
    conn = op.get_bind()
    users = conn.execute(sa.text("SELECT id FROM users WHERE \"referralCode\" IS NULL")).fetchall()
    used_codes = set()
    for (user_id,) in users:
        code = _generate_referral_code()
        while code in used_codes:
            code = _generate_referral_code()
        used_codes.add(code)
        conn.execute(
            sa.text('UPDATE users SET "referralCode" = :code WHERE id = :uid'),
            {"code": code, "uid": user_id}
        )

    # ── 6. Backfill: Create empty CustomerWallet for all existing users ──
    users_for_wallet = conn.execute(sa.text(
        "SELECT id FROM users WHERE id NOT IN (SELECT \"userId\" FROM customer_wallets)"
    )).fetchall()
    for (user_id,) in users_for_wallet:
        wallet_id = f"cw_{uuid.uuid4().hex[:16]}"
        conn.execute(
            sa.text(
                'INSERT INTO customer_wallets (id, "userId", balance, "promoBalance", "isActive", "createdAt", "updatedAt") '
                "VALUES (:id, :uid, 0.00, 0.00, true, NOW(), NOW())"
            ),
            {"id": wallet_id, "uid": user_id}
        )


def downgrade() -> None:
    op.drop_table('referrals')
    op.drop_table('wallet_transactions')
    op.drop_table('customer_wallets')
    op.drop_constraint('fk_users_referredById', 'users', type_='foreignkey')
    op.drop_constraint('uq_users_referralCode', 'users', type_='unique')
    op.drop_column('users', 'referredById')
    op.drop_column('users', 'referralCode')
