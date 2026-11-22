import asyncio
import uuid
import sys
sys.path.insert(0, 'd:/Fastkirana/fastapi-backend')

from database import AsyncSessionLocal
from models import Order, OrderItem, OrderStatus, OrderType, PaymentMethod, PaymentStatus
from sqlalchemy import select
from sqlalchemy.orm import selectinload

async def transfer_shakes():
    async with AsyncSessionLocal() as session:
        # 1. Fetch Wedson order 4311-R
        res = await session.execute(
            select(Order).options(selectinload(Order.items)).where(Order.id == 'ord_9dce9573df5948b3b41f')
        )
        wedson_order = res.scalar_one_or_none()
        if not wedson_order:
            print("Error: Order ord_9dce9573df5948b3b41f not found!")
            return

        print(f"Found Wedson Order: {wedson_order.readableId} ({wedson_order.id})")
        print(f"Original items count: {len(wedson_order.items)}, Total: {wedson_order.total}")

        # Identify the 2 shake items
        shake_items = []
        keep_items = []
        for it in wedson_order.items:
            name_l = it.name.lower()
            if 'butter' in name_l and 'shake' in name_l:
                shake_items.append(it)
            elif 'strawberry' in name_l and 'shake' in name_l:
                shake_items.append(it)
            else:
                keep_items.append(it)

        print(f"Identified {len(shake_items)} shake items to transfer:")
        for s in shake_items:
            print(f"  - {s.name} (Qty: {s.quantity}, Price: {s.price})")

        print(f"Items remaining in Wedson: {len(keep_items)}")
        for k in keep_items:
            print(f"  - {k.name} (Qty: {k.quantity}, Price: {k.price})")

        # 2. Create new Order for A.S. Restaurant (REST-101)
        new_order_id = f"ord_{uuid.uuid4().hex[:20]}"
        new_readable_id = "4311-AS"
        shakes_total = sum(float(s.price or 0.0) * int(s.quantity or 1) for s in shake_items)

        as_order = Order(
            id=new_order_id,
            readableId=new_readable_id,
            userId=wedson_order.userId,
            addressId=wedson_order.addressId,
            combinedId=wedson_order.combinedId,
            restaurantId='REST-101', # A.S. Restaurant
            orderType=OrderType.RESTAURANT,
            status=OrderStatus.DELIVERED,
            subtotal=shakes_total,
            discount=0.0,
            deliveryFee=0.0,
            taxes=0.0,
            miscFee=0.0,
            refundAmount=0.0,
            total=shakes_total,
            paymentMethod=wedson_order.paymentMethod,
            paymentStatus=wedson_order.paymentStatus,
            deliveryMethod=wedson_order.deliveryMethod,
            notes=wedson_order.notes,
            storeId=wedson_order.storeId,
            createdAt=wedson_order.createdAt,
            estimatedDelivery=wedson_order.estimatedDelivery,
            deliveryLat=wedson_order.deliveryLat,
            deliveryLng=wedson_order.deliveryLng
        )
        session.add(as_order)
        await session.flush()

        # 3. Re-assign shake items to as_order and update productId to A.S. Restaurant products
        # A.S. Restaurant shake product IDs:
        # Butterscotch Shake: cmqhzmodz000104icef59dlgf
        # Strawberry Shake: cmqhzo083000204ic1ujhimgj
        for s in shake_items:
            s.orderId = as_order.id
            if 'butter' in s.name.lower():
                s.productId = 'cmqhzmodz000104icef59dlgf'
            elif 'strawberry' in s.name.lower():
                s.productId = 'cmqhzo083000204ic1ujhimgj'

        # 4. Update Wedson order subtotal and total
        wedson_total = sum(float(k.price or 0.0) * int(k.quantity or 1) for k in keep_items)
        wedson_order.subtotal = wedson_total
        wedson_order.total = wedson_total

        await session.commit()
        print("\n--- TRANSFER SUCCESSFUL! ---")
        print(f"Wedson Order ({wedson_order.readableId}): Total updated to ₹{wedson_total}")
        print(f"A.S. Restaurant Order ({as_order.readableId}): Created with Total ₹{shakes_total}")
        print(f"Combined ID: {wedson_order.combinedId}")

if __name__ == '__main__':
    asyncio.run(transfer_shakes())
