import asyncio
import os
import sys

sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

from database import AsyncSessionLocal
from models import User, FcmToken
from sqlalchemy.future import select
from utils.firebase import send_fcm_notification, init_firebase

async def check_user():
    init_firebase()
    async with AsyncSessionLocal() as session:
        # Find user by phone
        stmt = select(User).where(User.phone.like("%9170942500%"))
        res = await session.execute(stmt)
        users = res.scalars().all()
        print(f"Users found with 9170942500: {len(users)}")
        
        for u in users:
            print(f"User: ID={u.id}, Name={u.name}, Phone={u.phone}, Role={u.role}")
            # Check tokens for this user
            stmt_fcm = select(FcmToken).where(FcmToken.userId == u.id)
            res_fcm = await session.execute(stmt_fcm)
            tokens = res_fcm.scalars().all()
            print(f"  -> Tokens for user {u.id}: {len(tokens)}")
            for t in tokens:
                print(f"     Token: {t.token[:30]}... ({t.deviceType})")

        # Also check all total tokens in fcm_tokens table
        all_res = await session.execute(select(FcmToken))
        all_tokens = all_res.scalars().all()
        print(f"\nTotal Tokens in fcm_tokens table: {len(all_tokens)}")

if __name__ == "__main__":
    asyncio.run(check_user())
