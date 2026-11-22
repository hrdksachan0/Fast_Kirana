import asyncio
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Order, OrderItem
from sqlalchemy import select
from sqlalchemy.orm import selectinload

async def update_as_prices():
    async with AsyncSessionLocal() as session:
        res = await session.execute(
            select(Order).options(selectinload(Order.items)).where(Order.readableId == '4311-AS')
        )
        order = res.scalar_one_or_none()
        if not order:
            print("Order 4311-AS not found!")
            return

        new_subtotal = 0.0
        for it in order.items:
            # A.S. Restaurant price for shakes is ₹85.00
            it.price = 85.0
            new_subtotal += 85.0 * int(it.quantity or 1)
            print(f"Updated item: {it.name} -> ₹{it.price} (Qty: {it.quantity})")

        order.subtotal = new_subtotal
        order.total = new_subtotal

        await session.commit()
        print(f"\nOrder 4311-AS successfully updated to A.S. Restaurant prices!")
        print(f"New Sub-Order Total: ₹{order.total}")

if __name__ == '__main__':
    asyncio.run(update_as_prices())
