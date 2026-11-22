import asyncio
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Order, OrderItem, OrderStatus
from sqlalchemy import select
from sqlalchemy.orm import selectinload

async def remove_onion_pizza():
    async with AsyncSessionLocal() as session:
        res = await session.execute(
            select(Order).options(selectinload(Order.items)).where(Order.id == 'ord_ea871dc5bfda4f078bff')
        )
        order = res.scalar_one_or_none()
        if not order:
            print("Order 4253-R not found!")
            return

        print(f"Found Order: {order.readableId} ({order.id}) | Current Total: ₹{order.total} | Status: {order.status}")
        
        # Find and delete Onion Pizza item
        removed_items = []
        for it in list(order.items):
            if 'onion' in it.name.lower() and 'pizza' in it.name.lower():
                removed_items.append(it.name)
                await session.delete(it)

        print(f"Removed items: {removed_items}")

        # Update order financials & status
        order.subtotal = 0.0
        order.deliveryFee = 0.0
        order.taxes = 0.0
        order.miscFee = 0.0
        order.total = 0.0
        order.status = OrderStatus.CANCELLED
        order.notes = "Capsicum Tomato Onion Pizza removed by admin. Order cancelled."

        await session.commit()
        print(f"Order {order.readableId} successfully updated: Items removed, Total set to ₹0.00, Status set to CANCELLED.")

if __name__ == '__main__':
    asyncio.run(remove_onion_pizza())
