import asyncio
import os
import sys

# Add backend directory to sys.path
sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

from database import AsyncSessionLocal
from models import FcmToken, User
from sqlalchemy.future import select
from utils.firebase import send_fcm_notification, init_firebase

async def main():
    print("1. Initializing Firebase Admin...")
    init_success = init_firebase()
    print(f"Firebase initialized: {init_success}")

    async with AsyncSessionLocal() as session:
        print("\n2. Checking registered FCM tokens in database...")
        stmt = select(FcmToken, User).outerjoin(User, FcmToken.userId == User.id)
        result = await session.execute(stmt)
        rows = result.all()
        
        print(f"Total tokens found: {len(rows)}")
        
        if not rows:
            print("No FCM tokens registered in database yet.")
            print("To register: Log in on the Flutter app, and the token will automatically save to the database.")
            return

        tokens = []
        for fcm, user in rows:
            user_info = f"{user.name} ({user.phone})" if user else "Anonymous / No User"
            print(f" - ID: {fcm.id} | User: {user_info} | Device: {fcm.deviceType} | Token: {fcm.token[:25]}...")
            tokens.append(fcm.token)

        print("\n3. Sending Live Test Push Notification to all registered devices...")
        res = await send_fcm_notification(
            tokens=tokens,
            title="⚡ FastKirana Notification Test",
            body="Hello! Aapka FastKirana push notification system 100% live aur working hai! 🛵📦",
            data={
                "type": "TEST_ALERT",
                "category": "order",
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
        )
        print(f"Result: {res}")

if __name__ == "__main__":
    asyncio.run(main())
