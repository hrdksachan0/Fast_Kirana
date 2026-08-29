import asyncio
import sys

sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

from utils.firebase import send_fcm_topic_notification

async def test_cart_alert():
    print("Sending cart alert to topic phone_8112849854...")
    msg_id = await send_fcm_topic_notification(
        topic="phone_8112849854",
        title="🛒 Complete Your FastKirana Order!",
        body="You left items in your cart (Green Brinjal). Tap to order in 10 mins!",
        data={"type": "CART_ALERT", "url": "/cart"}
    )
    print("Delivered Cart Alert Message ID:", msg_id)

if __name__ == "__main__":
    asyncio.run(test_cart_alert())
