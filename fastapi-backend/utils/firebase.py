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
    if _firebase_initialized:
        return True
    
    try:
        # Method 1: Load from env variable (JSON string)
        cred_json = os.getenv("FIREBASE_CREDENTIALS")
        if cred_json:
            try:
                cred_dict = json.loads(cred_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("Firebase Admin initialized successfully from env JSON.")
                return True
            except Exception as e:
                logger.error(f"Failed to initialize Firebase from env JSON: {str(e)}")
        
        # Method 2: Load from local file
        # Look for file in the fastapi-backend root folder
        root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cred_file = os.path.join(root_dir, "firebase-credentials.json")
        if os.path.exists(cred_file):
            try:
                cred = credentials.Certificate(cred_file)
                firebase_admin.initialize_app(cred)
                _firebase_initialized = True
                logger.info("Firebase Admin initialized successfully from firebase-credentials.json.")
                return True
            except Exception as e:
                logger.error(f"Failed to initialize Firebase from credentials file: {str(e)}")
        
        logger.warning("Firebase credentials not configured. FCM notifications will be skipped.")
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
    Returns success and failure counts, and a list of invalid tokens that should be deleted.
    """
    if not init_firebase():
        logger.error("Cannot send FCM notification: Firebase not initialized.")
        return {"success": 0, "failure": len(tokens), "invalid_tokens": []}
    
    if not tokens:
        return {"success": 0, "failure": 0, "invalid_tokens": []}
    
    try:
        # Convert data keys and values to strings (FCM requires string values)
        data_str = {}
        if data:
            for k, v in data.items():
                data_str[str(k)] = str(v)

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data_str,
            tokens=tokens
        )
        
        # Send message
        response = messaging.send_multicast(message)
        
        success_count = response.success_count
        failure_count = response.failure_count
        
        invalid_tokens = []
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    # Check if the error is due to an invalid/expired token
                    exc = resp.exception
                    # FCM returns specific codes for invalid tokens like registration-token-not-registered
                    error_code = getattr(exc, 'code', '')
                    if error_code in ['registration-token-not-registered', 'invalid-argument-or-token']:
                        invalid_tokens.append(tokens[idx])
                        
        logger.info(f"FCM batch send completed: {success_count} success, {failure_count} failures.")
        return {
            "success": success_count,
            "failure": failure_count,
            "invalid_tokens": invalid_tokens
        }
    except Exception as e:
        logger.error(f"Exception occurred while sending FCM multicast: {str(e)}")
        return {"success": 0, "failure": len(tokens), "invalid_tokens": []}
