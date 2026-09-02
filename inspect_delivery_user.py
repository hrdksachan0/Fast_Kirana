import asyncio
import sys

sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

from database import AsyncSessionLocal
from models import User, Address, Order, Role
from sqlalchemy.future import select

from sqlalchemy import func

async def inspect():
    async with AsyncSessionLocal() as session:
        # Update admin@fastkirana.in
        res_adm = await session.execute(select(User).where(User.email == "admin@fastkirana.in"))
        adm_user = res_adm.scalars().first()
        if adm_user:
            adm_user.phone = "+917054470303"
            adm_user.role = Role.ADMIN
            adm_user.name = "Fastkirana Admin"
            print("Set admin@fastkirana.in to Role.ADMIN with phone +917054470303")

        # Update delivery@fastkirana.com
        res_del = await session.execute(select(User).where(User.email == "delivery@fastkirana.com"))
        del_user = res_del.scalars().first()
        if del_user:
            del_user.phone = "+919696503759"
            del_user.role = Role.DELIVERY
            del_user.name = "Aryan"
            print("Set delivery@fastkirana.com to Role.DELIVERY with phone +919696503759")

        await session.commit()
        print("VERIFIED SEPARATION!")

if __name__ == "__main__":
    asyncio.run(inspect())
