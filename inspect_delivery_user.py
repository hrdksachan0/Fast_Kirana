import asyncio
import sys

sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

from database import AsyncSessionLocal
from models import User, Address, Order
from sqlalchemy.future import select

async def inspect():
    async with AsyncSessionLocal() as session:
        # Check delivery partner users
        res = await session.execute(select(User).where(User.email.like("%delivery%")))
        delivery_users = res.scalars().all()
        print(f"Delivery users with email %delivery%: {len(delivery_users)}")
        for u in delivery_users:
            print(f"ID: {u.id}, Name: {u.name}, Email: {u.email}, Phone: {u.phone}, Role: {u.role}")

        # Check all DELIVERY role users
        res2 = await session.execute(select(User).where(User.role == "DELIVERY"))
        riders = res2.scalars().all()
        print(f"\nAll DELIVERY role users: {len(riders)}")
        for r in riders:
            print(f"ID: {r.id}, Name: {r.name}, Email: {r.email}, Phone: {r.phone}")

if __name__ == "__main__":
    asyncio.run(inspect())
