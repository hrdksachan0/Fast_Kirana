import asyncio
import json
import os
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Product, StoreInventory
from sqlalchemy import select

BACKUP_PATH = 'd:/Fastkirana/fastapi-backend/backups/temporarily_closed_stock_backup.json'

async def restore_categories():
    if not os.path.exists(BACKUP_PATH):
        print(f"Error: Backup file not found at {BACKUP_PATH}")
        return

    with open(BACKUP_PATH, 'r', encoding='utf-8') as f:
        backup_data = json.load(f)

    async with AsyncSessionLocal() as session:
        restored_count = 0
        for product_id, data in backup_data.items():
            res = await session.execute(
                select(Product).where(Product.id == product_id)
            )
            p = res.scalar_one_or_none()
            if not p:
                continue

            p.stock = data.get("product_stock", 0)
            p.isAvailable = data.get("product_isAvailable", True)
            if data.get("variants") is not None:
                p.variants = data["variants"]

            # Restore store inventories
            for inv_data in data.get("inventory", []):
                store_id = inv_data["storeId"]
                inv_res = await session.execute(
                    select(StoreInventory).where(
                        StoreInventory.productId == product_id,
                        StoreInventory.storeId == store_id
                    )
                )
                inv = inv_res.scalar_one_or_none()
                if inv:
                    inv.stock = inv_data.get("stock", 0)
                    inv.isAvailable = inv_data.get("isAvailable", True)

            restored_count += 1

        await session.commit()
        print(f"Successfully restored stock for {restored_count} products.")

if __name__ == '__main__':
    asyncio.run(restore_categories())
