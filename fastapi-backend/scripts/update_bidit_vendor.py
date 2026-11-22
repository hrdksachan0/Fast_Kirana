import asyncio
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Product, StoreInventory, Vendor
from sqlalchemy import select

BIDIT_VENDOR_ID = 'cmty7royc000004jro9fnjzzw'
BIDIT_VENDOR_NAME = 'Bidit grocery'
SEVAI_ID = 'aa61c67f-ab41-439d-9905-a3cf907b9dac'

async def update_vendor_links():
    async with AsyncSessionLocal() as session:
        # 1. Delink all Dettol products from Bidit Grocery
        d_res = await session.execute(
            select(Product).where(Product.name.ilike('%dettol%'))
        )
        dettol_prods = d_res.scalars().all()
        print(f"Delinking {len(dettol_prods)} Dettol products from '{BIDIT_VENDOR_NAME}'...")
        for dp in dettol_prods:
            print(f"  - Delinking: {dp.name} (ID: {dp.id})")
            dp.vendorId = None
            dp.vendor = None

            # Also clear vendorId in StoreInventory
            inv_res = await session.execute(
                select(StoreInventory).where(StoreInventory.productId == dp.id)
            )
            for inv in inv_res.scalars().all():
                inv.vendorId = None

        # 2. Link Haldiram Seviyan Vermicelli to Bidit Grocery
        s_res = await session.execute(
            select(Product).where(Product.id == SEVAI_ID)
        )
        sevai_prod = s_res.scalar_one_or_none()
        if sevai_prod:
            print(f"\nLinking to {BIDIT_VENDOR_NAME}: {sevai_prod.name} (ID: {sevai_prod.id})")
            sevai_prod.vendorId = BIDIT_VENDOR_ID
            sevai_prod.vendor = BIDIT_VENDOR_NAME

            # Also update vendorId in StoreInventory
            inv_res = await session.execute(
                select(StoreInventory).where(StoreInventory.productId == sevai_prod.id)
            )
            for inv in inv_res.scalars().all():
                inv.vendorId = BIDIT_VENDOR_ID
        else:
            print(f"Error: Sevai product {SEVAI_ID} not found!")

        await session.commit()
        print("\nVendor link update committed successfully!")

if __name__ == '__main__':
    asyncio.run(update_vendor_links())
