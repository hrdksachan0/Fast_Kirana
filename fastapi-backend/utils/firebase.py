import os
import json
import logging
import re
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

        # Method 3: Load from individual FIREBASE_* environment variables (Railway / Cloud)
        client_email = os.getenv("FIREBASE_CLIENT_EMAIL")
        private_key = os.getenv("FIREBASE_PRIVATE_KEY")
        project_id = os.getenv("FIREBASE_PROJECT_ID")
        if client_email and private_key and project_id:
            try:
                clean_key = private_key.replace("\\n", "\n").strip().strip('"').strip("'")
                cred_dict = {
                    "type": "service_account",
                    "project_id": project_id.strip(),
                    "client_email": client_email.strip(),
                    "private_key": clean_key,
                    "token_uri": "https://oauth2.googleapis.com/token",
                }
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("✅ Firebase Admin initialized successfully from individual FIREBASE_* envs.")
                return True
            except Exception as e:
                logger.error(f"Failed to initialize Firebase from individual FIREBASE_* envs: {str(e)}")
        
        # Method 4: Built-in production fallback service credentials
        FALLBACK_CREDENTIALS = {
            "type": "service_account",
            "project_id": "fastkirana-98a68",
            "client_email": "firebase-adminsdk-fbsvc@fastkirana-98a68.iam.gserviceaccount.com",
            "private_key": """-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDmnNIVpENGO4on
LOR0O/yzwFfXMOtYZ9o2oGZBF66p7GnHczP07vaNGhn1cCjlIMgo829HvN8jB1kI
5tSxwhZsr9tL/i78PQh7vI5iDNYGuPw6awSClu1TwfDCWS1KqH198EP0raMxhFe4
S1iOe4NkOxFlxifHZRMik74Zhkhmtd8byEeTltGccYwcCA2iJQZ/xjcFonxgElK6
ig2/Io/9NyiMaSODObLvsq9xNKWzKDAd/8utnT8sBar0Py9i+9vnHSkNcyatgQ7M
sYgH+k8aru587J+ikkToT8JTNELI2pZVIRqeKvlrv6dQsMXODqjNFCQ+7joQGcMu
F++WYb7jAgMBAAECggEAOV2QOvbyDzH3Y1hc+fcEHPi/QRX3rTWkSAttdEq+VaGs
DIPBTG/3H9F63J2KZrjZYapwp5E5ln6Y7Mhy50cHCgFS1VwE9xT9m74jUwurX9+7
SpLde9isb7XiPI4vYI96LA5M8TwSSNqJcZw4irT50cCJyt3YflbLxEGpO7M2Jmol
hL8YqRj7rp0qy9W6VxfmT/DoS6P19k238vayELVozUdMMavUNeUwz6OmGjzyAHOz
U0P3PdRX8LvivAOnA/A7GzpsbP9JWRbOIlU1J/kCnP+Kcg/G6pZZ/p6qMPv1d2ib
PyX2DOSm2G0GEWkfR4aXX+BoUu8RzNLS4fO+euHtvQKBgQD6xaX0IMoJYo5bunMj
Un67rjbDxPJRpdfAag3FwSRxR7giT/l6oTgg35qM+XuGJL5tRmwSoLfsXf4mCKB5
2NzNif1t4gRx6uMx5ygDzmPOYIHpmmYNjDTSGGQ4fHxYSOzlCBWmuTERV8eNn772
u9uW5iDXQu2h5dYjzfKNtn7c5QKBgQDra5UuFHALAotQ1ug5s3ZwQd+YXcIpO0Qr
htzy+h1IWcXSgK55WJL0X/gCl5WBPTeNzCoGbD5nKaThb9WHOskKpo8gaKvXOwKQ
PV3+2QTc64tFIe5sbPKidrdOFAVhV8xMJzh0aDY37VdvHf3puYyyb4IR/YLxOBi9
8fiTFgw4JwKBgQCoHxQIXGc27YUlSBXi626dosmCbCpMxNOlYzSCjN9CtuNi1Z0b
MrSvjVlPA/9lSoMEPb88qdVEuSsnEoeLyPEXN1jZbzqtqNzSWve/vYG6HYdbNrEO
ih3rcIDYQdUXVyTC0624TdXwm5nkf+GGByHLw9Lmni80aCMtc+gWS/A3ZQKBgHpD
YTKRQq81Hw1YzzpITdZ3H5yN9Oxc70Z7v/wgkVyl4us0EWjL62YnATK3btmz5Uor
Ihg71xzUr+C0p/yXNxnk7qgyNCyPZQFsHYjhRHlHiwjYWm7NFiXx6bkPBMxNQLi8
FcG+7YmWJbZ7qQbdaoixCKg3NO356D+djy80YBw5AoGASYDtpXNW0ZPl8wD9GRuI
qyk/xC7Fuvc75rVMHKv/AwWUWlot1I5eJiJoIqQKF0R9xDnprlxGqpk9vlY7WHBD
j1yxowoSr851qAsjOHEL8GAU8RS1RzcUq6ZguNnA3yPALna4nSTh4t/1wtSS7Vif
vr2uSqJghFgjT1YH8irHRkQ=
-----END PRIVATE KEY-----""",
            "token_uri": "https://oauth2.googleapis.com/token",
        }
        try:
            cred = credentials.Certificate(FALLBACK_CREDENTIALS)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("✅ Firebase Admin initialized successfully from fallback credentials.")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize Firebase from fallback credentials: {str(e)}")

        logger.warning("⚠️ Firebase credentials not configured. FCM notifications will be skipped.")
        return False
    except Exception as e:
        logger.error(f"Exception during Firebase initialization: {str(e)}")
        return False

# Try to initialize on load
init_firebase()

def is_order_buzzer_alert(title: str, body: str, data: Optional[Dict[str, Any]]) -> bool:
    d = data or {}
    screen = str(d.get("screen", "")).lower()
    msg_type = str(d.get("type", "")).upper()
    role = str(d.get("role", "")).upper()
    status_val = str(d.get("status", "")).upper()
    t_lower = str(title).lower()
    b_lower = str(body).lower()

    is_cancelled = (
        status_val in ["CANCELLED", "REJECTED", "FAILED", "REFUNDED"] or
        "cancel" in t_lower or "cancel" in b_lower
    )
    if is_cancelled:
        return False

    return (
        screen in ["restaurant-console", "admin-orders", "delivery", "picker", "vendor-console"] or
        bool(d.get("restaurantId")) or
        msg_type in ["NEW_ORDER", "STAFF_ALERT", "VENDOR_NEW_ORDER"] or
        role in ["ADMIN", "CHEF", "PICKER", "DELIVERY", "VENDOR"] or
        "🛎️" in title or "💳" in title or "👨‍🍳" in title or "🚨" in title or "📦" in title or
        "new order" in t_lower or "kitchen" in t_lower or "awaiting approval" in t_lower
    )


def is_order_status_update(title: str, body: str, data: Optional[Dict[str, Any]]) -> bool:
    d = data or {}
    status_val = str(d.get("status", "")).upper()
    msg_type = str(d.get("type", "")).upper()
    t_lower = str(title).lower()
    return (
        status_val in ["OUT_FOR_DELIVERY", "DISPATCHED", "DELIVERED", "CONFIRMED", "PREPARING", "COOKING", "PACKED", "SHIPPED"] or
        msg_type == "ORDER_STATUS_UPDATE" or
        "out for delivery" in t_lower or "dispatched" in t_lower or "delivered" in t_lower or "on the way" in t_lower
    )


async def send_fcm_notification(
    tokens: List[str],
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Send push notification to multiple device tokens via FCM.
    Uses modern firebase-admin send_each_for_multicast SDK.
    Supports high-priority buzzer alarm for Admin, Staff, and Kitchen.
    """
    if not init_firebase():
        logger.error("Cannot send FCM notification: Firebase not initialized.")
        return {"success": 0, "failure": len(tokens), "invalid_tokens": []}
    
    clean_tokens = [t for t in tokens if t and isinstance(t, str) and len(t) > 10]
    if not clean_tokens:
        return {"success": 0, "failure": 0, "invalid_tokens": []}
    
    try:
        data_str = {str(k): str(v) for k, v in (data or {}).items()}
        data_str["click_action"] = "FLUTTER_NOTIFICATION_CLICK"
        data_str["title"] = title
        data_str["body"] = body

        is_buzzer = is_order_buzzer_alert(title, body, data)
        is_status = is_order_status_update(title, body, data)

        if is_buzzer:
            channel_id = "fastkirana_order_buzzer_v2"
            sound = "order_chime"
            priority = "max"
            default_sound = False
            default_vibrate = False
        elif is_status:
            channel_id = "fastkirana_order_status"
            sound = "order_chime"
            priority = "high"
            default_sound = False
            default_vibrate = False
        else:
            channel_id = "fastkirana_alerts"
            sound = "default"
            priority = "high"
            default_sound = True
            default_vibrate = True

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
                    sound=sound,
                    channel_id=channel_id,
                    default_sound=default_sound,
                    default_vibrate_timings=default_vibrate,
                    priority=priority,
                    visibility="public",
                    click_action="FLUTTER_NOTIFICATION_CLICK"
                )
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        badge=1,
                        content_available=True,
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
                        
        logger.info(f"🚀 FCM batch send completed: {success_count} success, {failure_count} failures (Channel: {channel_id}).")
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
    Send push notification to a Firebase Topic (e.g. 'admin_orders', 'admin_orders_all', 'picker_orders_hub-209206')
    Supports high-priority buzzer alarm for Admin, Staff, and Kitchen.
    """
    if not init_firebase():
        logger.error("Cannot send FCM topic notification: Firebase not initialized.")
        return False
    
    clean_topic = re.sub(r'[^a-zA-Z0-9-_.~%]', '', str(topic)).strip()
    if not clean_topic:
        return False
    
    try:
        data_str = {str(k): str(v) for k, v in (data or {}).items()}
        data_str["click_action"] = "FLUTTER_NOTIFICATION_CLICK"
        data_str["title"] = title
        data_str["body"] = body

        is_buzzer = is_order_buzzer_alert(title, body, data)
        is_status = is_order_status_update(title, body, data)

        if is_buzzer:
            channel_id = "fastkirana_order_buzzer_v2"
            sound = "order_chime"
            priority = "max"
            default_sound = False
            default_vibrate = False
        elif is_status:
            channel_id = "fastkirana_order_status"
            sound = "order_chime"
            priority = "high"
            default_sound = False
            default_vibrate = False
        else:
            channel_id = "fastkirana_alerts"
            sound = "default"
            priority = "high"
            default_sound = True
            default_vibrate = True

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
                    sound=sound,
                    channel_id=channel_id,
                    default_sound=default_sound,
                    default_vibrate_timings=default_vibrate,
                    priority=priority,
                    visibility="public",
                    click_action="FLUTTER_NOTIFICATION_CLICK"
                )
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        badge=1,
                        content_available=True,
                    )
                )
            )
        )
        res = messaging.send(message)
        logger.info(f"🚀 FCM topic notification sent successfully to topic '{clean_topic}' (Channel: {channel_id}): {res}")
        return True
    except Exception as e:
        logger.error(f"❌ Error sending FCM notification to topic '{clean_topic}': {e}")
        return False

