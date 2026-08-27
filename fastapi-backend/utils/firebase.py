import os
import json
import logging
import firebase_admin
from firebase_admin import credentials, messaging
from typing import Optional, Dict, Any, List

logger = logging.getLogger("fcm_notifications")

# Global flag to track initialization
_firebase_initialized = False

def init_firebase() -> bool:
    global _firebase_initialized
    if _firebase_initialized and firebase_admin._apps:
        return True
    
    try:
        if firebase_admin._apps:
            _firebase_initialized = True
            return True

        # Method 1: Load from env variable (JSON string)
        cred_json = os.getenv("FIREBASE_CREDENTIALS")
        if cred_json:
            try:
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("✅ Firebase Admin initialized successfully from env JSON.")
                return True
            except Exception as e:
                logger.error(f"Failed to initialize Firebase from env JSON: {str(e)}")
        
        # Method 2: Load from local file
        root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cred_file = os.path.join(root_dir, "firebase-credentials.json")
        if os.path.exists(cred_file):
            try:
                cred = credentials.Certificate(cred_file)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("✅ Firebase Admin initialized successfully from firebase-credentials.json.")
                return True
            except Exception as e:
                logger.error(f"Failed to initialize Firebase from credentials file: {str(e)}")
        
        logger.warning("⚠️ Firebase credentials not configured. FCM notifications will be skipped.")
        return False
    except Exception as e:
        logger.error(f"Exception during Firebase initialization: {str(e)}")
        return False

# Try to initialize on load
init_firebase()

async def send_fcm_notification(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Send push notification to multiple device tokens via FCM.
    Uses modern firebase-admin send_each_for_multicast SDK.
    """
    if not init_firebase():
        logger.error("Cannot send FCM notification: Firebase not initialized.")
        return {"success": 0, "failure": len(tokens), "invalid_tokens": []}
    
    clean_tokens = [t for t in tokens if t and isinstance(t, str) and len(t) > 10]
    if not clean_tokens:
        return {"success": 0, "failure": 0, "invalid_tokens": []}
    
    try:
        # Convert data keys and values to strings (FCM requirement)
        data_str = {str(k): str(v) for k, v in (data or {}).items()}

        message = messaging.MulticastMessage(
            tokens=clean_tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data_str,
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
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            )
        )
        
        # Send message using modern send_each_for_multicast
        response = messaging.send_each_for_multicast(message)
        
        success_count = response.success_count
        failure_count = response.failure_count
        
        invalid_tokens = []
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    exc = resp.exception
                    error_code = getattr(exc, 'code', '')
                    if error_code in ['registration-token-not-registered', 'invalid-argument-or-token']:
                        invalid_tokens.append(clean_tokens[idx])
                        
        logger.info(f"🚀 FCM batch send completed: {success_count} success, {failure_count} failures.")
        return {
            "success": success_count,
            "failure": failure_count,
            "invalid_tokens": invalid_tokens
        }
    except Exception as e:
        logger.error(f"❌ Exception occurred while sending FCM multicast: {str(e)}")
        return {"success": 0, "failure": len(clean_tokens), "invalid_tokens": []}


async def send_fcm_topic_notification(
    topic: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    Send push notification to a Firebase Topic (e.g. 'all_users', 'phone_8112849854', 'user_cmshitud10001lwidejcw36i3')
    """
    if not init_firebase():
        logger.error("Cannot send FCM topic notification: Firebase not initialized.")
        return False
    
    clean_topic = str(topic).replace("+", "").replace(" ", "").replace("-", "").strip()
    if not clean_topic:
        return False
    
    try:
        data_str = {str(k): str(v) for k, v in (data or {}).items()}
        data_str["title"] = title
        data_str["body"] = body

        message = messaging.Message(
            topic=clean_topic,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data_str,
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
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)
                )
            )
        )
        res = messaging.send(message)
        logger.info(f"🚀 FCM topic notification sent successfully to topic '{clean_topic}': {res}")
        return True
    except Exception as e:
        logger.error(f"❌ Error sending FCM notification to topic '{clean_topic}': {e}")
        return False

