import os
import sys
import firebase_admin
from firebase_admin import credentials, messaging

sys.path.insert(0, r"d:\Fastkirana\fastapi-backend")

cred_path = r"d:\Fastkirana\fastapi-backend\firebase-credentials.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

print("Firebase initialized with project:", firebase_admin.get_app().project_id)

def send_all_test_notifications():
    # 1. Send to topic 'all_users'
    msg1 = messaging.Message(
        notification=messaging.Notification(
            title="⚡ FastKirana Express",
            body="Hello Hardik! Aapka FastKirana push notification 100% live & active hai! 🛵📦",
        ),
        data={
            "type": "ORDER_STATUS",
            "category": "order",
            "title": "⚡ FastKirana Express",
            "body": "Hello Hardik! Aapka FastKirana push notification 100% live & active hai! 🛵📦"
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                icon="@mipmap/ic_launcher",
                color="#E20A22",
                sound="default",
                channel_id="fastkirana_alerts",
                default_sound=True,
                default_vibrate_timings=True
            )
        ),
        topic="all_users"
    )

    # 2. Send to topic 'phone_8112849854'
    msg2 = messaging.Message(
        notification=messaging.Notification(
            title="🛵 Order Update: FastKirana Express",
            body="Aapka order prepare ho raha hai Ghatampur darkstore me! ⚡",
        ),
        data={
            "type": "ORDER_UPDATE",
            "category": "order",
            "title": "🛵 Order Update: FastKirana Express",
            "body": "Aapka order prepare ho raha hai Ghatampur darkstore me! ⚡"
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                icon="@mipmap/ic_launcher",
                color="#E20A22",
                sound="default",
                channel_id="fastkirana_alerts",
                default_sound=True,
                default_vibrate_timings=True
            )
        ),
        topic="phone_8112849854"
    )

    try:
        r1 = messaging.send(msg1)
        print("[SUCCESS] Sent broadcast to topic 'all_users'! ID:", r1)
    except Exception as e:
        print("[ERROR] Failed topic 'all_users':", e)

    try:
        r2 = messaging.send(msg2)
        print("[SUCCESS] Sent direct alert to topic 'phone_8112849854'! ID:", r2)
    except Exception as e:
        print("[ERROR] Failed topic 'phone_8112849854':", e)

if __name__ == "__main__":
    send_all_test_notifications()
