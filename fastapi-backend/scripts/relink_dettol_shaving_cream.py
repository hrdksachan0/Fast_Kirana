import asyncio
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Product, StoreInventory
from sqlalchemy import select

BIDIT_VENDOR_ID = 'cmty7royc000004jro9fnjzzw'
BIDIT_VENDOR_NAME = 'Bidit grocery'
PRODUCT_READABLE_ID = 200683

async def relink_dettol_shaving_cream():
    async with AsyncSessionLocal() as session:
        # Find product by readableId 200683
        res = await session.execute(
            select(Product).where(Product.readableId == PRODUCT_READABLE_ID)
        )
        p = res.scalar_one_or_none()
        if not p:
            print(f"Product {PRODUCT_READABLE_ID} not found!")
            return

        print(f"Found Product: {p.name} (ID: {p.id}, ReadableId: {p.readableId})")
        p.vendorId = BIDIT_VENDOR_ID
        p.vendor = BIDIT_VENDOR_NAME

        # Also update StoreInventory
        inv_res = await session.execute(
            select(StoreInventory).where(StoreInventory.productId == p.id)
        )
        invs = inv_res.scalars().all()
        for inv in invs:
            inv.vendorId = BIDIT_VENDOR_ID
            print(f"Updated StoreInventory: storeId={inv.storeId} -> vendorId={inv.vendorId}")

        await session.commit()
        print(f"\nSuccessfully re-linked '{p.name}' to vendor '{BIDIT_VENDOR_NAME}' ({BIDIT_VENDOR_ID})!")

if __name__ == '__main__':
    asyncio.run(relink_dettol_shaving_cream())
