import sys
sys.path.insert(0, ".")
from database import engine
import asyncio
from sqlalchemy import text

indexes = [
    'CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id ON "cart_items"("cartId");',
    'CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON "cart_items"("productId");',
    'CREATE INDEX IF NOT EXISTS idx_orders_address_id ON "orders"("addressId");',
    'CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON "product_images"("productId");',
    'CREATE INDEX IF NOT EXISTS idx_store_inventories_product_id ON "store_inventories"("productId");',
    'CREATE INDEX IF NOT EXISTS idx_store_inventories_store_id ON "store_inventories"("storeId");',
    'CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON "wallet_transactions"("walletId");',
    'CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON "referrals"("referrerId");',
    'CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON "reviews"("userId");',
    'CREATE INDEX IF NOT EXISTS idx_restaurant_reviews_user_id ON "restaurant_reviews"("userId");',
    'CREATE INDEX IF NOT EXISTS idx_wishlist_items_product_id ON "wishlist_items"("productId");',
    'CREATE INDEX IF NOT EXISTS idx_users_referred_by_id ON "users"("referredById");',
    'CREATE INDEX IF NOT EXISTS idx_users_assigned_store_id ON "users"("assignedStoreId");'
]

async def apply_indexes():
    async with engine.begin() as conn:
        for idx in indexes:
            name = idx.split()[5]
            await conn.execute(text(idx))
            print(f"Applied: {name}")
    print("ALL 13 PERFORMANCE INDEXES APPLIED TO SUPABASE SUCCESSFULLY!")

if __name__ == "__main__":
    asyncio.run(apply_indexes())
