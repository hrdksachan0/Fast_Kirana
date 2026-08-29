import asyncio
import os
import sys

sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

from utils.firebase import init_firebase, send_fcm_topic_notification
from routers.orders import send_pwa_notification_to_user

async def test_order_notification():
    init_firebase()
    print("Testing Customer Order Placed Push Notification to Phone 8112849854...")
    
    # Send order placed notification
    await send_pwa_notification_to_user(
        user_id="cmshitud10001lwidejcw36i3",
        title="🎉 Order Placed Successfully! (FK-78219)",
        body="Aapka FastKirana order confirm ho gaya hai! Ghatampur store se 10 mins me deliver hoga 🛵⚡",
        data={
            "orderId": "test_order_12345",
            "status": "CONFIRMED",
            "type": "ORDER_PLACED"
        },
        phone="8112849854"
    )
    print("[DONE] Order notification dispatched successfully!")

if __name__ == "__main__":
    asyncio.run(test_order_notification())
