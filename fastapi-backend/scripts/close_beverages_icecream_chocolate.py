import asyncio
import os
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Product, StoreInventory
from sqlalchemy import select, update

TARGET_CATEGORIES = ['CAT-108', 'CAT-105', 'SUB-115-03']

async def close_categories():
    async with AsyncSessionLocal() as session:
        # 1. Fetch all products in target categories
        res = await session.execute(
            select(Product).where(Product.categoryId.in_(TARGET_CATEGORIES))
        )
        products = res.scalars().all()
        print(f"Setting {len(products)} products to Out of Stock across {TARGET_CATEGORIES}...")

        updated_count = 0
        for p in products:
            p.stock = 0
            p.isAvailable = True # Visible but 0 stock = Out of Stock

            # If product has variants, set stock of all variants to 0
            if p.variants:
                updated_variants = []
                for v in p.variants:
                    v_copy = dict(v)
                    v_copy['stock'] = 0
                    updated_variants.append(v_copy)
                p.variants = updated_variants

            # 2. Update StoreInventory for this product
            inv_res = await session.execute(
                select(StoreInventory).where(StoreInventory.productId == p.id)
            )
            invs = inv_res.scalars().all()
            for inv in invs:
                inv.stock = 0
                if inv.storeId == 'hub-209206':
                    inv.isAvailable = True # Keep assorted so it shows as Out of Stock
                else:
                    inv.isAvailable = False

            updated_count += 1

        await session.commit()
        print(f"Successfully marked {updated_count} products as Out of Stock (Temporarily Closed).")

if __name__ == '__main__':
    asyncio.run(close_categories())
