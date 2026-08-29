import os
import sys
import firebase_admin
from firebase_admin import credentials, messaging

cred_path = r"d:\Fastkirana\fastapi-backend\firebase-credentials.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

print("Firebase initialized with project:", firebase_admin.get_app().project_id)

def send_topic_alert():
    message = messaging.Message(
        notification=messaging.Notification(
            title="FastKirana Express Test",
            body="Aapka Push Notification 100% Live & Connected hai!",
        ),
        data={
            "type": "BROADCAST_TEST",
            "category": "order",
            "title": "FastKirana Express Test",
            "body": "Aapka Push Notification 100% Live & Connected hai!"
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

    try:
        response = messaging.send(message)
        print("[SUCCESS] Successfully sent FCM message to topic 'all_users'! Message ID:", response)
    except Exception as e:
        print("[ERROR] Error sending to topic:", e)

if __name__ == "__main__":
    send_topic_alert()
